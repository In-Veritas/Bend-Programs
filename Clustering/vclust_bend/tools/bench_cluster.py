#!/usr/bin/env python3
"""Cluster-stage timings: Bend (1 and 12 workers) vs Vclust/Clusty 1.2.2.

Every measured command runs under the shared bench lock and `capped`, through
/usr/bin/time (wall, user, sys, max RSS). Reported per case:
  vclust  - the official `vclust cluster` CLI (Python + Clusty), end to end;
  clusty  - the bundled Clusty binary with the exact arguments vclust passes,
            end to end, plus its own printed clustering-kernel time;
  bend-tN - the Bend binary with N workers, end to end, plus its phase times
            (CLUSTER_TIMING=1: parse, build, kernel, certify+render, write).
Outputs are compared byte for byte. Usage:
  python3 tools/bench_cluster.py --binary BIN --dataset full --out evidence/x.json
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

PKG = Path(__file__).resolve().parents[1]
CLU = PKG.parent
VCLUST = CLU / '.tools/vclust-1.3.1/bin/vclust'
CLUSTY = CLU / '.tools/vclust-1.3.1/lib/python3.14/site-packages/bin/clusty'
LOCK = os.environ.get('BENCH_LOCK') or str(Path(__file__).resolve().parents[1] / '.work' / 'bench.lock')
sys.path.insert(0, str(PKG / 'tests'))
from reference_data import load  # noqa: E402

ALGOS = ['single', 'complete', 'uclust', 'cd-hit', 'set-cover', 'leiden']


def timed(cmd, env=None):
    full = ['flock', LOCK, 'capped', '/usr/bin/time', '-f', 'TIME %e %U %S %M'] + [str(c) for c in cmd]
    e = dict(os.environ, **(env or {}))
    up = open('/proc/loadavg').read().split()[0]
    p = subprocess.run(full, capture_output=True, text=True, env=e, timeout=600)
    if p.returncode:
        raise RuntimeError(f'{cmd}: {p.stderr[-1500:]}')
    m = re.findall(r'TIME ([\d.]+) ([\d.]+) ([\d.]+) (\d+)', p.stderr)[-1]
    return {'wall_s': float(m[0]), 'user_s': float(m[1]), 'sys_s': float(m[2]),
            'rss_kb': int(m[3]), 'loadavg_1m_before': float(up), 'stdout': p.stdout[-2000:],
            'stderr': p.stderr[-2000:]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--binary', type=Path, required=True)
    ap.add_argument('--dataset', default='full')
    ap.add_argument('--metric', default='ani')
    ap.add_argument('--threshold', default='0.95')
    ap.add_argument('--threads', type=int, nargs='+', default=[1, 12])
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    _, _, ani, ids = load(args.dataset)
    work = PKG / '.work/bench-cluster'
    work.mkdir(parents=True, exist_ok=True)
    results = []
    for algo in ALGOS:
        opts = ['--algorithm', algo, '--metric', args.metric, f'--{args.metric}', args.threshold]
        row = {'dataset': args.dataset, 'algorithm': algo, 'options': opts}
        ref = work / f'{algo}.vclust.tsv'
        row['vclust'] = timed([VCLUST, 'cluster', '-i', ani, '--ids', ids, '-o', ref, '-v', '0'] + opts)
        out = work / f'{algo}.clusty.tsv'
        clusty_cmd = [CLUSTY, '--objects-file', ids, '--algo', algo, '--id-cols', 'qidx', 'ridx',
                      '--distance-col', args.metric, '--similarity', '--numeric-ids',
                      '--min', args.metric, args.threshold]
        if algo == 'leiden':
            clusty_cmd += ['--leiden-resolution', '0.7', '--leiden-beta', '0.01', '--leiden-iterations', '2']
        row['clusty'] = timed(clusty_cmd + [ani, out])
        k = re.search(r'Clustering \(algorithm[^\n]*\n(?:.*\n)*?\s*time \[s\]: ([\d.e+-]+)', row['clusty']['stdout'] + row['clusty']['stderr'])
        row['clusty']['kernel_s'] = float(k.group(1)) if k else None
        load_t = re.search(r'Loading pairwise distances[^\n]*\n(?:.*\n)*?\s*time \[s\]: ([\d.e+-]+)', row['clusty']['stdout'] + row['clusty']['stderr'])
        row['clusty']['load_s'] = float(load_t.group(1)) if load_t else None
        refb = ref.read_bytes()
        row['clusty']['identical'] = out.read_bytes() == refb
        for t in args.threads:
            bout = work / f'{algo}.bend-t{t}.tsv'
            r = timed([args.binary, '-i', ani, '--ids', ids, '-o', bout] + opts + ['+RTS', '--threads', t, '-RTS'],
                      env={'CLUSTER_TIMING': '1'})
            ph = re.search(r'parse (\d+) build (\d+) kernel (\d+) certify\+render (\d+) write (\d+)', r['stderr'])
            if ph:
                r['phases_ms'] = dict(zip(['parse', 'build', 'kernel', 'certify_render', 'write'], map(int, ph.groups())))
            r['identical'] = bout.read_bytes() == refb
            row[f'bend-t{t}'] = r
        for v in row.values():
            if isinstance(v, dict):
                v.pop('stdout', None)
        results.append(row)
        args.out.write_text(json.dumps(results, indent=2) + '\n')
        print(algo, {k: (v.get('wall_s'), v.get('rss_kb'), v.get('identical'), v.get('kernel_s') or v.get('phases_ms'))
                     for k, v in row.items() if isinstance(v, dict)}, flush=True)


if __name__ == '__main__':
    main()
