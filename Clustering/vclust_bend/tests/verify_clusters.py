#!/usr/bin/env python3
"""Independent semantic checks and a spanning-forest witness for actual TSVs.

This checker does not rerun the clustering algorithms. It checks their output
contracts against the filtered input graph. The general forest implication is
proved separately in proofs/Forest.lean; this Python parser/checker is not itself
a formally verified program and remains an explicit trust boundary.
"""
import argparse
import csv
from collections import defaultdict, deque
import hashlib
import json
from pathlib import Path

def read_graph(ani, ids, thresholds, metric):
    from clusty_model import clusty_strtod
    with Path(ids).open() as f:
        names=[line.rstrip('\n').split('\t')[0] for line in list(f)[1:] if line.strip()]
    if len(set(names)) != len(names): raise ValueError('duplicate identifiers cannot certify an unambiguous TSV mapping')
    graph=[set() for _ in names]
    with Path(ani).open() as f:
        for row in csv.DictReader(f,delimiter='\t'):
            accepted=all(clusty_strtod(row[k]) >= v for k,v in thresholds.items() if k!='num_alns')
            if thresholds.get('num_alns',0)>0:
                accepted &= clusty_strtod(row['num_alns']) <= thresholds['num_alns']
            if not accepted: continue
            a,b=int(row['qidx']),int(row['ridx'])
            if not (0<=a<len(names) and 0<=b<len(names)): raise ValueError('input edge index outside ids')
            if a!=b: graph[a].add(b);graph[b].add(a)
    return names,graph

def verify(ani,ids,output,algorithm,thresholds,metric='ani'):
    if algorithm not in ('single','complete','uclust','cd-hit','set-cover','leiden'):
        raise ValueError(f'unknown algorithm contract: {algorithm}')
    names,graph=read_graph(ani,ids,thresholds,metric)
    lookup={v:i for i,v in enumerate(names)};groups=defaultdict(list); seen=set()
    with Path(output).open() as f:
        for row in csv.DictReader(f,delimiter='\t'):
            name=row['object']
            if name not in lookup: raise ValueError(f'unknown output object: {name}')
            if name in seen: raise ValueError(f'duplicate output object: {name}')
            seen.add(name);groups[row['cluster']].append(lookup[name])
    if seen != set(names): raise ValueError('missing output objects')
    root=[-1]*len(names);parent=[-1]*len(names);rank=[-1]*len(names)
    stars={}
    for label,members in groups.items():
        allowed=set(members);r=members[0];q=deque([r]);parent[r]=r;rank[r]=0
        while q:
            v=q.popleft();root[v]=r
            for u in sorted(graph[v] & allowed):
                if parent[u]<0: parent[u]=v;rank[u]=rank[v]+1;q.append(u)
        if any(root[v]!=r for v in members): raise ValueError(f'disconnected cluster: {label}')
        if algorithm=='complete':
            for v in members:
                if allowed-{v}-graph[v]: raise ValueError(f'non-clique complete cluster: {label}')
        if algorithm in ('uclust','cd-hit','set-cover'):
            seeds=[v for v in members if not (allowed-{v}-graph[v])]
            if not seeds: raise ValueError(f'no adjacent seed for cluster: {label}')
            stars[label]=min(seeds)
    # Check the witness independently of the BFS that constructed it.
    for v in range(len(names)):
        p=parent[v]
        if p==v:
            if root[v]!=v or rank[v]!=0: raise ValueError('invalid forest root')
        elif not (p in graph[v] and root[p]==root[v] and 0<=rank[p]<rank[v]):
            raise ValueError('invalid forest step')
    if algorithm=='single':
        if any(root[v]!=root[u] for v,ns in enumerate(graph) for u in ns):
            raise ValueError('single linkage split an accepted connected component')
    return {'algorithm':algorithm,'objects':len(names),'clusters':len(groups),
            'metric':metric,'thresholds':thresholds,
            'edges':sum(map(len,graph))//2,'partition':True,'connected':True,
            'clique':algorithm=='complete','edge_closed':algorithm=='single',
            'star_seeds':stars,'root':root,'parent':parent,'rank':rank,
            'input_sha256':hashlib.sha256(Path(ani).read_bytes()).hexdigest(),
            'ids_sha256':hashlib.sha256(Path(ids).read_bytes()).hexdigest(),
            'output_sha256':hashlib.sha256(Path(output).read_bytes()).hexdigest(),
            'trust_boundary':'Python I/O and finite certificate checks; Forest.lean proves the abstract implication.'}

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('-i','--input',required=True);ap.add_argument('--ids',required=True)
    ap.add_argument('--clusters',required=True);ap.add_argument('--algorithm',required=True)
    ap.add_argument('--metric',default='ani');ap.add_argument('--threshold',type=float,default=.95)
    ap.add_argument('--certificate',type=Path)
    a=ap.parse_args();result=verify(a.input,a.ids,a.clusters,a.algorithm,{a.metric:a.threshold},a.metric)
    if a.certificate: a.certificate.write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS {result["objects"]} objects; {result["clusters"]} clusters; partition and {a.algorithm} contract')

if __name__=='__main__': main()
