#!/usr/bin/env python3
"""Build and launch the Bend programs. All sequence processing runs in Bend."""

import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
from decimal import Decimal, InvalidOperation

ROOT = Path(__file__).resolve().parent
ALGORITHMS = {
    "single-linkage": "single_linkage",
    "complete-linkage": "complete_linkage",
    "uclust": "uclust",
    "set-cover": "set_cover",
    "cd-hit": "cd_hit",
    "leiden": "leiden",
}
FASTA_SUFFIXES = {".fasta", ".fa", ".fna", ".ffn", ".frn", ".fas", ".fsa"}
MAX_INPUT_BYTES = 256 * 1024 * 1024


def default_compiler():
    configured = os.environ.get("BEND_REPO") or os.environ.get("BEND_CORE")
    if configured:
        return Path(configured)
    current = ROOT.parent.parent / "bend"
    fallback = ROOT.parent.parent / "bend2-core"
    if (current / "bend2/main.ts").is_file() or not (fallback / "bend2/main.ts").is_file():
        return current
    return fallback


def fraction(value):
    try:
        number = Decimal(value)
        scaled = number * 10000
        if not number.is_finite() or not 0 < number <= 1:
            raise ValueError
        if scaled != scaled.to_integral_value():
            raise ValueError
        return int(scaled)
    except (InvalidOperation, ValueError):
        raise argparse.ArgumentTypeError(
            "use a fraction in (0, 1], with at most four decimal places"
        ) from None


def bounded_integer(limit, minimum=0):
    def parse(value):
        try:
            result = int(value)
            if not minimum <= result <= limit:
                raise ValueError
            return result
        except ValueError:
            raise argparse.ArgumentTypeError(
                f"use an integer in {minimum}..{limit}"
            ) from None
    return parse


def build(algorithm, backend, compiler, threads=1):
    bun = shutil.which("bun")
    if not bun:
        raise RuntimeError("Bun is required to compile Bend (bun was not found)")
    entry = compiler / "bend2" / "main.ts"
    if not entry.is_file():
        raise RuntimeError(f"Bend compiler not found: {entry}")
    compiler_files = sorted((compiler / "bend2").glob("*.ts"))
    compiler_files += [compiler / "bend2" / "base.bend"]
    compiler_files += sorted((compiler / "bend2" / "effs").glob("*"))
    source_files = [ROOT / f"{ALGORITHMS[algorithm]}.bend"]
    source_files += sorted((ROOT / "lib").glob("*.bend"))
    digest = hashlib.sha256()
    digest.update(f"v2:{backend}:{platform.machine()}:{platform.system()}".encode())
    digest.update(subprocess.check_output([bun, "--version"]))
    clang = shutil.which("clang") if backend == "c" else None
    if backend == "c":
        if not clang:
            raise RuntimeError("Clang was not found; install it or use --backend js")
        digest.update(subprocess.check_output([clang, "--version"]))
    for path in compiler_files + source_files:
        if path.is_file():
            digest.update(path.name.encode())
            digest.update(path.read_bytes())
    cache = Path(tempfile.gettempdir()) / "bend-fasta-cache" / digest.hexdigest()
    executable = cache / ("program.js" if backend == "js" else "program")
    if not executable.is_file():
        cache.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="build-", dir=cache) as folder:
            emitted = Path(folder) / ("program.js" if backend == "js" else "program.c")
            subprocess.run([bun, str(entry), str(source_files[0]), "-o", str(emitted)],
                           cwd=compiler, check=True, env=dict(os.environ, BEND_NO_TELEMETRY="1"))
            product = emitted
            if backend == "c":
                product = Path(folder) / "program"
                subprocess.run([clang, "-O2", "-std=c11", "-lpthread", "-lm",
                                str(emitted), "-o", str(product)], check=True)
            os.replace(product, executable)
    if backend == "js":
        return [bun, str(executable)]
    return [str(executable), "--threads", str(threads), "--gpu", "off"]


def same_path(left, right):
    if left.resolve() == right.resolve():
        return True
    return left.exists() and right.exists() and os.path.samefile(left, right)


def input_files(path, recursive=False, output_dir=None):
    if path.is_file():
        if recursive:
            raise ValueError("--recursive requires a FASTA folder")
        files = [path]
    elif path.is_dir():
        entries = path.rglob("*") if recursive else path.iterdir()
        files = sorted((p for p in entries if p.suffix.lower() in FASTA_SUFFIXES
                        and not p.name.lower().endswith(".representatives.fasta")
                        and (output_dir is None or not p.resolve().is_relative_to(output_dir.resolve()))
                        and p.is_file()), key=lambda p: p.relative_to(path).as_posix())
        if not files:
            raise ValueError(f"no FASTA files found in folder: {path}")
    else:
        raise ValueError(f"FASTA file or folder not found: {path}")
    for file in files:
        if file.stat().st_size > MAX_INPUT_BYTES:
            raise ValueError(f"FASTA input exceeds 256 MiB: {file}")
    return files


