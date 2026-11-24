#!/usr/bin/env python3
"""Project-scoped validation entry: no arbitrary command execution arguments."""
import argparse
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('vclust_bend_run',ROOT/'run.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

def main():
    p=argparse.ArgumentParser()
    p.add_argument('action',choices=['build','check','proofs','guards','cli-tests','semantics','certified-timings','benchmark','cluster-tests','prefilter-tests','align-tests'])
    p.add_argument('stage',nargs='?',choices=['prefilter','align','cluster'])
    p.add_argument('--full',action='store_true')
    p.add_argument('--threads',type=int)
    args=p.parse_args()
    command,_=launcher.compiler()
    if args.action=='build':
        print(launcher.build(args.stage or 'cluster'))
    elif args.action=='check':
        for stage in ([args.stage] if args.stage else ['prefilter','align','cluster']):
            launcher.capped([*command,ROOT/f'{stage}.bend','--check-only'],'8G',cwd=ROOT)
    elif args.action=='proofs':
        os.environ['PATH']='/home/veritas/.local/opt/lean-4.34.0/bin:'+os.environ['PATH']
        records=[]
        entries=[(ROOT/f'{name}.bend',[*command,ROOT/f'{name}.bend','--verdict']) for name in ['partition_certificate','clique_certificate']]
        entries.append((ROOT/'proofs/Forest.lean',['lean',ROOT/'proofs/Forest.lean']))
        for source,cmd in entries:
            result=launcher.capped(cmd,'8G',cwd=ROOT,capture_output=True,text=True)
            print(result.stdout,result.stderr,flush=True)
            record={'file':str(source.relative_to(ROOT)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                    'command':list(map(str,cmd)),'exit_code':result.returncode,'stdout':result.stdout,'stderr':result.stderr}
            records.append(record)
            (ROOT/'evidence/proof-verdicts.json').write_text(json.dumps(records,indent=2)+'\n')
    elif args.action=='guards':
        binary=ROOT/'.work/certificate-runtime'
        launcher.capped([*command,ROOT/'tests/certificate_runtime.bend','-o',binary],'8G',cwd=ROOT)
        result=launcher.capped([binary],'1G',cwd=ROOT,capture_output=True,text=True)
        if result.stdout.strip()!='True{}': raise RuntimeError(result.stdout+result.stderr)
        record={'exit_code':result.returncode,'stdout':result.stdout,'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),
                'sources':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in
                           ('cluster.bend','partition_certificate.bend','clique_certificate.bend','tests/certificate_runtime.bend')}}
        (ROOT/'evidence/native-guards.json').write_text(json.dumps(record,indent=2)+'\n')
        print('PASS native rejects invalid partition and invalid complete clique',flush=True)
        launcher.capped([sys.executable,ROOT/'tests/test_certificates.py'],'1G',cwd=ROOT)
    elif args.action=='benchmark':
        for stage in ('prefilter','align','cluster'): launcher.build(stage)
        datasets=['stratified1000','full'] if args.full else ['stratified1000']
        threads=[args.threads] if args.threads else [1,12]
        report=ROOT/'evidence'/('benchmark-'+'-'.join(datasets)+'-t'+'-'.join(map(str,threads))+'.json')
        launcher.capped([sys.executable,ROOT/'benchmark.py','--datasets',*datasets,'--threads',*map(str,threads),'--report',report],'4G',cwd=ROOT)
    elif args.action=='cli-tests':
        for stage in ('prefilter','align','cluster'): launcher.build(stage)
        launcher.capped([sys.executable,ROOT/'tests/test_cli.py'],'3G',cwd=ROOT)
    elif args.action in ('semantics','certified-timings'):
        script='certify_existing.py' if args.action=='semantics' else 'measure_certified_cluster.py'
        launcher.capped([sys.executable,ROOT/'tools'/script],'3G',cwd=ROOT)
    elif args.action=='cluster-tests':
        binary=launcher.build('cluster')
        launcher.capped([sys.executable,ROOT/'tests/test_cluster.py','--binary',binary,
                        *(['--full'] if args.full else [])],'3G',cwd=ROOT)
    else:
        test='test_prefilter.py' if args.action=='prefilter-tests' else 'test_align.py'
        launcher.capped([sys.executable,ROOT/'tests'/test,*(['--full'] if args.full else []),
                        *(['--threads',str(args.threads or 1)] if args.action=='align-tests' else [])],'4G',cwd=ROOT)

if __name__=='__main__':
    main()
