#!/usr/bin/env python3
"""Adversarial output tests: plausible wrong TSVs must not be certified."""
import json
from pathlib import Path
import tempfile
from verify_clusters import verify

def main():
    results=[]
    with tempfile.TemporaryDirectory(prefix='vclust-certificate-') as tmp:
        d=Path(tmp);ids=d/'ids.tsv';ani=d/'ani.tsv';out=d/'clusters.tsv'
        ids.write_text('id\tlength\na\t100\nb\t100\nc\t100\nd\t100\n')
        ani.write_text('qidx\tridx\tani\n0\t1\t0.99\n1\t2\t0.99\n2\t3\t0.99\n')
        def test(name,algo,rows,accept):
            out.write_text('object\tcluster\n'+''.join(f'{obj}\t{label}\n' for obj,label in rows))
            try: verify(ani,ids,out,algo,{'ani':.95});accepted=True;reason='accepted'
            except ValueError as e: accepted=False;reason=str(e)
            if accepted!=accept: raise AssertionError(f'{name}: {reason}')
            results.append({'case':name,'expected_accept':accept,'actual_accept':accepted,'reason':reason})
            print('PASS',name,reason)
        whole=[(x,0) for x in 'abcd']
        test('valid single chain','single',whole,True)
        test('unknown algorithm contract','unknown',whole,False)
        test('complete must reject chain','complete',whole,False)
        test('single must reject split component','single',[(x,i//2) for i,x in enumerate('abcd')],False)
        test('leiden must reject disconnected group','leiden',[('a',0),('b',1),('c',0),('d',1)],False)
        for algo in ('uclust','cd-hit','set-cover'):
            test(algo+' must reject no-star chain',algo,whole,False)
        test('missing object','single',whole[:-1],False)
        test('duplicate object','single',whole+[('a',0)],False)
        test('unknown object','single',whole+[('z',0)],False)
        test('valid complete split','complete',[(x,i//2) for i,x in enumerate('abcd')],True)
    evidence=Path(__file__).resolve().parents[1]/'evidence/certificate-negative-tests.json'
    evidence.write_text(json.dumps(results,indent=2)+'\n')

if __name__=='__main__': main()
