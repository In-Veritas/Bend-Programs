#!/usr/bin/env python3
"""Fuzz: Bend prefilter (Kmer-db port) vs `vclust prefilter`, byte for byte.

Random multi-FASTAs built to stress the Kmer-db method: families of mutated
copies (many shared k-mers, deep pattern trees), exact duplicates (patterns
extended in place), tandem repeats and homopolymers (repeated k-mers within a
sample), N runs and IUPAC/lowercase symbols (broken k-mers), records shorter
than k and empty records, many tiny records (patterns that become bubbles with
a small --bubble-size). Each case runs a few option sets, including
Bend-only --bubble-size / -t variants that must reproduce the plain run.

  CAP=4G capped python3 tests/fuzz_prefilter.py [--cases N] [--seed S]
"""
import os, random, signal, subprocess, sys, importlib.util, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
VCLUST = os.path.join(os.path.dirname(PKG), ".tools", "vclust-1.3.1", "bin", "vclust")
if not os.path.exists(VCLUST):
    VCLUST = os.path.expanduser("~/Bend-Programs/Clustering/.tools/vclust-1.3.1/bin/vclust")


def build():
    spec = importlib.util.spec_from_file_location('launcher', os.path.join(PKG, 'run.py'))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return str(m.build('prefilter'))


def mutate(s, rate, rng):
    out = []
    for c in s:
        r = rng.random()
        if r < rate / 3:
            continue                       # deletion
        if r < 2 * rate / 3:
            out.append(rng.choice("ACGT"))  # substitution
        elif r < rate:
            out.append(c); out.append(rng.choice("ACGT"))  # insertion
        else:
            out.append(c)
    return "".join(out)


def dataset(rng):
    recs = []
    for f in range(rng.randint(1, 6)):
        base = "".join(rng.choice("ACGT") for _ in range(rng.randint(200, 3000)))
        for c in range(rng.randint(1, 12)):
            s = mutate(base, rng.choice([0, 0.001, 0.01, 0.05, 0.2]), rng)
            if rng.random() < 0.2:
                s = s + s[: rng.randint(0, len(s))]           # internal repeat
            if rng.random() < 0.2:
                i = rng.randint(0, len(s)); s = s[:i] + "N" * rng.randint(1, 40) + s[i:]
            if rng.random() < 0.1:
                s = s.lower()
            if rng.random() < 0.1:
                i = rng.randint(0, len(s)); s = s[:i] + rng.choice("RYKMSWnx-") + s[i:]
            recs.append(s)
    for _ in range(rng.randint(0, 20)):                        # tiny / odd records
        recs.append(rng.choice(["", "ACGT", "A" * rng.randint(1, 80),
                                ("ACGTTGCA" * 20)[: rng.randint(10, 160)],
                                "".join(rng.choice("ACGT") for _ in range(rng.randint(20, 60)))]))
    for _ in range(rng.randint(0, 3)):                        # duplicates
        if recs:
            recs.append(rng.choice(recs))
    rng.shuffle(recs)
    lines = []
    for i, s in enumerate(recs):
        lines.append(f">r{i} desc{i}")
        w = rng.choice([60, 70, 10 ** 6])
        lines += [s[j:j + w] for j in range(0, len(s), w)] or [""]
    return "\n".join(lines) + "\n"


OPTS = [
    ([], []),
    (["--min-kmers", "1", "--min-ident", "0"], ["--min-kmers", "1", "--min-ident", "0"]),
    (["--min-kmers", "0", "--min-ident", "0"], ["--min-kmers", "0", "--min-ident", "0"]),
    (["-k", "15", "--min-kmers", "2", "--min-ident", "0.5"], ["-k", "15", "--min-kmers", "2", "--min-ident", "0.5"]),
    (["--max-seqs", "3", "--min-kmers", "2", "--min-ident", "0.5"], ["--max-seqs", "3", "--min-kmers", "2", "--min-ident", "0.5"]),
    (["--batch-size", "7", "--min-kmers", "2", "--min-ident", "0.5"], ["--batch-size", "7", "--min-kmers", "2", "--min-ident", "0.5"]),
    (["--kmers-fraction", "0.3", "--min-kmers", "1", "--min-ident", "0.3"], ["--kmers-fraction", "0.3", "--min-kmers", "1", "--min-ident", "0.3"]),
    (["--bubble-size", "2", "--min-kmers", "1", "--min-ident", "0"], ["--min-kmers", "1", "--min-ident", "0"]),
    (["--bubble-size", "3", "--batch-size", "5", "--min-kmers", "1", "--min-ident", "0.2"], ["--batch-size", "5", "--min-kmers", "1", "--min-ident", "0.2"]),
    (["-t", "3", "--min-kmers", "1", "--min-ident", "0"], ["--min-kmers", "1", "--min-ident", "0"]),
]


def main():
    args = sys.argv[1:]
    n = int(args[args.index("--cases") + 1]) if "--cases" in args else 20
    seed = int(args[args.index("--seed") + 1]) if "--seed" in args else 1
    rng = random.Random(seed)
    binary = build()
    fails = total = skips = 0
    with tempfile.TemporaryDirectory() as tmp:
        for c in range(n):
            fa = os.path.join(tmp, f"c{c}.fasta")
            open(fa, "w").write(dataset(rng))
            for bopts, vopts in OPTS:
                ref = os.path.join(tmp, "ref.txt"); out = os.path.join(tmp, "out.txt")
                for p in (ref, out):
                    if os.path.exists(p): os.remove(p)
                child = subprocess.Popen([VCLUST, "prefilter", "-i", fa, "-o", ref, "-t", "4", "-v", "0"] + vopts,
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                try:
                    child.wait(timeout=60)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL); child.wait()   # only our own process group
                    skips += 1
                    keep = os.path.join(PKG, ".work", "fuzz", f"seed{seed}_case{c}_vclust_timeout")
                    os.makedirs(keep, exist_ok=True); subprocess.run(["cp", fa, keep])
                    print(f"SKIP case {c} {' '.join(vopts)}: Vclust timed out (input kept in {keep})", flush=True)
                    continue
                subprocess.run([binary, "-i", fa, "-o", out] + bopts + ["+RTS", "--threads", "4", "-RTS"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=300)
                total += 1
                same = os.path.exists(ref) and os.path.exists(out) and open(ref, "rb").read() == open(out, "rb").read()
                if not same:
                    fails += 1
                    keep = os.path.join(PKG, ".work", "fuzz", f"seed{seed}_case{c}")
                    os.makedirs(keep, exist_ok=True)
                    subprocess.run(["cp", fa, keep])
                    print(f"DIFF case {c} {' '.join(bopts)} (input kept in {keep})", flush=True)
            print(f"case {c}: done", flush=True)
    print(f"{total - fails}/{total} identical, {skips} skipped (Vclust timed out)")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
