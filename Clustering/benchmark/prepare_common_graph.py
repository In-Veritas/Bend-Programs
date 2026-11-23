#!/usr/bin/env python3
"""Filter a Vclust ANI table into the compact graph shared by all kernels."""

import argparse
from decimal import Decimal, InvalidOperation
import hashlib
import json
import os
from pathlib import Path


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ani", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--metric", choices=("ani", "tani", "gani"), default="ani")
    parser.add_argument("--threshold", default="0.95")
    args = parser.parse_args()
    try:
        threshold = Decimal(args.threshold)
    except InvalidOperation:
        parser.error("threshold must be decimal")
    if not Decimal(0) <= threshold <= Decimal(1):
        parser.error("threshold must be in 0..1")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_name(args.output.name + ".tmp")
    input_rows = 0
    qualifying_rows = 0
    edges = {}
    with args.ani.open() as source:
        header = source.readline().rstrip("\r\n").split("\t")
        try:
            qidx = header.index("qidx")
            ridx = header.index("ridx")
            score = header.index(args.metric)
        except ValueError as error:
            raise SystemExit(f"missing ANI column: {error}") from None
        for number, line in enumerate(source, 2):
            fields = line.rstrip("\r\n").split("\t")
            input_rows += 1
            try:
                value = Decimal(fields[score])
            except (IndexError, InvalidOperation):
                raise SystemExit(f"invalid ANI row {number}") from None
            if value >= threshold:
                qualifying_rows += 1
                left = int(fields[qidx])
                right = int(fields[ridx])
                if right < left:
                    left, right = right, left
                pair = (left, right)
                previous = edges.get(pair)
                if previous is None or value > previous[0]:
                    edges[pair] = (value, fields[score])
    with temporary.open("w") as destination:
        destination.write(f"qidx\tridx\t{args.metric}\n")
        for (left, right), (_, text) in sorted(edges.items()):
            destination.write(f"{left}\t{right}\t{text}\n")
    os.replace(temporary, args.output)
    report = {
        "schema": 1,
        "source": {
            "path": str(args.ani),
            "bytes": args.ani.stat().st_size,
            "sha256": sha256(args.ani),
            "rows": input_rows,
        },
        "graph": {
            "path": str(args.output),
            "bytes": args.output.stat().st_size,
            "sha256": sha256(args.output),
            "qualifying_source_rows": qualifying_rows,
            "edges": len(edges),
            "duplicates_collapsed": qualifying_rows - len(edges),
        },
        "metric": args.metric,
        "threshold": str(threshold),
    }
    encoded = json.dumps(report, indent=2) + "\n"
    args.metadata.parent.mkdir(parents=True, exist_ok=True)
    meta_temp = args.metadata.with_name(args.metadata.name + ".tmp")
    meta_temp.write_text(encoded)
    os.replace(meta_temp, args.metadata)
    print(encoded, end="")


if __name__ == "__main__":
    main()
