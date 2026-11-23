#!/usr/bin/env python3
"""Benchmark Vclust prefilter and alignment across a thread matrix."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MEASURE = Path(__file__).with_name("measure.py")
DEFAULT_VCLUST = ROOT / ".tools/vclust-1.3.1/bin/vclust"


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_tsv_sha256(path):
    rows = Path(path).read_bytes().splitlines()
    if not rows:
        return hashlib.sha256(b"").hexdigest()
    encoded = b"\n".join([rows[0], *sorted(rows[1:])]) + b"\n"
    return hashlib.sha256(encoded).hexdigest()


def line_count(path):
    with Path(path).open("rb") as source:
        return sum(1 for _ in source)


def measure(command, report_path, energy):
    invocation = [
        sys.executable,
        str(MEASURE),
        "--output", str(report_path),
        "--energy", energy,
        "--",
        *map(str, command),
    ]
    process = subprocess.run(invocation, text=True, capture_output=True)
    if process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip()
        raise RuntimeError(f"measurement failed: {' '.join(map(str, command))}\n{detail}")
    return json.loads(report_path.read_text())


def summarize(runs):
    summaries = []
    for threads in sorted({run["threads"] for run in runs}):
        selected = [run for run in runs if run["threads"] == threads]
        row = {"threads": threads, "repeats": len(selected)}
        for stage in ("prefilter", "align"):
            measurements = [run[stage] for run in selected]
            row[stage] = {
                "median_wall_seconds": statistics.median(
                    value["metrics"]["time_real_seconds"] for value in measurements
                ),
                "median_user_seconds": statistics.median(
                    value["metrics"]["time_user_seconds"] for value in measurements
                ),
                "median_system_seconds": statistics.median(
                    value["metrics"]["time_system_seconds"] for value in measurements
                ),
                "median_maximum_resident_bytes": int(statistics.median(
                    value["metrics"]["maximum_resident_bytes"] for value in measurements
                )),
            }
        totals = [
            run["prefilter"]["metrics"]["time_real_seconds"]
            + run["align"]["metrics"]["time_real_seconds"]
            for run in selected
        ]
        row["median_pipeline_wall_seconds"] = statistics.median(totals)
        summaries.append(row)
    baseline = next(
        (row["median_pipeline_wall_seconds"] for row in summaries if row["threads"] == 1),
        None,
    )
    for row in summaries:
        row["pipeline_speedup_vs_one_thread"] = (
            baseline / row["median_pipeline_wall_seconds"] if baseline else None
        )
    return summaries


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fasta", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--threads", type=int, nargs="+", default=(1, 2, 4, 8))
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--min-ident", type=float, default=0.7)
    parser.add_argument("--filter-threshold", type=float, default=0.7)
    parser.add_argument("--energy", choices=("auto", "off"), default="off")
    parser.add_argument("--vclust", type=Path, default=DEFAULT_VCLUST)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    if args.repeats < 1 or any(value < 1 for value in args.threads):
        parser.error("repeats and thread counts must be positive")
    if not 0 <= args.min_ident <= 1 or not 0 <= args.filter_threshold <= 1:
        parser.error("identity thresholds must be in 0..1")
    if not args.vclust.is_file():
        parser.error(f"Vclust is not installed at {args.vclust}")

    info = subprocess.run(
        [str(args.vclust), "info"], text=True, capture_output=True, check=True
    ).stdout.strip()
    runs = []
    with tempfile.TemporaryDirectory(prefix="vclust-frontend-matrix-") as folder_text:
        folder = Path(folder_text)
        for repeat in range(1, args.repeats + 1):
            # Reverse the thread order every other repeat to reduce order bias.
            thread_order = args.threads if repeat % 2 == 1 else tuple(reversed(args.threads))
            for threads in thread_order:
                stem = f"t{threads}-r{repeat}"
                filter_path = folder / f"{stem}.filter.tsv"
                ani_path = folder / f"{stem}.ani.tsv"
                ids_path = ani_path.with_suffix(".ids.tsv")
                prefilter_command = [
                    args.vclust, "prefilter",
                    "-i", args.fasta,
                    "-o", filter_path,
                    "--min-ident", str(args.min_ident),
                    "--threads", str(threads),
                    "-v", "0",
                ]
                prefilter = measure(
                    prefilter_command, folder / f"{stem}.prefilter.measurement.json",
                    args.energy,
                )
                align_command = [
                    args.vclust, "align",
                    "-i", args.fasta,
                    "-o", ani_path,
                    "--filter", filter_path,
                    "--filter-threshold", str(args.filter_threshold),
                    "--outfmt", "complete",
                    "--threads", str(threads),
                    "-v", "0",
                ]
                align = measure(
                    align_command, folder / f"{stem}.align.measurement.json",
                    args.energy,
                )
                runs.append({
                    "threads": threads,
                    "repeat": repeat,
                    "prefilter": prefilter,
                    "align": align,
                    "outputs": {
                        "filter": {
                            "bytes": filter_path.stat().st_size,
                            "lines": line_count(filter_path),
                            "sha256": sha256(filter_path),
                            "canonical_sha256": canonical_tsv_sha256(filter_path),
                        },
                        "ani": {
                            "bytes": ani_path.stat().st_size,
                            "lines": line_count(ani_path),
                            "sha256": sha256(ani_path),
                            "canonical_sha256": canonical_tsv_sha256(ani_path),
                        },
                        "ids": {
                            "bytes": ids_path.stat().st_size,
                            "lines": line_count(ids_path),
                            "sha256": sha256(ids_path),
                        },
                    },
                })

    canonical_filter_hashes = {
        run["outputs"]["filter"]["canonical_sha256"] for run in runs
    }
    canonical_ani_hashes = {
        run["outputs"]["ani"]["canonical_sha256"] for run in runs
    }
    ids_hashes = {run["outputs"]["ids"]["sha256"] for run in runs}
    deterministic = (
        len(canonical_filter_hashes) == 1
        and len(canonical_ani_hashes) == 1
        and len(ids_hashes) == 1
    )
    report = {
        "schema": 1,
        "status": "valid" if deterministic else "invalid",
        "benchmark": "Vclust prefilter and complete-format alignment thread matrix",
        "input": {
            "path": str(args.fasta),
            "bytes": args.fasta.stat().st_size,
            "sha256": sha256(args.fasta),
        },
        "toolchain": {
            "vclust_info": info,
            "platform": {
                "system": platform.system(),
                "release": platform.release(),
                "machine": platform.machine(),
            },
        },
        "configuration": {
            "threads": args.threads,
            "repeats": args.repeats,
            "min_identity": args.min_ident,
            "alignment_filter_threshold": args.filter_threshold,
            "alignment_output_format": "complete",
            "energy_mode": args.energy,
            "thread_order": "forward on odd repeats; reversed on even repeats",
        },
        "determinism": {
            "canonical_filter_hashes": sorted(canonical_filter_hashes),
            "canonical_ani_hashes": sorted(canonical_ani_hashes),
            "ids_hashes": sorted(ids_hashes),
        },
        "runs": runs,
        "summary": summarize(runs),
    }
    encoded = json.dumps(report, indent=2) + "\n"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_name(args.output.name + ".tmp")
    temporary.write_text(encoded)
    os.replace(temporary, args.output)
    if not args.quiet:
        print(encoded, end="")
    if not deterministic:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
