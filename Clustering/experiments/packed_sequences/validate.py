#!/usr/bin/env python3
"""Validate both snapshots, packed word boundaries, and exact pairwise scores."""
import csv
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import time

from benchmark import HERE, ROOT, module


ROUNDTRIP = '''import Base
import ./lib/common.bend as C
def output(dataset: C.Dataset) -> IO(Unit):
  match dataset:
    case C.Dataset{items, size}:
      C.output(items, C.labels_identity(size))
def main() -> IO(Unit):
  do IO<Unit>:
    dataset: C.Dataset <- C.fasta_read(1)
    output(dataset)
'''
SCORES = '''import Base
import ./lib/common.bend as C
def print_cells(fuel: Nat, +index: U32, values: Array<U32>) -> IO(Unit):
  match fuel:
    case Zero{}: IO.pure(Unit, Unit{})
    case Succ{rest}:
      C.apply(Array<U32> & U32, IO(Unit), \\{Tuple: next => value => (
        do IO<Unit>:
          printed: Unit <- IO.print(U32.show(value))
          print_cells(rest, U32.add(index, 1), next)
      )}, Array.get(U32, values, index))
def output(dataset: C.Dataset, reverse: Bool) -> IO(Unit):
  match dataset:
    case C.Dataset{items, +size}:
      print_cells(C.to_nat(U32.mul(size, size)), 0, C.matrix_build(items, size, reverse))
def main() -> IO(Unit):
  do IO<Unit>:
    dataset: C.Dataset <- C.fasta_read(1)
    reverse: U32 <- C.env_number("CLUSTER_REVERSE", "0", 1)
    output(dataset, U32.is_eq(reverse, 1))
'''


def main():
    compiler = module('production', ROOT/'run.py').default_compiler().resolve()
    results = HERE/'results'; results.mkdir(exist_ok=True)
    env = dict(os.environ, BEND_REPO=str(compiler), BEND_NO_TELEMETRY='1')
    report = {'compiler': str(compiler), 'checks': []}
    for variant in ('baseline', 'packed'):
        start = time.perf_counter()
        with (results/f'validation_{variant}.log').open('w') as log:
            subprocess.run([sys.executable,str(HERE/variant/'tests/test_clustering.py')],
                           env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
        report['checks'].append(dict(variant=variant, tests=22, seconds=time.perf_counter()-start))
        print(variant, '22 original tests passed', flush=True)

    rng = random.Random(4281)
    lengths = [1,2,7,8,9,15,16,17,31,32,33,63,64,65,127,128,129,255,256,257,1000,30000]
    sequences = [''.join(rng.choices(alphabet,k=n)) for alphabet in ('ACGT','ACGTRYSWKMBDHVN') for n in lengths]
    sequences += ['acgu', 'NNNN', 'ARYKMBDHVSWN']
    fixture = HERE/'inputs/packing_boundaries.fasta'
    fixture.parent.mkdir(exist_ok=True)
    fixture.write_text(''.join(f'>record_{i}\n{s}\n' for i,s in enumerate(sequences)))
    normalized = [s.upper().replace('U','T') for s in sequences]
    expected_fasta = ''.join(f'>record_{i}\n' + '\n'.join(s[j:j+80] for j in range(0,len(s),80))+'\n'
                             for i,s in enumerate(normalized))
    oracle = module('oracle', ROOT/'tests/test_clustering.py')
    score_sequences = normalized[:19]+normalized[22:41]+['ACGT'*8,'ACGT'*3+'N'+'ACGT'*5,'ACGT'*3+'A'+'ACGT'*5]
    score_file=HERE/'inputs/alignment_boundaries.fasta'
    score_file.write_text(''.join(f'>pair_{i}\n{s}\n' for i,s in enumerate(score_sequences)))
    expected_scores={reverse:[oracle.similarity(a,b,reverse=reverse) for a in score_sequences for b in score_sequences]
                     for reverse in (False,True)}
    for variant in ('baseline','packed'):
        for name, source in (('roundtrip',ROUNDTRIP),('pair_scores',SCORES)):
            path=HERE/variant/(name+'.bend');path.write_text(source)
            for backend in ('c','js'):
                emitted=results/f'{variant}_{name}.{backend}'
                subprocess.run(['bun',str(compiler/'bend2/main.ts'),str(path),'-o',str(emitted)],env=env,check=True)
                if backend=='c':
                    binary=results/f'{variant}_{name}.bin'
                    subprocess.run(['clang','-O2','-std=c11','-lpthread','-lm',str(emitted),'-o',str(binary)],check=True)
                    command=[str(binary),'--threads','1','--gpu','off']
                else: command=['bun',str(emitted)]
                if name=='roundtrip':
                    reps=results/'roundtrip.fasta'
                    process=subprocess.run(command,env=dict(env,CLUSTER_INPUT=str(fixture),CLUSTER_REPRESENTATIVES=str(reps)),
                                           capture_output=True,text=True,check=True,timeout=60)
                    assert not process.stderr, process.stderr
                    assert reps.read_text()==expected_fasta,(variant,backend,'roundtrip')
                    rows=list(csv.DictReader(process.stdout.splitlines(),delimiter='\t'))
                    assert [int(r['cluster_representative']) for r in rows]==list(range(len(sequences)))
                else:
                    for reverse in (False,True):
                        process=subprocess.run(command,env=dict(env,CLUSTER_INPUT=str(score_file),CLUSTER_REVERSE=str(int(reverse))),
                                               capture_output=True,text=True,check=True,timeout=60)
                        assert not process.stderr, process.stderr
                        assert list(map(int,process.stdout.split()))==expected_scores[reverse],(variant,backend,reverse)
                emitted.unlink()
                if backend=='c': binary.unlink()
        print(variant, 'word boundaries, RNA/IUPAC roundtrips, and exact alignment scores passed on C and JS',flush=True)
    report.update(roundtrip_records=len(sequences),score_pairs_per_backend_and_strand=len(score_sequences)**2,
                  backends=['c','js'],strands=['plus','both'],status='passed')
    (results/'validation.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__': main()