def main():
    parser = argparse.ArgumentParser(
        description="Cluster DNA/RNA FASTA records using algorithms written in Bend.",
        epilog="Output is TSV in input order. Indices are zero-based. "
               "Inputs are limited to 16384 records, 300000 residues per record, and 256 MiB.",
    )
    parser.add_argument("algorithm", choices=ALGORITHMS)
    parser.add_argument("input", type=Path, help="uncompressed FASTA file or folder; "
                        "each file in a folder is clustered independently")
    parser.add_argument("--recursive", action="store_true",
                        help="also read FASTA files in subfolders")
    parser.add_argument("--identity", type=fraction, default=9000, metavar="FRACTION",
                        help="inclusive identity threshold; default: 0.9")
    parser.add_argument("--strand", choices=("plus", "both"), default="plus",
                        help="compare the supplied strand or also reverse complements")
    scoring = parser.add_mutually_exclusive_group()
    scoring.add_argument("--fast", action="store_true",
                         help="replace long-sequence alignment with an indexed approximate "
                              "64-bin 15-mer MinHash score; much faster, but may miss or "
                              "admit cluster edges")
    scoring.add_argument("--lz-ani", action="store_true",
                         help="use the Bend LZ-ANI port and Vclust's symmetric total-ANI "
                              "metric after a sparse canonical 25-mer prefilter")
    parser.add_argument("--min-kmers", type=bounded_integer(4294967295, 1),
                        default=20,
                        help="minimum shared unique canonical 25-mers for an LZ-ANI "
                             "candidate; default: 20 (Vclust/Kmer-db default)")
    parser.add_argument("--min-ident", type=fraction, default=7000,
                        metavar="FRACTION",
                        help="minimum Kmer-db ani-shorter candidate estimate; "
                             "default: 0.7")
    parser.add_argument("--resolution", type=fraction, default=5000, metavar="FRACTION",
                        help="Leiden CPM resolution on the unweighted graph; default: 0.5")
    parser.add_argument("--seed", type=bounded_integer(4294967295), default=1,
                        help="Leiden random seed; default: 1")
    parser.add_argument("--passes", type=bounded_integer(100000, 1), default=100,
                        help="maximum Leiden local-move sweeps per level; default: 100")
    parser.add_argument("--output", "-o", type=Path, help="TSV destination; default: stdout")
    parser.add_argument("--representatives", type=Path,
                        help="also write a FASTA file containing cluster representatives")
    parser.add_argument("--output-dir", type=Path,
                        help="folder results directory (default: INPUT/clusters/ALGORITHM); "
                        "writes a TSV and representative FASTA for every input file")
    parser.add_argument("--backend", choices=("c", "js"), default="c")
    parser.add_argument("--threads", type=bounded_integer(256, 1), default=1,
                        help="native Bend runtime CPU threads; default: 1")
    parser.add_argument("--compiler", type=Path,
                        default=default_compiler(),
                        help="Bend checkout (default: sibling bend; falls back to bend2-core)")
    args = parser.parse_args()
    if args.backend == "js" and args.threads != 1:
        parser.error("the JavaScript backend is single-threaded; use --threads 1")
    batch = args.input.is_dir()
    if batch:
        if args.output is not None or args.representatives is not None:
            parser.error("folder input uses --output-dir, not --output or --representatives")
        output_dir = args.output_dir or args.input / "clusters" / args.algorithm
        if args.input.resolve().is_relative_to(output_dir.resolve()):
            parser.error("--output-dir must not be the input folder or its ancestor")
    else:
        if args.output_dir is not None:
            parser.error("--output-dir requires a FASTA folder")
        output_dir = None
    try:
        inputs = input_files(args.input, args.recursive, output_dir)
        if batch:
            jobs = []
            for source in inputs:
                base = output_dir / source.relative_to(args.input)
                jobs.append((source, base.with_name(base.name + ".clusters.tsv"),
                             base.with_name(base.name + ".representatives.fasta")))
        else:
            jobs = [(args.input, args.output, args.representatives)]
        outputs = [p for _, table, reps in jobs for p in (table, reps) if p is not None]
        for index, path in enumerate(outputs):
            for previous in inputs + outputs[:index]:
                if same_path(path, previous):
                    raise ValueError("input, TSV output, and representatives must use different files")
            if not batch and not path.parent.is_dir():
                raise ValueError(f"output directory does not exist: {path.parent}")
            if path.exists() and not path.is_file():
                raise ValueError(f"output is not a regular file: {path}")
    except (OSError, ValueError) as error:
        parser.error(str(error))
    temporary = []
    table = None
    try:
        command = build(args.algorithm, args.backend, args.compiler.resolve(), args.threads)
        env = dict(os.environ)
        env.update(CLUSTER_DNA="1",
                   CLUSTER_IDENTITY=str(args.identity),
                   CLUSTER_REVERSE=str(int(args.strand == "both")),
                   CLUSTER_FAST=str(int(args.fast)),
                   CLUSTER_LZ_ANI=str(int(args.lz_ani)),
                   CLUSTER_KMER_MINIMUM=str(args.min_kmers),
                   CLUSTER_KMER_IDENTITY=str(args.min_ident),
                   CLUSTER_RESOLUTION=str(args.resolution), CLUSTER_SEED=str(args.seed),
                   CLUSTER_PASSES=str(args.passes))
        for source, output, representatives in jobs:
            env.update(CLUSTER_INPUT=str(source.resolve()), CLUSTER_REPRESENTATIVES="")
            table = None
            for destination in (output, representatives):
                if destination is not None:
                    if batch:
                        destination.parent.mkdir(parents=True, exist_ok=True)
                    fd, name = tempfile.mkstemp(prefix=".bend-cluster-", dir=destination.parent)
                    os.close(fd)
                    temporary.append((Path(name), destination))
                    if destination == output:
                        table = open(name, "wb")
                    else:
                        env["CLUSTER_REPRESENTATIVES"] = str(Path(name).resolve())
            result = subprocess.run(command, env=env, stdout=table)
            if table:
                table.close()
            if result.returncode:
                print(f"error: clustering failed for {source}", file=sys.stderr)
                return result.returncode
        for source, destination in temporary:
            os.replace(source, destination)
        if batch:
            print(f"Clustered {len(jobs)} FASTA files independently. Results: {output_dir}",
                  file=sys.stderr)
        return 0
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    finally:
        if table and not table.closed:
            table.close()
        for source, _ in temporary:
            source.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
