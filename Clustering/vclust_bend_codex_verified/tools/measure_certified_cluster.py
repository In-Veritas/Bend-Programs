#!/usr/bin/env python3
"""Measure the actual certified launcher separately from native stage timings."""
from pathlib import Path
import json
import sys
import hashlib

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from benchmark import measured

def main():
    source=ROOT/'evidence/benchmark-stratified1000-full-t12.json'
    report=json.loads(source.read_text());base=Path(report['work_directory'])
    if not report.get('performance_comparison_complete',False):
        raise SystemExit('Run a complete, uncontended benchmark --full --threads 12 before measuring the certified launcher.')
    rows=[]
    for dataset in ('stratified1000','full'):
        folder=base/f'{dataset}-t12-bend';out=folder/'certified-clusters.tsv'
        cmd=[sys.executable,ROOT/'run.py','cluster','-i',folder/'ani.tsv','--ids',folder/'ani.ids.tsv',
             '-o',out,'--algorithm','leiden','--metric','ani','--ani','0.95','-t','1']
        row={'dataset':dataset,**measured(cmd,folder/'certified-cluster.log',300)}
        row['identical_to_native']=out.read_bytes()==(folder/'clusters.tsv').read_bytes()
        cert=json.loads(Path(str(out)+'.certificate.json').read_text())
        row['certificate_hash_matches']=cert['output_sha256']==hashlib.sha256(out.read_bytes()).hexdigest()
        if not row['identical_to_native'] or not row['certificate_hash_matches']: raise RuntimeError(row)
        rows.append(row);print(dataset,row['wall_seconds'],row['max_rss_kib'],'certified launcher PASS',flush=True)
    (ROOT/'evidence/certified-launcher-timings.json').write_text(json.dumps({'note':'Single samples including cached launcher build lookup, systemd scope, native clustering, Python semantic verification and certificate publication. Compare with native stage timings only with this boundary in mind.','runs':rows},indent=2)+'\n')

if __name__=='__main__': main()
