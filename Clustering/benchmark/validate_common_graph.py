#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_C = ROOT / "c_baseline/cluster_graph"
DEFAULT_VCLUST = ROOT / ".tools/vclust-1.3.1/bin/vclust"
ALGORITHMS = ("single", "complete", "uclust", "cd-hit", "set-cover", "leiden")
STRICT_ALGORITHMS = frozenset(ALGORITHMS[:-1])


def partition(path):
    rows = Path(path).read_text().splitlines()
    if not rows or rows[0] != "object\tcluster":
        raise ValueError(f"unexpected cluster header in {path}")
    groups = {}
    for row in rows[1:]:
        object_id, cluster = row.split("\t")
        groups.setdefault(cluster, []).append(object_id)
    canonical = sorted(sorted(group) for group in groups.values())
    encoded = json.dumps(canonical, separators=(",", ":")).encode()
    return canonical, hashlib.sha256(encoded).hexdigest()


def file_sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ani", type=Path, required=True)
    parser.add_argument("--ids", type=Path, required=True)
    parser.add_argument("--metric", choices=("ani", "tani", "gani"), default="ani")
    parser.add_argument("--threshold", type=float, default=0.95)
    parser.add_argument("--source-fasta", type=Path)
    parser.add_argument("--c-binary", type=Path, default=DEFAULT_C)
    parser.add_argument("--vclust", type=Path, default=DEFAULT_VCLUST)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    if not args.c_binary.is_file():
        subprocess.run(["make"], cwd=ROOT / "c_baseline", check=True)
    results = {}
    with tempfile.TemporaryDirectory(prefix="common-graph-validation-") as folder_text:
        folder = Path(folder_text)
        for algorithm in ALGORITHMS:
            c_output = folder / f"c-{algorithm}.tsv"
            vclust_output = folder / f"vclust-{algorithm}.tsv"
            subprocess.run(
                [
                    str(args.c_binary),
                    "--input", str(args.ani),
                    "--ids", str(args.ids),
                    "--output", str(c_output),
                    "--algorithm", algorithm,
                    "--metric", args.metric,
                    "--threshold", str(args.threshold),
                    "--threads", "1",
                ],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            command = [
                str(args.vclust), "cluster",
                "-i", str(args.ani),
                "--ids", str(args.ids),
                "-o", str(vclust_output),
                "--algorithm", algorithm,
                "--metric", args.metric,
                f"--{args.metric}", str(args.threshold),
                "-v", "0",
            ]
            subprocess.run(command, check=True, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
            c_partition, c_hash = partition(c_output)
            vclust_partition, vclust_hash = partition(vclust_output)
            results[algorithm] = {
                "equal": c_partition == vclust_partition,
                "c_clusters": len(c_partition),
                "vclust_clusters": len(vclust_partition),
                "c_membership_sha256": c_hash,
                "vclust_membership_sha256": vclust_hash,
                "strict": algorithm in STRICT_ALGORITHMS,
            }
    report = {
        "schema": 1,
        "ani": {
            "path": str(args.ani.resolve()),
            "sha256": file_sha256(args.ani),
            "bytes": args.ani.stat().st_size,
        },
        "ids": {
            "path": str(args.ids.resolve()),
            "sha256": file_sha256(args.ids),
            "bytes": args.ids.stat().st_size,
        },
        "metric": args.metric,
        "threshold": args.threshold,
        "algorithms": results,
        "all_strict_matches": all(
            result["equal"] for result in results.values() if result["strict"]
        ),
    }
    if args.source_fasta is not None:
        report["source_fasta"] = {
            "path": str(args.source_fasta),
            "sha256": file_sha256(args.source_fasta),
            "bytes": args.source_fasta.stat().st_size,
        }
    encoded = json.dumps(report, indent=2) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_name(args.output.name + ".tmp")
        temporary.write_text(encoded)
        os.replace(temporary, args.output)
    print(encoded, end="")
    if any(not result["equal"] and result["strict"] for result in results.values()):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
