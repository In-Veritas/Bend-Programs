#!/usr/bin/env python3
"""Differential fuzzer: Bend prefilter / cluster vs Vclust 1.3.1, byte for byte.

  CAP=6G capped python3 tests/fuzz_vclust.py [--seeds N] [--stage prefilter|cluster|all]

prefilter (+ align): random multi-FASTAs made of mutated copies of a few ancestors
(near-identical and duplicate genomes, shared repeats, short contigs, N runs,
lowercase, IUPAC symbols, CRLF line ends), run with several option sets
(defaults, --max-seqs, --kmers-fraction, -k 15/19, --min-kmers 1
--min-ident 0, --batch-size), so row blocks, pair codes, hash-table growth
and ties are exercised.

cluster: random distance tables in vclust align's format, large enough
(several MiB) that rows straddle the 512 KiB chunk boundaries of the parallel
parser, with ties, duplicate rows, self pairs, rows rejected by filters, some
'\\r\\n' line ends, ids absent from the table; every algorithm, two thresholds.

Stdlib only. Exit status 1 on any mismatch (the inputs are kept).
"""
import os
import random
import subprocess
import sys
import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
VCLUST = os.path.join(os.path.dirname(PKG), ".tools", "vclust-1.3.1", "bin", "vclust")
WORK = os.path.join(PKG, ".work", "fuzz")


