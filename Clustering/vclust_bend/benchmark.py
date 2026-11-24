#!/usr/bin/env python3
"""Sequential, capped head-to-head pipeline timings; exact outputs are checked."""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import platform
import subprocess
import time
import run as launcher

ROOT=Path(__file__).resolve().parent
VC=ROOT.parent/'.tools/vclust-1.3.1/bin/vclust'
DATA={
 'stratified1000':ROOT.parent/'datasets/infant_gut_virome/ready/earlyvir_stratified1000.fasta',
 'full':ROOT.parent/'datasets/infant_gut_virome/raw/all.curated.vOTUs.EarlyVir.fna'}

def measured(cmd,log,timeout):
    timing=log.with_suffix('.time')
    actual=['/usr/bin/time','-f','%e\t%M','-o',str(timing),*map(str,cmd)]
    with log.open('w') as out, subprocess.Popen(actual,stdout=out,stderr=out,start_new_session=True) as p:
        try: code=p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid,signal.SIGKILL);p.wait();raise
    if code: raise RuntimeError(f'exit {code}; see {log}')
    wall,rss=timing.read_text().strip().splitlines()[-1].split('\t')
    return {'wall_seconds':float(wall),'max_rss_kib':int(rss),'command':list(map(str,cmd))}

def main():
    p=argparse.ArgumentParser();p.add_argument('--datasets',nargs='+',choices=DATA,default=['stratified1000','full'])
    p.add_argument('--threads',nargs='+',type=int,default=[1,12]);p.add_argument('--timeout',type=int,default=1200)
    p.add_argument('--report',type=Path,default=ROOT/'evidence/benchmark.json')
    a=p.parse_args();bins={s:launcher.build(s) for s in ('prefilter','align','cluster')}
    base=ROOT/'.work/benchmark';base.mkdir(parents=True,exist_ok=True)
    work=base/datetime.datetime.now().strftime('%Y%m%dT%H%M%S.%f')
    work.mkdir()
    report={'created_at':datetime.datetime.now().astimezone().isoformat(),'repetitions':1,
            'work_directory':str(work),
            'platform':platform.platform(),
            'native_sha256':{stage:hashlib.sha256(binary.read_bytes()).hexdigest() for stage,binary in bins.items()},
            'note':'Single sequential samples in fixed Vclust-then-Bend order; page cache not flushed; build excluded. Vclust timings include its Python CLI; Bend timings invoke native executables directly and exclude run.py and the independent Python semantic verifier. Native partition/clique guards are included. Clusty has no thread flag.',
            'runs':[]}
    with (base/'benchmark.lock').open('w') as lock:
      fcntl.flock(lock,fcntl.LOCK_EX)
      for dataset in a.datasets:
       for threads in a.threads:
        outputs={}
        for tool in ('vclust','bend'):
          folder=work/f'{dataset}-t{threads}-{tool}';folder.mkdir(exist_ok=True)
          flt,ani,cl=folder/'fltr.txt',folder/'ani.tsv',folder/'clusters.tsv'
          common={
            'prefilter':['-i',DATA[dataset],'-o',flt],
            'align':['-i',DATA[dataset],'-o',ani,'--filter',flt],
            'cluster':['-i',ani,'--ids',folder/'ani.ids.tsv','-o',cl,'--algorithm','leiden','--metric','ani','--ani','0.95']}
          for stage in ('prefilter','align','cluster'):
            row={'dataset':dataset,'threads':threads,'tool':tool,'stage':stage,
                 'uptime':subprocess.check_output(['uptime'],text=True).strip()}
            cmd=([VC,stage,*common[stage],*(['-t',threads] if stage!='cluster' else []),'-v','0'] if tool=='vclust' else
                 [bins[stage],*common[stage],'+RTS','--threads',threads,'-RTS'])
            try: row.update(measured(cmd,folder/f'{stage}.log',a.timeout),status='ok')
            except (OSError,RuntimeError,subprocess.TimeoutExpired) as e: row.update(status='failed',error=str(e))
            report['runs'].append(row)
            a.report.write_text(json.dumps(report,indent=2)+'\n')
            print(dataset,threads,tool,stage,row.get('wall_seconds'),row.get('max_rss_kib'),row['status'],flush=True)
            if row['status']!='ok': break
          outputs[tool]=folder
        comparisons={}
        for filename in ('fltr.txt','ani.tsv','ani.ids.tsv','clusters.tsv'):
            x,y=outputs['vclust']/filename,outputs['bend']/filename
            if x.exists() and y.exists():
                with x.open('rb') as f: hx=hashlib.file_digest(f,'sha256').hexdigest()
                with y.open('rb') as f: hy=hashlib.file_digest(f,'sha256').hexdigest()
                comparisons[filename]={'identical':hx==hy,'reference_sha256':hx,'bend_sha256':hy}
            else: comparisons[filename]={'identical':False,'missing':True}
        report.setdefault('comparisons',[]).append({'dataset':dataset,'threads':threads,'files':comparisons})
        a.report.write_text(json.dumps(report,indent=2)+'\n')
        print('COMPARE',dataset,threads,all(x['identical'] for x in comparisons.values()),flush=True)
    raise SystemExit(0 if all(r['status']=='ok' for r in report['runs']) and
                     all(f['identical'] for c in report['comparisons'] for f in c['files'].values()) else 1)

if __name__=='__main__': main()
