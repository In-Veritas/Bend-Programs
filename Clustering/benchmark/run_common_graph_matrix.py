#!/usr/bin/env python3
"""Benchmark Bend-to-C, independent C, and Clusty on one immutable graph."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MEASURE = Path(__file__).with_name("measure.py")
DEFAULT_C = ROOT / "c_baseline/cluster_graph"
DEFAULT_CLUSTY = (
    ROOT / ".tools/vclust-1.3.1/lib/python3.14/site-packages/bin/clusty"
)
ALGORITHMS = ("single", "complete", "uclust", "cd-hit", "set-cover")
ALGORITHM_CODES = {name: index for index, name in enumerate(ALGORITHMS)}
DEFAULT_BEND_REPO = ROOT.parent.parent / "bend"
DEFAULT_BEND_SOURCE = Path(__file__).with_name("bend_common_graph") / "main.bend"


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def object_ids(path):
    rows = Path(path).read_text().splitlines()
    header = rows[0].split("\t")
    column = header.index("id")
    return [row.split("\t")[column] for row in rows[1:]]


def partition_hash(path, numeric_ids=None):
    rows = Path(path).read_text().splitlines()
    if not rows or rows[0] != "object\tcluster":
        raise RuntimeError(f"unexpected cluster output header in {path}")
    groups = {}
    for row in rows[1:]:
        object_id, cluster = row.split("\t")
        if numeric_ids is not None:
            object_id = numeric_ids[int(object_id)]
        groups.setdefault(cluster, []).append(object_id)
    canonical = sorted(sorted(group) for group in groups.values())
    encoded = json.dumps(canonical, separators=(",", ":")).encode()
    return len(canonical), hashlib.sha256(encoded).hexdigest()


def checked_output(command):
    process = subprocess.run(command, text=True, capture_output=True, check=True)
    return (process.stdout.strip() or process.stderr.strip())


def measure(command, report_path, energy, stdout_output=None):
    invocation = [
        sys.executable,
        str(MEASURE),
        "--output", str(report_path),
        "--energy", energy,
    ]
    if stdout_output is not None:
        invocation.extend(["--stdout-output", str(stdout_output)])
    invocation.extend(["--", *map(str, command)])
    process = subprocess.run(invocation, text=True, capture_output=True)
    if process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip()
        raise RuntimeError(f"measurement failed: {' '.join(map(str, command))}\n{detail}")
    return json.loads(report_path.read_text())


def build_bend(repo, source, folder):
    bun = shutil.which("bun")
    clang = shutil.which("clang")
    entry = repo / "bend2/main.ts"
    if not bun or not clang or not entry.is_file():
        raise RuntimeError("Bun, Clang, and a current Bend checkout are required")
    emitted = folder / "bend-common-graph.c"
    binary = folder / "bend-common-graph"
    environment = dict(os.environ, BEND_NO_TELEMETRY="1")
    emit_command = [bun, str(entry), str(source.resolve()), "-o", str(emitted)]
    subprocess.run(emit_command, cwd=repo, env=environment, check=True)
    compile_command = [
        clang, "-O2", "-std=c11", "-lpthread", "-lm",
        str(emitted), "-o", str(binary),
    ]
    subprocess.run(compile_command, check=True)
    revision = checked_output(["git", "-C", str(repo), "rev-parse", "HEAD"])
    return binary, emit_command, compile_command, revision


def median_summary(runs):
    grouped = {}
    for run in runs:
        key = (run["implementation"], run["algorithm"], run["requested_threads"])
        grouped.setdefault(key, []).append(run)
    summaries = []
    for (implementation, algorithm, requested_threads), group in sorted(grouped.items()):
        energy_values = [
            run["energy"].get("estimated_cpu_joules")
            for run in group
            if run["energy"].get("available")
        ]
        summaries.append({
            "implementation": implementation,
            "algorithm": algorithm,
            "requested_threads": requested_threads,
            "effective_threads": group[0]["effective_threads"],
            "repeats": len(group),
            "median_wall_seconds": statistics.median(
                run["metrics"]["time_real_seconds"] for run in group
            ),
            "median_user_seconds": statistics.median(
                run["metrics"]["time_user_seconds"] for run in group
            ),
            "median_system_seconds": statistics.median(
                run["metrics"]["time_system_seconds"] for run in group
            ),
            "median_maximum_resident_bytes": int(statistics.median(
                run["metrics"]["maximum_resident_bytes"] for run in group
            )),
            "median_estimated_cpu_joules": (
                statistics.median(energy_values) if len(energy_values) == len(group)
                else None
            ),
            "membership_sha256": group[0]["membership_sha256"],
            "clusters": group[0]["clusters"],
        })
    return summaries


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ani", type=Path, required=True)
    parser.add_argument("--ids", type=Path, required=True)
    parser.add_argument("--source-fasta", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--metric", choices=("ani", "tani", "gani"), default="ani")
    parser.add_argument("--threshold", type=float, default=0.95)
    parser.add_argument("--threads", type=int, nargs="+", default=(1, 2, 4, 8))
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--algorithms", nargs="+", choices=ALGORITHMS,
                        default=ALGORITHMS)
    parser.add_argument("--energy", choices=("auto", "off"), default="off")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--c-binary", type=Path, default=DEFAULT_C)
    parser.add_argument("--clusty", type=Path, default=DEFAULT_CLUSTY)
    parser.add_argument("--bend-repo", type=Path, default=DEFAULT_BEND_REPO)
    parser.add_argument("--bend-source", type=Path, default=DEFAULT_BEND_SOURCE)
    parser.add_argument("--without-bend", action="store_true")
    args = parser.parse_args()

    if args.repeats < 1 or any(value < 1 for value in args.threads):
        parser.error("repeats and thread counts must be positive")
    if not 0 <= args.threshold <= 1:
        parser.error("threshold must be in 0..1")
    if args.c_binary.resolve() == DEFAULT_C.resolve():
        subprocess.run(["make", "-B"], cwd=ROOT / "c_baseline", check=True)
    elif not args.c_binary.is_file():
        parser.error(f"C binary does not exist: {args.c_binary}")
    if not args.clusty.is_file():
        parser.error(f"Clusty is not installed at {args.clusty}")

    c_compiler = os.environ.get("CC", "cc")
    c_version = checked_output([c_compiler, "--version"]).splitlines()[0]
    clusty_version = checked_output([str(args.clusty), "--version"])
    ordered_ids = object_ids(args.ids)
    runs = []
    comparisons = []
    with tempfile.TemporaryDirectory(prefix="common-graph-matrix-") as folder_text:
        folder = Path(folder_text)
        bend_binary = None
        bend_emit_command = None
        bend_compile_command = None
        bend_revision = None
        bend_binary_hash = None
        if not args.without_bend:
            bend_binary, bend_emit_command, bend_compile_command, bend_revision = build_bend(
                args.bend_repo.resolve(), args.bend_source.resolve(), folder
            )
            bend_binary_hash = sha256(bend_binary)
        implementations = (
            ("bend-c", "c11", "vclust-clusty")
            if bend_binary is not None else ("c11", "vclust-clusty")
        )
        for repeat in range(1, args.repeats + 1):
            for threads in args.threads:
                for algorithm in args.algorithms:
                    outputs = {}
                    implementation_order = (
                        implementations if repeat % 2 == 1
                        else tuple(reversed(implementations))
                    )
                    for implementation in implementation_order:
                        output = folder / f"{implementation}-{algorithm}-t{threads}-r{repeat}.tsv"
                        measurement = folder / f"{output.name}.measurement.json"
                        if implementation == "bend-c":
                            command = [
                                "/usr/bin/env",
                                f"CLUSTER_GRAPH_INPUT={args.ani.resolve()}",
                                f"CLUSTER_GRAPH_SIZE={len(ordered_ids)}",
                                f"CLUSTER_GRAPH_ALGORITHM={ALGORITHM_CODES[algorithm]}",
                                f"CLUSTER_GRAPH_THRESHOLD={round(args.threshold * 1_000_000)}",
                                bend_binary,
                                "--threads", str(threads),
                                "--gpu", "off",
                            ]
                            effective_threads = threads
                        elif implementation == "c11":
                            command = [
                                args.c_binary,
                                "--input", args.ani,
                                "--ids", args.ids,
                                "--output", output,
                                "--algorithm", algorithm,
                                "--metric", args.metric,
                                "--threshold", str(args.threshold),
                                "--threads", str(threads),
                            ]
                            effective_threads = 1
                        else:
                            command = [
                                args.clusty,
                                "--objects-file", args.ids,
                                "--algo", algorithm,
                                "--id-cols", "qidx", "ridx",
                                "--distance-col", args.metric,
                                "--similarity",
                                "--numeric-ids",
                                "--min", args.metric, str(args.threshold),
                                "-t", str(threads),
                                args.ani,
                                output,
                            ]
                            # Clusty 1.2.2 Graph clamps this value to at least four.
                            effective_threads = max(4, threads)
                        measured = measure(
                            command, measurement, args.energy,
                            output if implementation == "bend-c" else None,
                        )
                        clusters, membership = partition_hash(
                            output, ordered_ids if implementation == "bend-c" else None
                        )
                        outputs[implementation] = membership
                        runs.append({
                            "implementation": implementation,
                            "algorithm": algorithm,
                            "repeat": repeat,
                            "requested_threads": threads,
                            "effective_threads": effective_threads,
                            "command": measured["command"],
                            "metrics": measured["metrics"],
                            "energy": measured["energy"],
                            "clusters": clusters,
                            "membership_sha256": membership,
                            "output_sha256": sha256(output),
                        })
                    equal = len(set(outputs.values())) == 1
                    comparisons.append({
                        "algorithm": algorithm,
                        "repeat": repeat,
                        "requested_threads": threads,
                        "memberships_equal": equal,
                        "membership_sha256_by_implementation": outputs,
                    })
                    if not equal:
                        raise RuntimeError(
                            f"membership mismatch for {algorithm}, threads={threads}, "
                            f"repeat={repeat}"
                        )

    bend_sources = [
        args.bend_source,
        args.bend_source.with_name("graph_io.bend"),
        args.bend_source.with_name("algorithms.bend"),
        ROOT / "lib/common.bend",
        ROOT / "lib/packing.bend",
        ROOT / "single_linkage.bend",
        ROOT / "complete_linkage.bend",
        ROOT / "set_cover.bend",
    ]
    report = {
        "schema": 1,
        "status": "valid" if all(row["memberships_equal"] for row in comparisons)
                  else "invalid",
        "benchmark": "common immutable ANI graph clustering kernel",
        "input": {
            "ani": {"path": str(args.ani), "bytes": args.ani.stat().st_size,
                    "sha256": sha256(args.ani)},
            "ids": {"path": str(args.ids), "bytes": args.ids.stat().st_size,
                    "sha256": sha256(args.ids)},
            "metric": args.metric,
            "threshold": args.threshold,
        },
        "toolchain": {
            "c_compiler": c_version,
            "c_compiler_command": c_compiler,
            "c_flags": os.environ.get(
                "CFLAGS", "-O3 -std=c11 -Wall -Wextra -Wpedantic"
            ),
            "c_link_flags": os.environ.get("LDFLAGS", ""),
            "c_fixed_libraries": "-lm",
            "c_makefile_sha256": sha256(ROOT / "c_baseline/Makefile"),
            "c_source_sha256": sha256(ROOT / "c_baseline/cluster_graph.c"),
            "c_binary_sha256": sha256(args.c_binary),
            "clusty": clusty_version,
            "clusty_thread_note": (
                "Clusty 1.2.2 accepts the undocumented -t option but its Graph "
                "constructor clamps the effective count to at least four"
            ),
            "bend_revision": bend_revision,
            "bend_emit_command": list(map(str, bend_emit_command or ())),
            "bend_compile_command": list(map(str, bend_compile_command or ())),
            "bend_binary_sha256": bend_binary_hash,
            "bend_source_sha256": {
                str(path): sha256(path) for path in bend_sources if path.is_file()
            },
            "bend_thread_note": (
                "the native runtime receives the requested worker count; these "
                "benchmark kernels contain no explicit parallel form"
            ),
            "platform": {
                "system": platform.system(),
                "release": platform.release(),
                "machine": platform.machine(),
            },
        },
        "configuration": {
            "algorithms": list(args.algorithms),
            "requested_threads": args.threads,
            "repeats": args.repeats,
            "energy_mode": args.energy,
            "execution_order": (
                "repeat, requested threads, algorithm; implementation order "
                "reverses between repeats"
            ),
        },
        "comparisons": comparisons,
        "runs": runs,
        "summary": median_summary(runs),
    }
    if args.source_fasta is not None:
        report["input"]["source_fasta"] = {
            "path": str(args.source_fasta),
            "bytes": args.source_fasta.stat().st_size,
            "sha256": sha256(args.source_fasta),
        }
    encoded = json.dumps(report, indent=2) + "\n"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_name(args.output.name + ".tmp")
    temporary.write_text(encoded)
    os.replace(temporary, args.output)
    if not args.quiet:
        print(encoded, end="")


if __name__ == "__main__":
    main()