def build(stage):
    spec = importlib.util.spec_from_file_location("launcher", os.path.join(PKG, "run.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return str(m.build(stage))


def mutate(rng, s, rate):
    out = []
    for c in s:
        r = rng.random()
        if r < rate:
            out.append(rng.choice("ACGT"))
        elif r < rate * 1.3:
            continue
        elif r < rate * 1.6:
            out.append(c + rng.choice("ACGT"))
        else:
            out.append(c)
    return "".join(out)


def random_fasta(rng, path, big=False):
    anc = ["".join(rng.choice("ACGT") for _ in range(rng.randint(300, 6000))) for _ in range(rng.randint(2, 8))]
    repeat = "".join(rng.choice("ACGT") for _ in range(rng.randint(30, 200)))
    recs = []
    n = rng.randint(900, 1600) if big else rng.randint(5, 220)
    for i in range(n):
        a = rng.choice(anc)
        kind = rng.random()
        if kind < 0.15 and recs:
            s = rng.choice(recs)[1]  # exact duplicate
        elif kind < 0.25:
            s = a[: rng.randint(10, 60)]  # short contig, maybe < k
        else:
            st = rng.randint(0, len(a) // 2)
            s = mutate(rng, a[st: st + rng.randint(200, len(a))], rng.choice([0.0, 0.002, 0.01, 0.05, 0.2]))
            if rng.random() < 0.3:
                p = rng.randint(0, len(s))
                s = s[:p] + repeat * rng.randint(1, 4) + s[p:]
            if rng.random() < 0.2:
                p = rng.randint(0, len(s))
                s = s[:p] + "N" * rng.randint(1, 40) + s[p:]
            if rng.random() < 0.1:
                s = s.lower()
            if rng.random() < 0.05:
                s = s.replace("A", "R", 3)
        recs.append((f"seq{i}_{rng.randint(0, 9999)} desc", s))
    nl = "\r\n" if rng.random() < 0.2 else "\n"
    with open(path, "w", newline="") as fh:
        for name, s in recs:
            fh.write(">" + name + nl)
            w = rng.choice([60, 80, 1000])
            for j in range(0, len(s), w):
                fh.write(s[j:j + w] + nl)


PF_OPTS = [[], ["--max-seqs", "3"], ["--kmers-fraction", "0.3"], ["-k", "15"], ["-k", "19", "--min-kmers", "2"],
           ["--min-kmers", "1", "--min-ident", "0"], ["--min-kmers", "1", "--min-ident", "0", "--max-seqs", "2"],
           ["--batch-size", "7"], ["--batch-size", "7", "--max-seqs", "2"]]


def fuzz_prefilter(rng, seed, binp, bina=None):
    fa = os.path.join(WORK, f"pf{seed}.fasta")
    big = seed % 3 == 2  # > 1 MiB: rows/records straddle the parallel readers' chunks
    random_fasta(rng, fa, big)
    bad = 0
    if bina:
        ref = fa + ".fltr"
        subprocess.run([VCLUST, "prefilter", "-i", fa, "-o", ref, "-t", "4", "-v", "0", "--min-ident", "0.3",
                        "--min-kmers", "2"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for fmt in ("lite", "complete"):
            subprocess.run([VCLUST, "align", "-i", fa, "-o", fa + ".ani.ref.tsv", "--filter", ref, "-t", "4", "-v", "0",
                            "--outfmt", fmt, "--out-ani", "0.5"],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run([bina, "-i", fa, "-o", fa + ".ani.bend.tsv", "--filter", ref, "--outfmt", fmt, "--out-ani", "0.5",
                            "+RTS", "--threads", "12", "--gpu", "off", "-RTS"],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for sfx in (".tsv", ".ids.tsv"):
                if open(fa + ".ani.ref" + sfx, "rb").read() != open(fa + ".ani.bend" + sfx, "rb").read():
                    print(f"DIFF align seed {seed} {fmt} {sfx} ({fa})", flush=True)
                    bad += 1
    for opts in PF_OPTS:
        ref, out = fa + ".ref", fa + ".bend"
        subprocess.run([VCLUST, "prefilter", "-i", fa, "-o", ref, "-t", "4", "-v", "0"] + opts, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run([binp, "-i", fa, "-o", out] + opts + ["+RTS", "--threads", "12", "--gpu", "off", "-RTS"],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        same = open(ref, "rb").read() == open(out, "rb").read()
        if not same:
            print(f"DIFF prefilter seed {seed} {' '.join(opts)}  ({fa})", flush=True)
            bad += 1
    if not bad:
        os.remove(fa)
    return bad


def fmt(x):
    return f"{x:.6g}" if x != 1 else "1"


def random_table(rng, base):
    n = rng.randint(50, 3000)
    ids = [f"g{i}_{rng.randint(0, 99999)}" for i in range(n)]
    with open(base + ".ids.tsv", "w") as fh:
        fh.write("id\tseq_len\tno_parts\n")
        for i, s in enumerate(ids):
            fh.write(f"{s}\t{10000 - i}\t1\n")
    rows = rng.randint(20000, 60000)
    crlf = rng.random() < 0.3
    vals = [0.95, 0.7, 0.951234, 0.949999, 1.0, 0.5, 0.99]
    with open(base + ".tsv", "w", newline="") as fh:
        fh.write("qidx\tridx\tquery\treference\ttani\tgani\tani\tqcov\trcov\tnum_alns\tlen_ratio\n")
        for _ in range(rows):
            q = rng.randrange(n)
            r = q if rng.random() < 0.01 else rng.randrange(n)
            def v():
                return rng.choice(vals) if rng.random() < 0.3 else rng.random()
            line = (f"{q}\t{r}\t{ids[q]}\t{ids[r]}\t{fmt(v())}\t{fmt(v())}\t{fmt(v())}\t{fmt(v())}\t{fmt(v())}"
                    f"\t{rng.randint(1, 30)}\t{fmt(rng.random())}")
            fh.write(line + ("\r\n" if crlf and rng.random() < 0.5 else "\n"))


CL = [(a, t) for a in ["single", "complete", "uclust", "cd-hit", "set-cover", "leiden"] for t in ["0.95", "0.7"]]


def fuzz_cluster(rng, seed, binc):
    base = os.path.join(WORK, f"cl{seed}")
    random_table(rng, base)
    bad = 0
    for a, t in CL:
        for extra in ([], ["-r"]) if a in ("leiden", "uclust") else ([],):
            ref, out = base + ".ref", base + ".out"
            cmd = ["-i", base + ".tsv", "--ids", base + ".ids.tsv", "--algorithm", a, "--metric", "ani", "--ani", t] + extra
            subprocess.run([VCLUST, "cluster", "-o", ref, "-v", "0"] + cmd, check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run([binc, "-o", out] + cmd + ["+RTS", "--threads", "12", "--gpu", "off", "-RTS"],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if open(ref, "rb").read() != open(out, "rb").read():
                print(f"DIFF cluster seed {seed} {a} {t} {' '.join(extra)} ({base}.tsv)", flush=True)
                bad += 1
    if not bad:
        for s in (".tsv", ".ids.tsv"):
            os.remove(base + s)
    return bad


def main():
    seeds = 20
    stage = "all"
    a = sys.argv[1:]
    if "--seeds" in a:
        seeds = int(a[a.index("--seeds") + 1])
    if "--stage" in a:
        stage = a[a.index("--stage") + 1]
    os.makedirs(WORK, exist_ok=True)
    bad = runs = 0
    if stage in ("prefilter", "all"):
        binp = build("prefilter")
        bina = build("align")
        for s in range(seeds):
            bad += fuzz_prefilter(random.Random(s), s, binp, bina)
            runs += len(PF_OPTS) + 4
    if stage in ("cluster", "all"):
        binc = build("cluster")
        for s in range(seeds):
            bad += fuzz_cluster(random.Random(1000 + s), s, binc)
            runs += 14
    print(f"{runs - bad}/{runs} identical", flush=True)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
