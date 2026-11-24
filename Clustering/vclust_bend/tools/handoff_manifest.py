#!/usr/bin/env python3
"""Record every package source change relative to the preserved Claude files."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import tarfile

ROOT=Path(__file__).resolve().parents[1]
def main():
    old={}
    with tarfile.open(ROOT.parent/'handoff/claude-inherited-vclust_bend.tar.gz') as archive:
        for member in archive.getmembers():
            if member.isfile(): old[member.name.removeprefix('vclust_bend/')]=archive.extractfile(member).read()
    current={str(p.relative_to(ROOT)):p.read_bytes() for p in ROOT.rglob('*')
             if p.is_file() and not set(p.relative_to(ROOT).parts)&{'.work','__pycache__','evidence'}}
    rows=[];diff=[]
    for name in sorted(old.keys()|current.keys()):
        before,after=old.get(name),current.get(name)
        status='unchanged' if before==after else 'new' if before is None else 'removed' if after is None else 'modified'
        rows.append({'file':name,'status':status,'before_sha256':hashlib.sha256(before).hexdigest() if before is not None else None,
                     'after_sha256':hashlib.sha256(after).hexdigest() if after is not None else None})
        if status!='unchanged':
            diff.extend(difflib.unified_diff((before or b'').decode().splitlines(True),(after or b'').decode().splitlines(True),
                        fromfile='claude/'+name if before is not None else '/dev/null',
                        tofile='codex/'+name if after is not None else '/dev/null'))
    (ROOT/'evidence/codex-source-manifest.json').write_text(json.dumps({'updated_at':datetime.datetime.now().astimezone().isoformat(),'files':rows},indent=2)+'\n')
    (ROOT/'evidence/codex-source-changes.patch').write_text(''.join(diff))
    inventory={}
    for path in sorted(ROOT.rglob('*')):
        relative=path.relative_to(ROOT)
        if not path.is_file() or set(relative.parts)&{'.work','__pycache__'} or relative.as_posix()=='evidence/delivered-sha256.json': continue
        inventory[str(relative)]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size}
    (ROOT/'evidence/delivered-sha256.json').write_text(json.dumps(inventory,indent=2)+'\n')
    print({s:sum(r['status']==s for r in rows) for s in ('new','modified','removed','unchanged')})

if __name__=='__main__': main()
