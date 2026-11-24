#!/usr/bin/env python3
"""Certify the 18 real-data outputs retained by the differential suite."""
from pathlib import Path
import json
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from reference_data import load
from verify_clusters import verify

def main():
    summary=[]
    for dataset in ('example','stratified1000','full'):
        _,_,ani,ids=load(dataset)
        for algo in ('single','complete','uclust','cd-hit','set-cover','leiden'):
            name=f'{dataset}-{algo}'
            out=ROOT/'.work/cluster-tests'/f'{name}.bend.tsv'
            cert=verify(ani,ids,out,algo,{'ani':.95},'ani')
            (ROOT/'evidence'/f'{name}.forest.json').write_text(json.dumps(cert,indent=2)+'\n')
            summary.append({'dataset':dataset,**{k:v for k,v in cert.items() if k not in ('root','parent','rank','star_seeds')}})
            print('PASS',name,cert['objects'],cert['clusters'],flush=True)
    (ROOT/'evidence/semantic-contracts.json').write_text(json.dumps(summary,indent=2)+'\n')

if __name__=='__main__': main()
