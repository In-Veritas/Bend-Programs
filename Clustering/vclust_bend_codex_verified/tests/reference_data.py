"""Durable Vclust fixtures; recover existing references or regenerate them."""
from pathlib import Path
import os
import shutil
import signal
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
CLU=ROOT.parent
VC=CLU/'.tools/vclust-1.3.1/bin/vclust'
SCRATCH=Path(os.environ.get('VCLUST_OLD_SCRATCH','/tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad'))
DATA={
 'example':('public_viromes/original/vclust_example.fasta','vc/fltr.txt','vc/ani.tsv'),
 'prefix1000':('public_viromes/ready/vclust_example_prefix1000.fasta','al/ref/vclust_example_prefix1000.fltr.txt','al/ref/vclust_example_prefix1000.ani.tsv'),
 'shortest1000':('infant_gut_virome/ready/earlyvir_shortest1000.fasta','al/ref/earlyvir_shortest1000.fltr.txt','al/ref/earlyvir_shortest1000.ani.tsv'),
 'stratified1000':('infant_gut_virome/ready/earlyvir_stratified1000.fasta','vc/s1000/fltr12.txt','vc/s1000/ani12.tsv'),
 'full':('infant_gut_virome/raw/all.curated.vOTUs.EarlyVir.fna','vc/full/fltr12.txt','vc/full/ani12.tsv')}

def run(cmd):
    with subprocess.Popen(list(map(str,cmd)),start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE) as p:
        try: _,err=p.communicate(timeout=600)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid,signal.SIGKILL);p.wait();raise
        if p.returncode: raise RuntimeError(err.decode(errors='replace'))

def load(name):
    fasta,old_filter,old_ani=DATA[name]
    folder=ROOT/'.work/references'/name;folder.mkdir(parents=True,exist_ok=True)
    fa=CLU/'datasets'/fasta;flt=folder/'fltr.txt';ani=folder/'ani.tsv';ids=folder/'ani.ids.tsv'
    for old,new in [(SCRATCH/old_filter,flt),(SCRATCH/old_ani,ani),((SCRATCH/old_ani).with_suffix('.ids.tsv'),ids)]:
        if not new.exists() and old.is_file(): shutil.copy2(old,new)
    with tempfile.TemporaryDirectory(prefix='reference-',dir=folder) as tmp:
        staging=Path(tmp)
        if not flt.exists():
            target=staging/'fltr.txt'
            run([VC,'prefilter','-i',fa,'-o',target,'-t','1','-v','0']);os.replace(target,flt)
        if not ani.exists() or not ids.exists():
            target=staging/'ani.tsv'
            run([VC,'align','-i',fa,'--filter',flt,'-o',target,'-t','1','-v','0'])
            os.replace(target,ani);os.replace(target.with_suffix('.ids.tsv'),ids)
    return fa,flt,ani,ids
