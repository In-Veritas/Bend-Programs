#!/usr/bin/env python3
"""Compare every cluster algorithm against the installed Vclust binary.

Run this script inside `capped`; children inherit its memory ceiling.
Each case has its own timeout and its output/command is retained on failure.
"""
import argparse
import hashlib
import json
import random
import subprocess
from pathlib import Path
from reference_data import load

PKG = Path(__file__).resolve().parents[1]
CLU = PKG.parent
SCRATCH = Path('/tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad')
VCLUST = CLU / '.tools/vclust-1.3.1/bin/vclust'
ALGORITHMS = ['single', 'complete', 'uclust', 'cd-hit', 'set-cover', 'leiden']

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--binary', type=Path, default=Path('/tmp/vclust-codex-cluster'))
    ap.add_argument('--full', action='store_true')
    ap.add_argument('--random', type=int, default=20)
    args = ap.parse_args()
    work = PKG / '.work/cluster-tests'
    work.mkdir(parents=True, exist_ok=True)
    cases = []
    for name in ['example','stratified1000'] + (['full'] if args.full else []):
        _,_,ani,ids=load(name)
        for algo in ALGORITHMS:
            cases.append((f'{name}-{algo}', ani, ids,
                          ['--algorithm', algo, '--metric', 'ani', '--ani', '0.95']))
    for seed in range(args.random):
        rng = random.Random(seed)
        n = rng.randrange(5, 45)
        ani, ids = work/f'random-{seed}.ani.tsv', work/f'random-{seed}.ids.tsv'
        ids.write_text('id\tseq_len\tno_parts\n'+''.join(f'seq{i}\t1000\t1\n' for i in range(n)))
        rows = ['qidx\tridx\tquery\treference\ttani\tgani\tani\tqcov\trcov\tnum_alns\tlen_ratio']
        for a in range(n):
            for b in range(a+1,n):
                if rng.random() < 0.22:
                    w = rng.choice([0.3,0.5,0.7,0.9,0.95,1.0])
                    rows.append(f'{a}\t{b}\tseq{a}\tseq{b}\t{w:.6f}\t{w:.6f}\t{w:.6f}\t1\t1\t1\t1')
        ani.write_text('\n'.join(rows)+'\n')
        for iters in (0,1,2,4):
            cases.append((f'random-{seed}-leiden-{iters}', ani, ids,
                          ['--algorithm','leiden','--metric','ani','--ani','0.1',
                           '--leiden-resolution',str(rng.choice([0.1,0.4,0.7,1.0])),
                           '--leiden-beta',str(rng.choice([0.01,0.1,0.5])),
                           '--leiden-iterations',str(iters)]))
    results = []
    for name, ani, ids, opts in cases:
        common = ['-i',str(ani),'--ids',str(ids)] + opts
        row = {'case': name, 'input':str(ani), 'options':opts}
        try:
            outputs = []
            for tool, prefix in [('reference',[str(VCLUST),'cluster']),('bend',[str(args.binary)])]:
                out = work/f'{name}.{tool}.tsv'
                cmd = prefix+common+['-o',str(out),'-v','0']
                if tool == 'bend': cmd += ['+RTS','--threads','1','-RTS']
                row[tool+'_command'] = cmd
                p = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
                if p.returncode:
                    raise RuntimeError(f'{tool}: exit {p.returncode}: {p.stderr[-2000:]} {p.stdout[-1000:]}')
                outputs.append(out.read_bytes())
            row['identical'] = outputs[0] == outputs[1]
            row['reference_sha256'] = hashlib.sha256(outputs[0]).hexdigest()
            row['bend_sha256'] = hashlib.sha256(outputs[1]).hexdigest()
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as e:
            row.update(identical=False, error=str(e))
        results.append(row)
        (work/'results.json').write_text(json.dumps(results,indent=2)+'\n')
        print(('PASS' if row['identical'] else 'FAIL'),name,row.get('error',''),flush=True)
    print(f'{sum(r["identical"] for r in results)}/{len(results)} identical',flush=True)
    raise SystemExit(0 if all(r['identical'] for r in results) else 1)

if __name__ == '__main__':
    main()
