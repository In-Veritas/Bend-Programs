#!/usr/bin/env python3
"""Differential test: Bend `prefilter` vs `vclust prefilter` (Kmer-db 2.3.1).

Builds vclust_bend/prefilter.bend, runs it and Vclust 1.3.1 on several
datasets and option sets, and compares the filter files byte for byte. On a
mismatch it reports missing/extra pairs and the max abs difference of the
shared values. Vclust outputs are cached (REF_DIR) so reruns are cheap; the
full-EarlyVir default reference reuses the lead's `vc/full/fltr12.txt`.

  python3 tests/test_prefilter.py [--quick] [--full] [--time]

  --quick  small datasets only (vclust_example, prefix1000, shortest1000)
  --full   also full EarlyVir (default options, --max-seqs 50,
           --kmers-fraction 0.2); heavy: ~1 GB for Bend, ~2.5 GB for Vclust
  PF_GPU=1 runs the Bend binary with --gpu (Bend `!` calls), under the bench lock.
  --time   time both tools at threads 1 and 12 (under the bench lock) and
           print wall time / max RSS

Run under the memory cap: `CAP=8G capped python3 tests/test_prefilter.py`.
Stdlib only.
"""
import os
import json
import signal
import importlib.util
from pathlib import Path
import subprocess
import sys
import time
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
CLU = os.path.dirname(PKG)
SCRATCH = os.environ.get(
    "PF_SCRATCH",
    "/tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad")
WORK = os.path.join(PKG, ".work", "prefilter-tests")
REF_DIR = os.path.join(PKG, '.work', 'references', 'prefilter-options')
LOCK = os.environ.get('PF_LOCK', os.path.join(SCRATCH, 'bench.lock'))  # the shared bench lock
VCLUST = os.path.join(CLU, ".tools", "vclust-1.3.1", "bin", "vclust")
BIN = os.path.join(WORK, "prefilter")
DS = os.path.join(CLU, "datasets")

DATASETS = {
    "vclust_example": os.path.join(DS, "public_viromes/original/vclust_example.fasta"),
    "prefix1000": os.path.join(DS, "public_viromes/ready/vclust_example_prefix1000.fasta"),
    "shortest1000": os.path.join(DS, "infant_gut_virome/ready/earlyvir_shortest1000.fasta"),
    "stratified1000": os.path.join(DS, "infant_gut_virome/ready/earlyvir_stratified1000.fasta"),
    "full": os.path.join(DS, "infant_gut_virome/raw/all.curated.vOTUs.EarlyVir.fna"),
}

BASIC = [
    [],
    ["--max-seqs", "50"],
    ["--kmers-fraction", "0.2"],
]
EXTRA = [
    ["--max-seqs", "1"],
    ["--batch-size", "300"],
    ["--batch-size", "300", "--max-seqs", "5"],
    ["-k", "15", "--kmers-fraction", "0.5"],
    ["-k", "16"],
    ["-k", "19", "--kmers-fraction", "0.3", "--min-kmers", "3"],
    # Kmer-db 2.3.1 stalls on the bundled example at k=30; see handoff.
    # Opt in with --include-slow-reference to retry it with a timeout.
    ["--min-kmers", "1", "--min-ident", "0"],
    ["--min-ident", "0.95", "--max-seqs", "3"],
]


def run(cmd, **kw):
    timeout = kw.pop('timeout', 180)
    with subprocess.Popen(cmd, start_new_session=True, **kw) as child:
        try:
            code = child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
            raise
        if code:
            raise subprocess.CalledProcessError(code, cmd)


def build():
    global BIN
    os.makedirs(WORK, exist_ok=True)
    spec = importlib.util.spec_from_file_location('launcher', os.path.join(PKG, 'run.py'))
    launcher = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(launcher)
    BIN = str(launcher.build('prefilter'))


def tag(opts):
    return "default" if not opts else "_".join(o.lstrip("-") for o in opts)


