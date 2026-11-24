#!/usr/bin/env python3
"""Column-level differential report and timings: Bend `align` vs `vclust align` (Vclust 1.3.1 / LZ-ANI 1.2.3).

For each dataset the official `vclust prefilter` makes the Kmer-db filter,
`vclust align` makes the reference ani.tsv/ani.ids.tsv, and the Bend program
(vclust_bend/align.bend) runs on the same filter. Outputs are compared
byte for byte; on a mismatch the max |difference| per numeric column and the
first differing rows are printed.

    python3 vclust_bend/tests/test_align_report.py              # 4 datasets + option variants
    python3 vclust_bend/tests/test_align_report.py --full       # + full EarlyVir (reference files)
    python3 vclust_bend/tests/test_align_report.py --timing     # + timings (bench lock, threads 1/12)

Every child process is started through `capped` when it is on PATH
(memory cap: $CAP, default 4G). Python stdlib only.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
ROOT = os.path.dirname(PKG)
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location("launcher", os.path.join(PKG, "run.py"))
launcher = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(launcher)


class wrapper:
    """align binary built by run.py; -t N becomes +RTS --threads N -RTS."""

    rts = []

    @staticmethod
    def binary():
        return str(launcher.build("align"))

    @staticmethod
    def command(args, exe):
        rest, threads, i = [], None, 0
        while i < len(args):
            if args[i] in ("-t", "--threads"):
                threads, i = args[i + 1], i + 2
                continue
            rest.append(args[i])
            i += 1
        rts = (["--threads", threads] if threads else []) + wrapper.rts
        return [exe] + rest + (["+RTS"] + rts + ["-RTS"] if rts else [])

VCLUST = os.path.join(ROOT, ".tools", "vclust-1.3.1", "bin", "vclust")
DATA = os.path.join(ROOT, "datasets")
DATASETS = {
    "vclust_example": "public_viromes/original/vclust_example.fasta",
    "prefix1000": "public_viromes/ready/vclust_example_prefix1000.fasta",
    "shortest1000": "infant_gut_virome/ready/earlyvir_shortest1000.fasta",
    "stratified1000": "infant_gut_virome/ready/earlyvir_stratified1000.fasta",
}
FULL_FASTA = "infant_gut_virome/raw/all.curated.vOTUs.EarlyVir.fna"
VARIANTS = [
    ("lite", ["--outfmt", "lite"]),
    ("complete", ["--outfmt", "complete"]),
    ("out-thresholds", ["--out-ani", "0.95", "--out-qcov", "0.5", "--out-tani", "0.3"]),
    ("out-gani-rcov", ["--out-gani", "0.4", "--out-rcov", "0.25"]),
    ("filter-threshold", ["--filter-threshold", "0.95"]),
    ("lz-params", ["--mal", "13", "--msl", "8", "--mrd", "30", "--mqd", "30",
                   "--reg", "50", "--aw", "20", "--am", "9", "--ar", "4"]),
    ("lz-params2", ["--mal", "9", "--msl", "6", "--reg", "20", "--aw", "10", "--am", "3", "--ar", "2",
                    "--outfmt", "complete"]),
]
NUMERIC = {"tani", "gani", "ani", "qcov", "rcov", "len_ratio", "num_alns", "qlen", "rlen",
           "nt_match", "nt_mismatch"}


def capped(cmd, cap=None):
    if shutil.which("capped"):
        env = dict(os.environ, CAP=cap or os.environ.get("CAP", "4G"))
        return ["capped"] + cmd, env
    return cmd, dict(os.environ)


LOCK_RUNS = []  # ["flock", lock] when --lock-runs: Bend runs take the bench lock


def run(cmd, cap=None, timed=False, locked=False):
    cmd, env = capped(cmd, cap)
    if locked:
        cmd = LOCK_RUNS + cmd
    if timed:
        cmd = ["/usr/bin/time", "-f", "%e %M"] + cmd
    p = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError("command failed (%d): %s\n%s" % (p.returncode, " ".join(cmd), p.stderr))
    if timed:
        wall, rss = p.stderr.strip().splitlines()[-1].split()
        return float(wall), int(rss)
    return None


def ids_name(out):
    d = out.rfind(".")
    return out + ".ids" if d < 0 else out[:d] + ".ids" + out[d:]


def compare(ref, got):
    """(identical, report) for two ani.tsv files."""
    with open(ref) as f:
        a = f.read().splitlines()
    with open(got) as f:
        b = f.read().splitlines()
    if a == b:
        return True, "identical, %d rows" % (len(a) - 1)
    lines = ["DIFFERENT: %d vs %d rows" % (len(a) - 1, len(b) - 1)]
    head = a[0].split("\t") if a else []
    if not b or b[0] != a[0]:
        lines.append("header differs: %r vs %r" % (a[:1], b[:1]))
        return False, "\n".join(lines)
    ka = {tuple(r.split("\t")[:2]): r.split("\t") for r in a[1:]}
    kb = {tuple(r.split("\t")[:2]): r.split("\t") for r in b[1:]}
    lines.append("rows only in vclust: %d, only in bend: %d" % (len(ka.keys() - kb.keys()),
                                                              len(kb.keys() - ka.keys())))
    for j, col in enumerate(head):
        if col in NUMERIC:
            mx = 0.0
            for k in ka.keys() & kb.keys():
                mx = max(mx, abs(float(ka[k][j]) - float(kb[k][j])))
            lines.append("  max |diff| %-11s %g" % (col, mx))
    shown = 0
    for x, y in zip(a, b):
        if x != y and shown < 5:
            lines.append("  vclust: " + x + "\n  bend  : " + y)
            shown += 1
    return False, "\n".join(lines)


SKIP_UNTIL = []  # --from-case: cases before this one are skipped


def check(name, fasta, fltr, args, work, exe, ref=None):
    if SKIP_UNTIL:
        if name != SKIP_UNTIL[0]:
            return True
        SKIP_UNTIL.clear()
    out_v = ref or os.path.join(work, name + ".vclust.tsv")
    if ref is None:
        run([VCLUST, "align", "-i", fasta, "-o", out_v, "-t", "4", "-v", "0"]
            + (["--filter", fltr] if fltr else []) + args)
    out_b = os.path.join(work, name + ".bend.tsv")
    run(wrapper.command(["-i", fasta, "-o", out_b] + (["--filter", fltr] if fltr else []) + args, exe),
        cap=os.environ.get("CAP", "6G"), locked=True)
    ok1, rep1 = compare(out_v, out_b)
    ok2, rep2 = compare(ids_name(out_v), ids_name(out_b))
    print("%-34s ani.tsv: %s | ids: %s" % (name, rep1, rep2), flush=True)
    return ok1 and ok2


def timing(name, fasta, fltr, work, exe, lock, full_ref=None):
    rows = []
    for t in (1, 12):
        up = open("/proc/loadavg").read().split()[0]
        out_b = os.path.join(work, "%s.t%d.bend.tsv" % (name, t))
        cmd, env = capped(wrapper.command(["-i", fasta, "-o", out_b, "--filter", fltr, "-t", str(t)], exe),
                          os.environ.get("CAP", "6G"))
        p = subprocess.run(["flock", lock, "/usr/bin/time", "-f", "%e %M"] + cmd, env=env,
                           capture_output=True, text=True)
        wall, rss = p.stderr.strip().splitlines()[-1].split()
        rows.append(("bend", t, float(wall), int(rss), up))
        if full_ref is None:
            out_v = os.path.join(work, "%s.t%d.vclust.tsv" % (name, t))
            cmd, env = capped([VCLUST, "align", "-i", fasta, "-o", out_v, "--filter", fltr,
                               "-t", str(t), "-v", "0"], "4G")
            up = open("/proc/loadavg").read().split()[0]
            p = subprocess.run(["flock", lock, "/usr/bin/time", "-f", "%e %M"] + cmd, env=env,
                               capture_output=True, text=True)
            wall, rss = p.stderr.strip().splitlines()[-1].split()
            rows.append(("vclust", t, float(wall), int(rss), up))
    for who, t, wall, rss, up in rows:
        print("  timing %-15s %-6s t=%-2d %8.2f s %8.1f MB  (load %s)" % (name, who, t, wall, rss / 1024, up),
              flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=os.path.join(PKG, ".work", "align-report"))
    ap.add_argument("--full", action="store_true", help="also full EarlyVir (reference files)")
    ap.add_argument("--full-dir", default=os.environ.get(
        "VCLUST_FULL_DIR", "/tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad/vc/full"))
    ap.add_argument("--timing", action="store_true")
    ap.add_argument("--lock", default=os.environ.get(
        "BENCH_LOCK", "/tmp/claude-1000/-home-veritas/5691d3ef-5733-4e4a-b581-7568273d0c95/scratchpad/bench.lock"))
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--no-variants", action="store_true")
    ap.add_argument("--exe", help="test this align binary (e.g. the GPU build of align_gpu.bend)")
    ap.add_argument("--lock-runs", action="store_true",
                    help="run every Bend binary under flock on the bench lock (required for GPU runs)")
    ap.add_argument("--from-case", help="skip cases before this name (resume)")
    ap.add_argument("--rts", default="", help="extra runtime options, e.g. '--gpu 4GB' or '--gpu off'")
    a = ap.parse_args()
    os.makedirs(a.work, exist_ok=True)
    if a.from_case:
        SKIP_UNTIL[:] = [a.from_case]
    if a.lock_runs:
        LOCK_RUNS[:] = ["flock", a.lock]
    exe = a.exe or wrapper.binary()
    wrapper.rts = a.rts.split()
    ok = True
    for name, rel in DATASETS.items():
        if a.only and name not in a.only:
            continue
        fasta = os.path.join(DATA, rel)
        fltr = os.path.join(a.work, name + ".fltr.txt")
        if not os.path.exists(fltr):
            run([VCLUST, "prefilter", "-i", fasta, "-o", fltr, "-t", "4", "-v", "0"])
        ok &= check(name, fasta, fltr, [], a.work, exe)
        if not a.no_variants and name in ("vclust_example", "prefix1000", "shortest1000"):
            for vname, args in VARIANTS:
                ok &= check(name + "." + vname, fasta, fltr, args, a.work, exe)
            if name != "shortest1000":
                ok &= check(name + ".no-filter", fasta, None, [], a.work, exe)
        if a.timing:
            timing(name, fasta, fltr, a.work, exe, a.lock)
    if a.full:
        fasta = os.path.join(DATA, FULL_FASTA)
        fltr = os.path.join(a.full_dir, "fltr12.txt")
        ref = os.path.join(a.full_dir, "ani12.tsv")
        t0 = time.time()
        ok &= check("full_earlyvir", fasta, fltr, [], a.work, exe, ref=ref)
        print("  (full run %.1f s)" % (time.time() - t0))
        if a.timing:
            timing("full_earlyvir", fasta, fltr, a.work, exe, a.lock, full_ref=ref)
    print("ALL IDENTICAL" if ok else "SOME OUTPUTS DIFFER")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
