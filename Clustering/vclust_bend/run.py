#!/usr/bin/env python3
"""Build and run the three native Bend stages, with cgroup memory limits."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import json
import fcntl

ROOT = Path(__file__).resolve().parent
CAP = ROOT / 'tools/capped.sh'

def compiler(explicit=None):
    value = explicit or os.environ.get('BEND_REPO') or os.environ.get('BEND')
    if value:
        path = Path(value).expanduser()
    else:
        found = shutil.which('bend')
        if not found:
            raise RuntimeError('Set BEND_REPO to the Bend source checkout, or put bend on PATH.')
        path = Path(found)
    if path.is_dir():
        entry = path/'bend2/main.ts'
        if not entry.is_file(): raise RuntimeError(f'No compiler entry: {entry}')
        bun = shutil.which('bun')
        if bun:
            cmd = [bun, str(entry)]
        elif (path/'.bend/bin/bend').is_file():
            # Official standalone executable also contains Bun.
            cmd = [str(path/'.bend/bin/bend'), str(entry)]
        else:
            raise RuntimeError('Bun is needed to run this compiler checkout.')
        files = sorted((path/'bend2').rglob('*.ts')) + sorted((path/'bend2').rglob('*.bend'))
    else:
        resolved = shutil.which(str(path)) or str(path)
        path = Path(resolved)
        if not path.is_file(): raise RuntimeError(f'Compiler does not exist: {path}')
        cmd, files = [str(path)], [path]
    digest = hashlib.sha256()
    for f in files:
        digest.update(str(f).encode()); digest.update(f.read_bytes())
    return cmd, digest.hexdigest()

def capped(cmd, memory, **kwargs):
    env = dict(os.environ, BEND_NO_TELEMETRY='1', BUN_BE_BUN='1', CAP=memory)
    return subprocess.run(['sh', str(CAP), *map(str,cmd)], env=env, check=True, **kwargs)

def build(stage, explicit=None):
    command, identity = compiler(explicit)
    digest = hashlib.sha256(identity.encode())
    for f in sorted(ROOT.glob('*.bend')):
        digest.update(f.name.encode()); digest.update(f.read_bytes())
    out = ROOT/'.work/bin'/digest.hexdigest()[:20]/stage
    out.parent.mkdir(parents=True, exist_ok=True)
    with (ROOT/'.work/build.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        if not out.exists():
            with tempfile.TemporaryDirectory(prefix=stage+'-build-',dir=out.parent) as tmp:
                staged=Path(tmp)/stage
                capped([*command, ROOT/f'{stage}.bend', '-o', staged], '8G', cwd=ROOT)
                os.replace(staged,out)
    return out

def main():
    ap = argparse.ArgumentParser(description=__doc__, epilog='Stage flags (-i, -o, --ids, --filter, --algorithm, etc.) are forwarded to Bend.')
    ap.add_argument('stage', choices=['prefilter','align','cluster'])
    ap.add_argument('--compiler')
    ap.add_argument('-t','--threads', type=int, default=1)
    ap.add_argument('--memory', default='3G')
    ap.add_argument('--build-only', action='store_true')
    args, rest = ap.parse_known_args()
    if args.threads < 1 or args.threads > 256: ap.error('threads must be in 1..256')
    if '+RTS' in rest or '-RTS' in rest: ap.error('use --threads instead of raw runtime flags')
    # Prevent accidental truncation of an input through a named output alias.
    paths = {}
    supplied = set()
    aliases = {'--in':'-i','--out':'-o','--out-repr':'-r'}
    for token in rest:
        if token.startswith('-') and not token[1:2].isdigit():
            key = aliases.get(token,token)
            if key in supplied: ap.error(f'duplicate option: {key}')
            supplied.add(key)
    for i,key in enumerate(rest[:-1]):
        if key in ('-i','--in','-o','--out','--ids','--filter'):
            paths[key] = Path(rest[i+1]).resolve()
    out = paths.get('-o',paths.get('--out'))
    if out:
        outputs = [out]
        if args.stage == 'align': outputs.append(out.with_suffix('.ids.tsv'))
        if args.stage == 'cluster': outputs.append(Path(str(out)+'.certificate.json'))
        for key,value in paths.items():
            if key not in ('-o','--out'):
                for target in outputs:
                    same = target == value or (target.exists() and value.exists() and os.path.samefile(target,value))
                    if same: ap.error(f'output would overwrite {key}: {value}')
    try:
        binary = build(args.stage,args.compiler)
        if args.build_only:
            print(binary)
        elif args.stage == 'cluster' and out:
            # Publish the named TSV only after the independent semantic check.
            out.parent.mkdir(parents=True,exist_ok=True)
            with tempfile.TemporaryDirectory(prefix='.vclust-bend-',dir=out.parent) as tmp:
                staged=Path(tmp)/'clusters.tsv'
                forwarded=list(rest)
                key='-o' if '-o' in forwarded else '--out'
                forwarded[forwarded.index(key)+1]=str(staged)
                capped([binary,*forwarded,'+RTS','--threads',args.threads,'-RTS'],args.memory)
                sys.path.insert(0,str(ROOT/'tests'))
                from verify_clusters import verify
                def value(key,default):
                    return rest[rest.index(key)+1] if key in rest else default
                metric=value('--metric','tani')
                thresholds={key:float(value('--'+key,'0')) for key in
                            ('ani','gani','tani','qcov','rcov','len_ratio','num_alns')}
                thresholds={key:v for key,v in thresholds.items() if v>0}
                cert=verify(paths.get('-i',paths.get('--in')),paths['--ids'],staged,
                            value('--algorithm','single'),thresholds,metric)
                certificate=Path(tmp)/'certificate.json'
                certificate.write_text(json.dumps(cert,indent=2)+'\n')
                os.replace(staged,out)
                os.replace(certificate,Path(str(out)+'.certificate.json'))
        else:
            capped([binary,*rest,'+RTS','--threads',args.threads,'-RTS'],args.memory)
    except (RuntimeError,ValueError,KeyError,OSError,subprocess.CalledProcessError) as e:
        print(f'vclust-bend: {e}',file=sys.stderr)
        return 1
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