def reference(name, opts):
    os.makedirs(REF_DIR, exist_ok=True)
    path = os.path.join(REF_DIR, f"{name}.{tag(opts)}.txt")
    old = os.path.join(SCRATCH, 'pf', 'refs', os.path.basename(path))
    if not os.path.exists(path) and os.path.isfile(old): shutil.copy2(old,path)
    if name == "full" and not opts:
        lead = os.path.join(SCRATCH, "vc", "full", "fltr12.txt")
        if os.path.exists(lead):
            if not os.path.exists(path): shutil.copy2(lead,path)
            return path
    if not os.path.exists(path):
        run([VCLUST, "prefilter", "-i", DATASETS[name], "-o", path + ".partial", "-t", "12", "-v", "0"] + opts,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        os.replace(path + ".partial", path)
    return path


GPU = os.environ.get("PF_GPU") == "1"   # PF_GPU=1: run the `--gpu` (Bend `!`) build path


def bend_cmd(inp, out, opts, threads=12, lock=True):
    cmd = [BIN, "-i", inp, "-o", out] + opts + (["--gpu"] if GPU else []) + ["+RTS", "--threads", str(threads), "-RTS"]
    # every GPU execution runs under the bench lock (board-wide energy measurements)
    return (["flock", LOCK] if GPU and lock else []) + cmd


def parse(path):
    rows = {}
    with open(path) as fh:
        header = fh.readline()
        for i, line in enumerate(fh):
            parts = line.rstrip("\n").split(",")
            for e in parts[1:]:
                if e:
                    j, v = e.split(":")
                    rows[(i, int(j))] = float(v)
    return header, rows


def compare(ref, out):
    with open(ref, "rb") as a, open(out, "rb") as b:
        if a.read() == b.read():
            return True, "identical"
    h1, r1 = parse(ref)
    h2, r2 = parse(out)
    miss = set(r1) - set(r2)
    extra = set(r2) - set(r1)
    diff = max((abs(r1[k] - r2[k]) for k in set(r1) & set(r2)), default=0.0)
    return False, (f"header {'same' if h1 == h2 else 'DIFF'}, {len(r1)} vs {len(r2)} entries, "
                   f"missing {len(miss)}, extra {len(extra)}, max |diff| {diff:.6f}")


def timed(cmd):
    os.makedirs(os.path.dirname(LOCK),exist_ok=True)
    t = time.time()
    r = subprocess.run(["flock", LOCK, "/usr/bin/time", "-f", "%e %M"] + cmd,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, check=True)
    wall, rss = r.stderr.strip().split("\n")[-1].split()
    return float(wall), int(rss) / 1024.0


def main():
    args = set(sys.argv[1:])
    build()
    names = ["vclust_example", "prefix1000", "shortest1000"]
    if "--quick" not in args:
        names.append("stratified1000")
    cases = [(n, o) for n in names for o in BASIC + (EXTRA if n != "stratified1000" else EXTRA[:3])]
    if "--full" in args:
        cases += [("full", o) for o in BASIC]
    if "--include-slow-reference" in args:
        cases.append(("vclust_example", ["-k", "30", "--min-ident", "0.9"]))
    else:
        print("SKIP reference k=30: Kmer-db 2.3.1 timed out on the example; opt in with --include-slow-reference", flush=True)
    reports = []
    fails = 0
    for name, opts in cases:
        row = {"dataset": name, "options": opts}
        try:
            ref = reference(name, opts)
            out = os.path.join(WORK, f"{name}.{tag(opts)}.bend.txt")
            cmd = bend_cmd(DATASETS[name], out, opts)
            run(cmd, timeout=600 if name == "full" else 180)
            ok, msg = compare(ref, out)
            row.update(command=cmd, reference=ref, output=out)
        except (OSError, subprocess.SubprocessError) as error:
            ok, msg = False, str(error)
        row.update(identical=ok, detail=msg)
        reports.append(row)
        Path(WORK, 'results.json').write_text(json.dumps(reports, indent=2)+'\n')
        fails += not ok
        print(f"{'PASS' if ok else 'FAIL'} {name:15s} {' '.join(opts) or '(defaults)':45s} {msg}", flush=True)
    if "--time" in args:
        print("\ntiming (wall s / max RSS MB), under the bench lock; uptime:",
              subprocess.run(["uptime"], capture_output=True, text=True).stdout.strip())
        tnames = ["stratified1000"] + (["full"] if "--full" in args else [])
        for name in tnames:
            for opts in BASIC:
                for t in (1, 12):
                    out = os.path.join(WORK, "timing.txt")
                    bw, bm = timed(bend_cmd(DATASETS[name], out, opts, t, lock=False))
                    vw, vm = timed([VCLUST, "prefilter", "-i", DATASETS[name], "-o", out, "-t", str(t), "-v", "0"]
                                   + opts)
                    print(f"{name:15s} {' '.join(opts) or '(defaults)':22s} t={t:2d}  "
                          f"bend {bw:7.2f} s {bm:7.0f} MB   vclust {vw:7.2f} s {vm:7.0f} MB", flush=True)
    print(f"\n{len(cases) - fails}/{len(cases)} identical")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
