#!/usr/bin/env python3
"""Time + energy matrix: Vclust 1.3.1 vs Bend-C (CPU) vs Bend-CUDA, per stage and end-to-end.

For each dataset x {prefilter, align, cluster, e2e} x configuration it runs
`tools/energy_bench.py` (bench lock, capped scope, idle baseline, NVML/RAPL)
and checks the output against Vclust's own (-t 12, first repeat) byte for
byte. A cell whose output differs is recorded as `mismatch` and is never
counted as a timed success.

Configurations
  vclust-t12, vclust-t1   official CLI (`vclust <stage> ... -t N -v 0`);
                          Clusty has no thread flag, so cluster has one vclust cell
  bendc-t12, bendc-t1     native Bend binary, `+RTS --gpu off --threads N -RTS`
  bendgpu-t12             native Bend binary with its GPU program (`!` calls on
                          the GPU, default runtime), only when a GPU build of
                          the stage exists, else the cell is `pending`; e2e
                          uses the GPU build of every stage that has one and
                          the CPU build (no `!`) of the others
  bendgpuoff-t12          the same GPU binary with `+RTS --gpu off` (its `!`
                          calls on the 12-thread CPU pool), to separate the
                          device from the code changes made for it

GPU builds are detected per stage from (first match):
  --gpu-entry STAGE=FILE.bend   explicit
  vclust_bend/STAGE_gpu.bend    convention for the GPU entry point
They are compiled here (capped 8G) and accepted only if the compiler wrote
the `<binary>.gpu` program beside the binary. `--gpu off` skips them.

Per-stage cells are isolated: align always reads Vclust's filter, cluster
Vclust's ani.tsv/ani.ids.tsv. e2e chains each tool's own three stages and
compares every intermediate file. Results: evidence/energy/<dataset>.jsonl,
summary.json, RESULTS.md (regenerate with --report-only).
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / 'tools'))
import energy_bench as eb  # noqa: E402
import run as launcher  # noqa: E402

VC = ROOT.parent / '.tools/vclust-1.3.1/bin/vclust'
DATA = {
    'stratified1000': ROOT.parent / 'datasets/infant_gut_virome/ready/earlyvir_stratified1000.fasta',
    'example': ROOT.parent / 'datasets/public_viromes/original/vclust_example.fasta',
    'all_clean_contigs': Path(os.environ.get('ALL_CLEAN_CONTIGS') or
                              '/home/veritas/Bioinformatique/clustervir-data/archives/'
                              'wetransfer_clustervir_2026-09-29_0954/all_clean_contigs.fasta'),
}
STAGES = ('prefilter', 'align', 'cluster', 'e2e')
CONFIGS = ('vclust-t12', 'vclust-t1', 'bendc-t12', 'bendc-t1', 'bendgpu-t12', 'bendgpuoff-t12')
CLUSTER_ARGS = ['--algorithm', 'leiden', '--metric', 'ani', '--ani', '0.95']
OUTFILES = {'prefilter': ['fltr.txt'], 'align': ['ani.tsv', 'ani.ids.tsv'], 'cluster': ['clusters.tsv'],
            'e2e': ['fltr.txt', 'ani.tsv', 'ani.ids.tsv', 'clusters.tsv']}
EVID = ROOT / 'evidence/energy'


def sha(p):
    return eb.sha256(p)


def count_genomes(fasta):
    n = 0
    with open(fasta, 'rb') as f:
        for line in f:
            n += line[:1] == b'>'
    return n


def gpu_entries(explicit):
    out = {}
    for item in explicit:
        st, f = item.split('=', 1)
        out[st] = (ROOT / f).resolve()
    for st in ('prefilter', 'align', 'cluster'):
        if st not in out and (ROOT / f'{st}_gpu.bend').exists():
            out[st] = ROOT / f'{st}_gpu.bend'
    return out


def build_gpu(stage, entry):
    """Compile a GPU entry point; return (binary, note). Binary None if no GPU program."""
    cmd, ident = launcher.compiler()
    h = hashlib.sha256(ident.encode())
    for f in sorted(ROOT.glob('*.bend')):
        h.update(f.name.encode()); h.update(f.read_bytes())
    out = ROOT / '.work/energy/gpu-bin' / h.hexdigest()[:20] / stage
    out.parent.mkdir(parents=True, exist_ok=True)
    if not out.exists():
        try:
            launcher.capped([*cmd, entry, '-o', out], '8G', cwd=ROOT)
        except subprocess.CalledProcessError as e:
            return None, f'GPU build of {entry.name} failed: {e}'
    if not Path(str(out) + '.gpu').exists():
        return None, f'{entry.name} built without a .gpu program (no ! calls reached)'
    return out, f'built from {entry.name}'


def commands(tool, threads, stage, data, folder, ref, bins):
    """Command list (or sh -c for e2e) and the produced files for one cell."""
    f = folder
    def vc(st, args):
        return [str(VC), st, *map(str, args), *([] if st == 'cluster' else ['-t', str(threads)]), '-v', '0']
    def bd(st, args):
        rts = ['+RTS', '--gpu', 'off', '--threads', str(threads), '-RTS'] if tool in ('bendc', 'bendgpuoff') else \
              ['+RTS', '--threads', str(threads), '-RTS']
        return [str(bins[st]), *map(str, args), *rts]
    run = vc if tool == 'vclust' else bd
    flt = ref.get('fltr.txt') if stage != 'e2e' else f / 'fltr.txt'
    ani = ref.get('ani.tsv') if stage != 'e2e' else f / 'ani.tsv'
    ids = ref.get('ani.ids.tsv') if stage != 'e2e' else f / 'ani.ids.tsv'
    args = {
        'prefilter': ['-i', data, '-o', f / 'fltr.txt'],
        'align': ['-i', data, '-o', f / 'ani.tsv', '--filter', flt],
        'cluster': ['-i', ani, '--ids', ids, '-o', f / 'clusters.tsv', *CLUSTER_ARGS],
    }
    if stage != 'e2e':
        return run(stage, args[stage])
    chain = ' && '.join(shlex.join(run(st, args[st])) for st in ('prefilter', 'align', 'cluster'))
    return ['sh', '-c', chain]


def expected_seconds(records, dataset, stage, config):
    xs = [r['wall_seconds'] for r in records if r.get('dataset') == dataset and r.get('stage') == stage
          and r.get('config') == config and r.get('wall_seconds')]
    return xs[-1] if xs else None


def run_matrix(a):
    EVID.mkdir(parents=True, exist_ok=True)
    gpu = gpu_entries(a.gpu_entry) if a.gpu != 'off' else {}
    if a.bins:  # reuse an existing build (e.g. while other agents edit the sources)
        bins = {s: Path(a.bins) / s for s in ('prefilter', 'align', 'cluster')}
    else:
        bins = {s: launcher.build(s) for s in ('prefilter', 'align', 'cluster')}
    gbins, gnotes = {}, {}
    for item in a.gpu_bin:
        st, f = item.split('=', 1)
        gbins[st], gnotes[st] = Path(f), f'prebuilt {f}'
        gpu.pop(st, None)
    for st, entry in gpu.items():
        gbins[st], gnotes[st] = build_gpu(st, entry)
    meta = {'bend_binaries': {s: {'path': str(b), 'sha256': sha(b)} for s, b in bins.items()},
            'gpu_binaries': {s: {'path': str(b) if b else None, 'note': gnotes[s],
                                 'sha256': sha(b) if b else None} for s, b in gbins.items()},
            'vclust': str(VC), 'cluster_args': CLUSTER_ARGS,
            'gpu_mode': a.gpu}
    for dataset in a.datasets:
        data = DATA[dataset]
        reps = a.repeats if a.repeats else (3 if dataset != 'all_clean_contigs' else 1)
        genomes = count_genomes(data)
        jl = EVID / f'{dataset}.jsonl'
        work = ROOT / '.work/energy' / dataset / time.strftime('%Y%m%dT%H%M%S')
        work.mkdir(parents=True)
        records = []
        ref = {}
        if jl.exists():
            # Reuse the latest Vclust -t 12 reference outputs (still on disk, hash re-checked).
            for line in jl.read_text().splitlines():
                r = json.loads(line)
                if r.get('status') == 'reference':
                    for k, h in r['outputs'].items():
                        if sha(k) == h:
                            ref[Path(k).name], ref[Path(k).name + '#sha'] = Path(k), h
        for stage in a.stages:
            for config in a.configs:
                tool, threads = config.split('-t')[0], int(config.split('-t')[1])
                if threads == 12:  # "t12" = every hardware thread (BENCH_THREADS overrides)
                    threads = int(os.environ.get('BENCH_THREADS') or os.cpu_count() or 12)
                base = {'invocation': work.name, 'dataset': dataset, 'genomes': genomes, 'stage': stage, 'config': config,
                        'tool': tool, 'threads': threads}
                if tool == 'vclust' and stage == 'cluster' and config != 'vclust-t12':
                    rec = dict(base, status='n/a', note='Clusty has no thread flag; see vclust-t12')
                    records.append(rec); jl.open('a').write(json.dumps(rec) + '\n'); continue
                stage_bins = dict(bins)
                if tool in ('bendgpu', 'bendgpuoff'):
                    need = ('prefilter', 'align', 'cluster') if stage == 'e2e' else (stage,)
                    miss = [s for s in need if not gbins.get(s)]
                    if len(miss) == len(need):
                        rec = dict(base, status='pending', note='no GPU build for ' + ', '.join(
                            f'{s} ({gnotes.get(s, "no GPU entry point")})' for s in miss))
                        records.append(rec); jl.open('a').write(json.dumps(rec) + '\n'); continue
                    stage_bins.update({s: gbins[s] for s in need if gbins.get(s)})
                    base['gpu_stages'] = [s for s in need if gbins.get(s)]
                if stage != 'e2e' and stage != 'prefilter' and not ref:
                    rec = dict(base, status='skipped', note='no Vclust reference outputs')
                    records.append(rec); continue
                for rep in range(1, reps + 1):
                    folder = work / f'{stage}-{config}-r{rep}'
                    folder.mkdir()
                    cmd = commands(tool, threads, stage, data, folder, ref, stage_bins)
                    exp = expected_seconds(records, dataset, stage, config) or a.baseline_default
                    bl = min(max(exp, 2.0), a.baseline_max)
                    outs = [folder / n for n in OUTFILES[stage]]
                    r = eb.measure(cmd, a.cap, bl, outs, f'{dataset}/{stage}/{config}/r{rep}',
                                   timeout=a.timeout, stdout=folder / 'stdout.log')
                    rec = dict(base, repeat=rep, **r)
                    # Equivalence against Vclust -t 12 (first repeat = the reference).
                    hashes = {Path(k).name: v for k, v in r['outputs'].items()}
                    if not r['ok']:
                        rec['status'] = 'failed'
                    elif config == 'vclust-t12' and rep == 1 and stage != 'e2e':
                        for n in OUTFILES[stage]:
                            ref[n] = folder / n
                            ref[n + '#sha'] = hashes[n]
                        rec['status'] = 'reference'
                    else:
                        cmp = {n: (hashes.get(n) is not None and hashes.get(n) == ref.get(n + '#sha'))
                               for n in OUTFILES[stage]}
                        rec['identical'] = cmp
                        rec['status'] = 'ok' if all(cmp.values()) else 'mismatch'
                    records.append(rec)
                    with jl.open('a') as f:
                        f.write(json.dumps(rec, sort_keys=True) + '\n')
                    e = r['energy']
                    print(f"{dataset} {stage:9} {config:11} r{rep} {rec['status']:9} "
                          f"wall={r.get('wall_seconds') or 0:7.2f}s peak={(r.get('cgroup_memory_peak_bytes') or 0)/2**20:7.0f}MiB "
                          f"gpuJ={e['gpu_raw_joules']} net={e['gpu_net_joules']} load='{r['uptime_before'][-17:]}'",
                          flush=True)
                    if rec['status'] in ('failed', 'mismatch') and tool != 'vclust':
                        break
                    if rec['status'] == 'failed' and tool == 'vclust':
                        break
        (EVID / f'{dataset}.meta.json').write_text(json.dumps(dict(meta, work=str(work)), indent=2) + '\n')
    report()


# ---------------------------------------------------------------- report
def med(xs):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return None
    n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2


INVALID = []


def invalid_power(r):
    """On battery, or (GPU cells only) the GPU board capped below its default power limit."""
    p = r.get('power_before') or {}
    g = p.get('gpu') or {}
    capped = (r.get('tool') == 'bendgpu' and g.get('enforced_power_limit_w') and g.get('default_power_limit_w')
              and g['enforced_power_limit_w'] < 0.9 * g['default_power_limit_w'])
    return p.get('ac_online') is False or bool(capped) or bool(p.get('invalid'))


def load_all():
    recs = []
    for jl in sorted(EVID.glob('*.jsonl')):
        # The latest invocation of each cell supersedes earlier ones, except that a
        # run made on battery (power-saver clocks) never supersedes one made on AC.
        lines = [json.loads(l) for l in jl.read_text().splitlines() if l.strip()]
        byinv = {}
        for r in lines:
            byinv.setdefault((r['dataset'], r['stage'], r['config']), {}).setdefault(
                r.get('invocation', ''), []).append(r)
        bat = lambda rs: any(invalid_power(r) for r in rs)
        for invs in byinv.values():
            order = sorted(invs)
            good = [i for i in order if not bat(invs[i])]
            pick = good[-1] if good else order[-1]
            recs.extend(invs[pick])
            for i in order:
                if i != pick and bat(invs[i]) and i > pick:
                    INVALID.extend(invs[i])
    return recs


def summarise(recs):
    cells = {}
    for r in recs:
        cells.setdefault((r['dataset'], r['stage'], r['config']), []).append(r)
    out = []
    for (ds, st, cf), rs in cells.items():
        timed = [r for r in rs if r.get('status') in ('ok', 'reference')]
        status = rs[-1].get('status')
        if any(r.get('status') == 'mismatch' for r in rs):
            status = 'mismatch'
        elif any(r.get('status') == 'failed' for r in rs):
            status = 'failed'
        elif timed:
            status = 'ok'
        row = {'dataset': ds, 'stage': st, 'config': cf, 'status': status, 'n': len(timed),
               'genomes': rs[0].get('genomes'), 'note': rs[-1].get('note') or rs[-1].get('error'),
               'gpu_stages': rs[-1].get('gpu_stages')}
        if timed:
            g = lambda f: med([f(r) for r in timed])
            row.update(
                wall=g(lambda r: r['wall_seconds']), wall_min=min(r['wall_seconds'] for r in timed),
                wall_max=max(r['wall_seconds'] for r in timed),
                user=g(lambda r: r['user_seconds']), sys=g(lambda r: r['sys_seconds']),
                peak_mib=g(lambda r: (r['cgroup_memory_peak_bytes'] or 0) / 2**20),
                rss_mib=g(lambda r: r['max_rss_kib_largest_process'] / 1024),
                gpu_raw=g(lambda r: r['energy']['gpu_raw_joules']),
                gpu_net=g(lambda r: r['energy']['gpu_net_joules']),
                gpu_base_w=g(lambda r: r['energy']['gpu_baseline_watts']),
                cpu_raw=g(lambda r: r['energy']['cpu_raw_joules']),
                cpu_net=g(lambda r: r['energy']['cpu_net_joules']),
                gpu_mem_mib=g(lambda r: (r['run']['gpu_mem_own_processes_peak_bytes'] or 0) / 2**20),
                gpu_util_max=g(lambda r: r['run']['gpu_util_max_pct']),
                load=[r['uptime_before'].split('load average:')[-1].strip() for r in timed],
                on_battery=any(invalid_power(r) for r in rs),
                foreign_gpu=sorted({p for r in timed for w in ('run', 'baseline') if r.get(w)
                                    for p in r[w].get('gpu_foreign_compute_processes', [])}),
            )
        out.append(row)
    return out


def fmt(x, nd=2):
    return '–' if x is None else f'{x:.{nd}f}'


def report():
    recs = load_all()
    rows = summarise(recs)
    (EVID / 'summary.json').write_text(json.dumps(rows, indent=2) + '\n')
    meta = {p.stem.replace('.meta', ''): json.loads(p.read_text()) for p in EVID.glob('*.meta.json')}
    rapl = next((r['rapl'] for r in recs if 'rapl' in r), None)
    L = ['# Energy and GPU comparison: Vclust 1.3.1 vs Bend-C vs Bend-CUDA', '',
         'Generated by `tools/run_energy_matrix.py` (measurements by `tools/energy_bench.py`).',
         'Median over repeats (n = timed repeats; range in brackets). Every Bend cell\'s output is',
         'compared byte for byte with Vclust -t 12; `mismatch` cells are not timed successes.', '',
         '- **time**: wall seconds of the command tree inside its capped scope (excludes systemd-run start-up).',
         '- **board J raw**: NVML total-energy counter of the whole GPU board over the run window, for every',
         '  cell. CPU-only cells do not use the GPU: their raw value is the board idling (display, compositor)',
         '  for the duration, i.e. it scales with time and says nothing about the CPU work. **idle W** is the',
         '  board power of the idle baseline taken right before the run (same length, lock held).',
         '- **GPU net J** (GPU cells only): raw - idle W x run duration = energy the run added on the board;',
         '  **J/genome** = GPU net J / genomes. For CPU-only cells net is idle noise (+/- tens of J) and is not shown.',
         '- **CPU J**: ' + ('RAPL package energy.' if rapl and rapl['available'] else
                          'unavailable - RAPL `energy_uj` is root-only on this machine (' +
                          ', '.join(d.split(':')[0] + ':' + ':'.join(d.split(':')[1:2]) for d in (rapl or {}).get('unreadable', [])[:1]) +
                          ' ... PermissionError); not estimated.'),
         '- **peak MiB**: cgroup `memory.peak` of the scope (all processes + page cache + ~10 MB helper);',
         '  **RSS MiB**: largest single process max RSS. **GPU MiB**: device memory used by the run\'s own processes.',
         '- **x Vclust**: Vclust-t12 time divided by the cell\'s (> 1 = faster than Vclust -t 12). No energy ratio',
         '  vs Vclust is given: Vclust runs on the CPU only and CPU energy is unavailable.',
         '- Cluster stage: `' + ' '.join(CLUSTER_ARGS) + '`; align/cluster cells read Vclust\'s upstream outputs; e2e chains each tool\'s own stages.',
         '']
    for ds in sorted({r['dataset'] for r in rows}, key=lambda d: list(DATA).index(d)):
        dr = [r for r in rows if r['dataset'] == ds]
        g = dr[0]['genomes']
        L += [f'## {ds} ({g} genomes)', '']
        m = meta.get(ds)
        L += ['| stage | config | status | n | time s | user+sys s | peak MiB | RSS MiB | board J raw | idle W | GPU net J | J/genome (GPU net) | CPU J | GPU MiB | GPU util max % | x Vclust time | load avg (1 min) |',
              '| --- | --- | --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --- |']
        for st in STAGES:
            ref = next((r for r in dr if r['stage'] == st and r['config'] == 'vclust-t12' and r.get('wall')), None)
            for cf in CONFIGS:
                r = next((x for x in dr if x['stage'] == st and x['config'] == cf), None)
                if r is None:
                    continue
                if not r.get('wall'):
                    L.append(f"| {st} | {cf} | {r['status']} | 0 | | | | | | | | | | | | | {r.get('note') or ''} |")
                    continue
                sp = ref['wall'] / r['wall'] if ref else None
                gpu_cell = cf.startswith('bendgpu-')
                net = r['gpu_net'] if gpu_cell else None
                rng = f" [{r['wall_min']:.2f}-{r['wall_max']:.2f}]" if r['n'] > 1 else ''
                loads = ' / '.join(l.split(', ')[0] for l in r['load'])
                flag = ' (GPU-J contaminated)' if r.get('foreign_gpu') else ''
                if r.get('on_battery'):
                    flag += ' **(INVALID: battery / GPU power-capped)**'
                if r.get('gpu_stages') and st == 'e2e':
                    flag += ' (GPU: ' + '+'.join(r['gpu_stages']) + ')'
                L.append(f"| {st} | {cf} | {r['status']}{flag} | {r['n']} | {fmt(r['wall'])}{rng} | {fmt(r['user'] + r['sys'], 1)} | "
                         f"{fmt(r['peak_mib'], 0)} | {fmt(r['rss_mib'], 0)} | {fmt(r['gpu_raw'], 1)} | {fmt(r['gpu_base_w'], 1)} | {fmt(net, 1)} | "
                         f"{fmt(net / g if net is not None and g else None, 3)} | "
                         f"{fmt(r['cpu_net'], 1)} | {fmt(r['gpu_mem_mib'], 0) if gpu_cell else '–'} | "
                         f"{fmt(r['gpu_util_max'], 0) if gpu_cell else '–'} | {fmt(sp)} | {loads} |")
        L.append('')
        if m:
            L += ['Binaries: ' + ', '.join(f"{s} `{v['sha256'][:12]}`" for s, v in m['bend_binaries'].items()) +
                  '; GPU: ' + (', '.join(f"{s}: {v['note']}" for s, v in m['gpu_binaries'].items()) or
                               ('not attempted (`--gpu off`)' if m.get('gpu_mode') == 'off' else 'no GPU entry point found')), '']
        fg = sorted({p for r in dr for p in r.get('foreign_gpu', [])})
        if fg:
            L += ['Other GPU compute processes seen during these runs (energy contaminated): ' + ', '.join(fg), '']
    if INVALID:
        L += ['## Runs excluded as invalid (laptop on battery with CPU at 1.1 GHz, or GPU board capped at 20 W)', '',
              'Kept in the JSONL for the record; a valid AC run of the same cell is shown above instead.', '',
              '| dataset | stage | config | time s (median) | board J raw | idle W |', '| --- | --- | --- | --: | --: | --: |']
        for r in summarise(INVALID):
            L.append(f"| {r['dataset']} | {r['stage']} | {r['config']} | {fmt(r.get('wall'))} | "
                     f"{fmt(r.get('gpu_raw'), 1)} | {fmt(r.get('gpu_base_w'), 1)} |")
        L.append('')
    (EVID / 'RESULTS.md').write_text('\n'.join(L) + '\n')
    print('wrote', EVID / 'RESULTS.md')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--datasets', nargs='+', choices=DATA, default=['stratified1000'])
    ap.add_argument('--stages', nargs='+', choices=STAGES, default=list(STAGES))
    ap.add_argument('--configs', nargs='+', choices=CONFIGS, default=list(CONFIGS))
    ap.add_argument('--repeats', type=int, default=0, help='0 = 3 on small datasets, 1 on all_clean_contigs')
    ap.add_argument('--cap', default='3G')
    ap.add_argument('--timeout', type=float, default=600)
    ap.add_argument('--gpu', choices=['auto', 'off'], default='auto')
    ap.add_argument('--gpu-entry', action='append', default=[], metavar='STAGE=FILE.bend')
    ap.add_argument('--bins', help='directory with prebuilt prefilter/align/cluster binaries')
    ap.add_argument('--gpu-bin', action='append', default=[], metavar='STAGE=BINARY',
                    help='prebuilt GPU binary (its .gpu file beside it)')
    ap.add_argument('--baseline-default', type=float, default=5.0)
    ap.add_argument('--baseline-max', type=float, default=60.0)
    ap.add_argument('--report-only', action='store_true')
    a = ap.parse_args()
    if a.report_only:
        report()
    else:
        run_matrix(a)


if __name__ == '__main__':
    main()
