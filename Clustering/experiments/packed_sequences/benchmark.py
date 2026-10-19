#!/usr/bin/env python3
"""Sequential native benchmark: paired order, identical input/output, per-run RSS."""
import argparse
import csv
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import random
import statistics
import subprocess
import sys
import tempfile
import threading
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run_once(command, fasta, timeout=120, reverse=False):
    with tempfile.TemporaryDirectory(prefix='packed-measure-') as temporary:
        reps = Path(temporary) / 'representatives.fasta'
        env = dict(os.environ, CLUSTER_INPUT=str(fasta.resolve()), CLUSTER_DNA='1',
                   CLUSTER_IDENTITY='9500', CLUSTER_REVERSE=str(int(reverse)),
                   CLUSTER_RESOLUTION='5000', CLUSTER_SEED='42', CLUSTER_PASSES='100',
                   CLUSTER_REPRESENTATIVES=str(reps), BEND_NO_TELEMETRY='1')
        with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
            started = time.perf_counter()
            process = subprocess.Popen(command, env=env, stdout=stdout, stderr=stderr)
            timer = threading.Timer(timeout, process.kill)
            timer.start()
            try:
                _, status, usage = os.wait4(process.pid, 0)
                elapsed = time.perf_counter() - started
                process.returncode = os.waitstatus_to_exitcode(status)
            finally:
                timer.cancel()
                timer.join()
            stdout.seek(0); table = stdout.read()
            stderr.seek(0); errors = stderr.read()
            if process.returncode != 0 or errors:
                raise RuntimeError((command, process.returncode, errors.decode(errors='replace')))
        representatives = reps.read_bytes()
        rows = list(csv.DictReader(table.decode().splitlines(), delimiter='\t'))
        rss_bytes = usage.ru_maxrss if sys.platform == 'darwin' else usage.ru_maxrss * 1024
        return dict(seconds=elapsed, cpu_seconds=usage.ru_utime + usage.ru_stime,
                    peak_rss_bytes=rss_bytes, records=len(rows),
                    clusters=len({r['cluster_representative'] for r in rows}),
                    table_sha256=digest(table), representatives_sha256=digest(representatives))


def inputs():
    folder = HERE / 'inputs'
    folder.mkdir(exist_ok=True)
    rng = random.Random(20261015)
    ancestors = [''.join(rng.choices('ACGT', k=128)) for _ in range(8)]
    path = folder / 'synthetic64_128.fasta'
    with path.open('w') as file:
        for i in range(64):
            s = list(ancestors[i % 8])
            for _ in range((i // 8) % 4):
                s[rng.randrange(len(s))] = rng.choice('ACGT')
            file.write(f'>synthetic_{i}\n{"".join(s)}\n')
    ready = ROOT / 'datasets/public_viromes/ready'
    storage = folder / 'storage1024_2048.fasta'
    with storage.open('w') as file:
        for i in range(1024):
            file.write(f'>storage_{i}\n' + ancestors[i % 8] * 16 + '\n')
    return {'synthetic64_128': path,
            'vclust_prefix1000': ready / 'vclust_example_prefix1000.fasta',
            'canu_short8': ready / 'canu_viral_short8.fasta',
            'wtdbg2_short8': ready / 'wtdbg2_viral_short8.fasta',
            'storage1024_2048': storage}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repeats', type=int, default=5)
    parser.add_argument('--warmups', type=int, default=1)
    parser.add_argument('--algorithms', nargs='+')
    parser.add_argument('--datasets', nargs='+')
    parser.add_argument('--result', default='benchmark')
    parser.add_argument('--reverse', action='store_true')
    args = parser.parse_args()
    production = module('production_launcher', ROOT / 'run.py')
    compiler = production.default_compiler().resolve()
    launchers = {v: module(v, HERE / v / 'run.py') for v in ('baseline', 'packed')}
    algorithms = args.algorithms or list(production.ALGORITHMS)
    datasets = inputs()
    selected = args.datasets or [name for name in datasets if not name.startswith('storage')]
    out = HERE / 'results'
    out.mkdir(exist_ok=True)
    if 'load-only' in algorithms:
        for launcher in launchers.values():
            launcher.ALGORITHMS['load-only'] = 'roundtrip'
    commands = {(variant, algorithm): launchers[variant].build(algorithm, 'c', compiler)
                for algorithm in algorithms for variant in launchers}
    report = dict(compiler_revision=subprocess.check_output(['git','-C',str(compiler),'rev-parse','HEAD'],text=True).strip(),
                  platform=platform.platform(), machine=platform.machine(),
                  clang=subprocess.check_output(['clang','--version'],text=True).splitlines()[0],
                  bun=subprocess.check_output(['bun','--version'],text=True).strip(),
                  source_hashes=json.loads((HERE/'source_hashes.json').read_text()),
                  experimental_hashes={p.name:digest(p.read_bytes()) for p in (HERE/'packed/lib/packing.bend',HERE/'packed/lib/alignment.bend')},
                  warmups=args.warmups, repeats=args.repeats,
                  identity=0.95, reverse=args.reverse, seed=42, threads=1,
                  measurement='Native child wall time and per-child peak RSS; includes FASTA parsing, packing, clustering, TSV and representative output; excludes compilation and Python launcher.',
                  datasets={name:dict(path=str(datasets[name].relative_to(ROOT)),sha256=digest(datasets[name].read_bytes())) for name in selected},
                  runs=[], summary=[])
    rng = random.Random(20261015)
    for name in selected:
        for algorithm in algorithms:
            reference = None
            measured = {v: [] for v in launchers}
            for repeat in range(-args.warmups, args.repeats):
                order = list(launchers); rng.shuffle(order)
                for variant in order:
                    sample = run_once(commands[variant,algorithm], datasets[name], reverse=args.reverse)
                    signature = (sample['table_sha256'], sample['representatives_sha256'])
                    if reference is None: reference = signature
                    assert signature == reference, (name, algorithm, variant, 'OUTPUT MISMATCH')
                    if repeat >= 0:
                        report['runs'].append(dict(dataset=name,algorithm=algorithm,variant=variant,repeat=repeat,**sample))
                        measured[variant].append(sample)
            row = dict(dataset=name, algorithm=algorithm, clusters=measured['baseline'][0]['clusters'])
            for variant,samples in measured.items():
                row[variant+'_seconds'] = statistics.median(s['seconds'] for s in samples)
                row[variant+'_rss_mib'] = statistics.median(s['peak_rss_bytes'] for s in samples)/(1024*1024)
                row[variant+'_min_seconds'] = min(s['seconds'] for s in samples)
                row[variant+'_max_seconds'] = max(s['seconds'] for s in samples)
            row['speedup'] = row['baseline_seconds']/row['packed_seconds']
            report['summary'].append(row)
            (out/(args.result+'.json')).write_text(json.dumps(report,indent=2)+'\n')
            with (out/(args.result+'.csv')).open('w') as file:
                writer=csv.DictWriter(file,fieldnames=row)
                writer.writeheader();writer.writerows(report['summary'])
            print(f'{name:20} {algorithm:17} baseline={row["baseline_seconds"]:.4f}s packed={row["packed_seconds"]:.4f}s speedup={row["speedup"]:.3f} RSS={row["baseline_rss_mib"]:.1f}/{row["packed_rss_mib"]:.1f} MiB',flush=True)


if __name__ == '__main__':
    main()
