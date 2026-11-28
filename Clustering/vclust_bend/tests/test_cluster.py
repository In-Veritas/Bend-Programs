#!/usr/bin/env python3
"""Differential test of the Bend `cluster` stage against `vclust cluster`.

Every case runs the installed Vclust 1.3.1 (Clusty 1.2.2) and the native
Bend binary on the same ani.tsv / ani.ids.tsv and requires byte-identical
clusters.tsv. Matrix: all six algorithms x metric/threshold/filter settings
(incl. -r, --qcov, --rcov, --len_ratio, --num_alns and Leiden parameters) on
the ANI tables that `vclust align` produced for vclust_example,
stratified1000 and (with --full) the whole EarlyVir reference; plus random
small graphs for Leiden with 0/1/2/4 iterations.

Run inside `capped` (children inherit the memory ceiling), e.g.
  CAP=3G capped python3 tests/test_cluster.py --full
Without --binary the stage is built through run.py (cached in .work/bin).
"""
import argparse
import hashlib
import json
import random
import subprocess
import sys
import time
from pathlib import Path
from reference_data import load

PKG = Path(__file__).resolve().parents[1]
CLU = PKG.parent
VCLUST = CLU / '.tools/vclust-1.3.1/bin/vclust'
ALGORITHMS = ['single', 'complete', 'uclust', 'cd-hit', 'set-cover', 'leiden']

# (label, options) per dataset; every setting runs for every algorithm
SETTINGS = [
    ('ani95', ['--metric', 'ani', '--ani', '0.95']),
    ('ani95-r-qcov', ['--metric', 'ani', '--ani', '0.95', '--qcov', '0.85', '-r']),
    ('tani50', ['--metric', 'tani', '--tani', '0.5']),
    ('tani30-r', ['--metric', 'tani', '--tani', '0.3', '-r']),
    ('gani70-rcov-lr', ['--metric', 'gani', '--gani', '0.7', '--rcov', '0.5', '--len_ratio', '0.6']),
    ('gani30-nalns-r', ['--metric', 'gani', '--gani', '0.3', '--num_alns', '5', '-r']),
    ('ani80-all', ['--metric', 'ani', '--ani', '0.8', '--tani', '0.4', '--gani', '0.4', '--qcov', '0.3']),
]
LEIDEN_EXTRA = [
    ('leiden-params', ['--metric', 'ani', '--ani', '0.8', '--leiden-resolution', '0.2',
                       '--leiden-beta', '0.05', '--leiden-iterations', '3']),
    ('leiden-until', ['--metric', 'gani', '--gani', '0.5', '--leiden-resolution', '1',
                      '--leiden-iterations', '-1']),
]


def build_binary():
    out = subprocess.run([sys.executable, str(PKG / 'run.py'), 'cluster', '--build-only'],
                         check=True, capture_output=True, text=True)
    return Path(out.stdout.strip().splitlines()[-1])


def random_cases(work, count):
    cases = []
    for seed in range(count):
        rng = random.Random(seed)
        n = rng.randrange(5, 45)
        ani, ids = work / f'random-{seed}.ani.tsv', work / f'random-{seed}.ids.tsv'
        ids.write_text('id\tseq_len\tno_parts\n' + ''.join(f'seq{i}\t1000\t1\n' for i in range(n)))
        rows = ['qidx\tridx\tquery\treference\ttani\tgani\tani\tqcov\trcov\tnum_alns\tlen_ratio']
        for a in range(n):
            for b in range(a + 1, n):
                if rng.random() < 0.22:
                    w = rng.choice([0.3, 0.5, 0.7, 0.9, 0.95, 1.0])
                    rows.append(f'{a}\t{b}\tseq{a}\tseq{b}\t{w:.6f}\t{w:.6f}\t{w:.6f}\t1\t1\t1\t1')
        ani.write_text('\n'.join(rows) + '\n')
        for iters in (0, 1, 2, 4):
            cases.append((f'random-{seed}-leiden-{iters}', ani, ids,
                          ['--algorithm', 'leiden', '--metric', 'ani', '--ani', '0.1',
                           '--leiden-resolution', str(rng.choice([0.1, 0.4, 0.7, 1.0])),
                           '--leiden-beta', str(rng.choice([0.01, 0.1, 0.5])),
                           '--leiden-iterations', str(iters)]))
        # heavily tied distances: complete linkage's (d, row, column) key order,
        # BFS order, seed choices
        for algo in ('complete', 'single', 'uclust', 'cd-hit', 'set-cover'):
            for t in ('0.5', '0.9'):
                cases.append((f'random-{seed}-{algo}-{t}', ani, ids,
                              ['--algorithm', algo, '--metric', 'ani', '--ani', t]))
    return cases


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--binary', type=Path)
    ap.add_argument('--full', action='store_true', help='also the full EarlyVir table')
    ap.add_argument('--random', type=int, default=20)
    ap.add_argument('--threads', type=int, default=1)
    ap.add_argument('--quick', action='store_true', help='only the ani95 setting')
    args = ap.parse_args()
    binary = args.binary or build_binary()
    work = PKG / '.work/cluster-tests'
    work.mkdir(parents=True, exist_ok=True)
    cases = []
    for name in ['example', 'stratified1000'] + (['full'] if args.full else []):
        _, _, ani, ids = load(name)
        settings = SETTINGS[:1] if args.quick else SETTINGS
        for label, opts in settings:
            for algo in ALGORITHMS:
                cases.append((f'{name}-{algo}-{label}', ani, ids, ['--algorithm', algo] + opts))
        if not args.quick:
            for label, opts in LEIDEN_EXTRA:
                cases.append((f'{name}-{label}', ani, ids, ['--algorithm', 'leiden'] + opts))
    cases += random_cases(work, args.random)
    results = []
    for name, ani, ids, opts in cases:
        common = ['-i', str(ani), '--ids', str(ids)] + opts
        row = {'case': name, 'input': str(ani), 'options': opts}
        try:
            outputs = []
            for tool, prefix in [('reference', [str(VCLUST), 'cluster']), ('bend', [str(binary)])]:
                out = work / f'{name}.{tool}.tsv'
                cmd = prefix + common + ['-o', str(out), '-v', '0']
                if tool == 'bend':
                    cmd += ['+RTS', '--threads', str(args.threads), '-RTS']
                row[tool + '_command'] = cmd
                t = time.time()
                p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
                row[tool + '_seconds'] = round(time.time() - t, 3)
                if p.returncode:
                    raise RuntimeError(f'{tool}: exit {p.returncode}: {p.stderr[-2000:]} {p.stdout[-1000:]}')
                outputs.append(out.read_bytes())
            row['identical'] = outputs[0] == outputs[1]
            row['rows'] = outputs[0].count(b'\n') - 1
            row['reference_sha256'] = hashlib.sha256(outputs[0]).hexdigest()
            row['bend_sha256'] = hashlib.sha256(outputs[1]).hexdigest()
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as e:
            row.update(identical=False, error=str(e))
        results.append(row)
        (work / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
        print(('PASS' if row['identical'] else 'FAIL'), name,
              row.get('error', f"{row.get('rows')} rows, vclust {row.get('reference_seconds')} s, "
                               f"bend {row.get('bend_seconds')} s"), flush=True)
    print(f'{sum(r["identical"] for r in results)}/{len(results)} identical', flush=True)
    raise SystemExit(0 if all(r['identical'] for r in results) else 1)


if __name__ == '__main__':
    main()
