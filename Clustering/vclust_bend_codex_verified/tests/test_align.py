#!/usr/bin/env python3
"""Differential LZ-ANI tests with exact comparison of both output files."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
from reference_data import load

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('launcher',ROOT/'run.py')
launcher=importlib.util.module_from_spec(spec); spec.loader.exec_module(launcher)
SCRATCH=Path('/tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad')
CLU=ROOT.parent
VC=CLU/'.tools/vclust-1.3.1/bin/vclust'

def run(cmd, timeout=180):
    with subprocess.Popen(list(map(str,cmd)),stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                          text=True,start_new_session=True) as p:
        try: out,err=p.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid,signal.SIGKILL);p.wait();raise
        if p.returncode: raise RuntimeError(f'exit {p.returncode}: {err[-2000:]} {out[-1000:]}')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--full',action='store_true')
    ap.add_argument('--threads',type=int,default=1);args=ap.parse_args()
    if not 1<=args.threads<=256: ap.error('threads must be in 1..256')
    binary=launcher.build('align');work=ROOT/'.work/align-tests';work.mkdir(parents=True,exist_ok=True)
    datasets=[
      ('example',CLU/'datasets/public_viromes/original/vclust_example.fasta',SCRATCH/'vc/fltr.txt',SCRATCH/'vc/ani.tsv'),
      ('prefix1000',CLU/'datasets/public_viromes/ready/vclust_example_prefix1000.fasta',SCRATCH/'al/ref/vclust_example_prefix1000.fltr.txt',SCRATCH/'al/ref/vclust_example_prefix1000.ani.tsv'),
      ('shortest1000',CLU/'datasets/infant_gut_virome/ready/earlyvir_shortest1000.fasta',SCRATCH/'al/ref/earlyvir_shortest1000.fltr.txt',SCRATCH/'al/ref/earlyvir_shortest1000.ani.tsv'),
      ('stratified1000',CLU/'datasets/infant_gut_virome/ready/earlyvir_stratified1000.fasta',SCRATCH/'vc/s1000/fltr12.txt',SCRATCH/'vc/s1000/ani12.tsv')]
    if args.full: datasets.append(('full',CLU/'datasets/infant_gut_virome/raw/all.curated.vOTUs.EarlyVir.fna',SCRATCH/'vc/full/fltr12.txt',SCRATCH/'vc/full/ani12.tsv'))
    results=[]
    for name,fa,flt,baseline in datasets:
        fa,flt,baseline,_=load(name)
        variants=[[]]
        if name in ('example','prefix1000'):
            variants += [['--outfmt','lite'],['--outfmt','complete'],['--out-ani','0.95'],['--filter-threshold','0.8'],['--mal','12','--msl','8']]
        for i,opts in enumerate(variants):
            ref=baseline if not opts else work/f'{name}-{i}.reference.tsv'
            out=work/f'{name}-{i}.bend.tsv'
            row={'dataset':name,'options':opts,'fasta':str(fa),'filter':str(flt),'reference':str(ref)}
            try:
                if opts: run([VC,'align','-i',fa,'--filter',flt,'-o',ref,'-t','1','-v','0',*opts])
                cmd=[binary,'-i',fa,'--filter',flt,'-o',out,*opts,'+RTS','--threads',str(args.threads),'-RTS']
                row['command']=list(map(str,cmd));run(cmd,timeout=600 if name=='full' else 180)
                checks={}
                for suffix,a,b in [('table',ref,out),('ids',ref.with_suffix('.ids.tsv'),out.with_suffix('.ids.tsv'))]:
                    av,bv=a.read_bytes(),b.read_bytes()
                    checks[suffix]={'identical':av==bv,'reference_sha256':hashlib.sha256(av).hexdigest(),'bend_sha256':hashlib.sha256(bv).hexdigest()}
                row.update(checks=checks,identical=all(c['identical'] for c in checks.values()))
            except (OSError,RuntimeError,subprocess.TimeoutExpired) as e: row.update(identical=False,error=str(e))
            results.append(row);(work/'results.json').write_text(json.dumps(results,indent=2)+'\n')
            print('PASS' if row['identical'] else 'FAIL',name,opts,row.get('error',''),flush=True)
    print(f'{sum(r["identical"] for r in results)}/{len(results)} identical')
    raise SystemExit(0 if all(r['identical'] for r in results) else 1)

if __name__=='__main__': main()
