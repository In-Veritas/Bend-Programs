#!/usr/bin/env python3
"""Exercise the shipped launcher, certificates and output preservation."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from reference_data import ROOT,VC,load

def main():
    fa,reference_filter,reference_ani,reference_ids=load('example')
    work=ROOT/'.work/cli-tests';work.mkdir(parents=True,exist_ok=True)
    results=[]
    def run(stage,args,success=True):
        cmd=[sys.executable,ROOT/'run.py',stage,*map(str,args)]
        p=subprocess.run(cmd,capture_output=True,text=True,timeout=120)
        if (p.returncode==0)!=success: raise AssertionError(p.stdout+p.stderr)
        results.append({'command':list(map(str,cmd)),'exit_code':p.returncode,'expected_success':success})
    flt=work/'filter.txt';ani=work/'ani.tsv';out=work/'clusters.tsv'
    run('prefilter',['-i',fa,'-o',flt,'-t','2'])
    assert flt.read_bytes()==reference_filter.read_bytes()
    run('align',['-i',fa,'--filter',flt,'-o',ani,'-t','2'])
    assert ani.read_bytes()==reference_ani.read_bytes()
    assert ani.with_suffix('.ids.tsv').read_bytes()==reference_ids.read_bytes()
    for algo in ('single','complete','uclust','cd-hit','set-cover','leiden'):
        for representative in (False,True):
            opts=['-i',ani,'--ids',ani.with_suffix('.ids.tsv'),'--algorithm',algo,'--metric','ani','--ani','.95']
            if representative: opts+=['-r']
            run('cluster',opts+['-o',out])
            ref=work/'reference.tsv'
            subprocess.run(list(map(str,[VC,'cluster',*opts,'-o',ref,'-v','0'])),check=True,capture_output=True)
            assert out.read_bytes()==ref.read_bytes(),(algo,representative)
            cert=json.loads(Path(str(out)+'.certificate.json').read_text())
            assert cert['output_sha256']==hashlib.sha256(out.read_bytes()).hexdigest()
            assert cert['objects']==12 and cert['partition'] and cert['connected']
    previous=out.read_bytes()
    run('cluster',['-i',ani,'--ids',reference_ids,'-o',out,'--metric','nonsense'],False)
    assert out.read_bytes()==previous
    ani_before=ani.read_bytes()
    run('cluster',['-i',ani,'--ids',reference_ids,'-o',ani,'--ani','.95','--metric','ani'],False)
    assert ani.read_bytes()==ani_before
    run('cluster',['-i',ani,'--ids',reference_ids,'-o',out,'--out',ani,'--ani','.95','--metric','ani'],False)
    assert ani.read_bytes()==ani_before and out.read_bytes()==previous
    (ROOT/'evidence/cli-integration.json').write_text(json.dumps(results,indent=2)+'\n')
    print('PASS launcher pipeline, all algorithms and representatives, certificates, input/output preservation')

if __name__=='__main__': main()
