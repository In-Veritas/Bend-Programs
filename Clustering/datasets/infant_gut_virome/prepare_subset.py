#!/usr/bin/env python3
"""Prepare deterministic EarlyVir inputs for smoke tests and benchmarks."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RAW_FASTA = ROOT / "raw" / "all.curated.vOTUs.EarlyVir.fna"
TAXONOMY = ROOT / "raw" / "taxtable.tsv"
READY = ROOT / "ready"
IUPAC = frozenset("ACGTURYKMSWBDHVN")


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=16)
    parser.add_argument("--max-length", type=int, default=30_000)
    parser.add_argument(
        "--selection",
        choices=("shortest", "stratified"),
        default="shortest",
        help="select the shortest records or evenly cover the eligible length ranking",
    )
    args = parser.parse_args()
    if args.count < 1:
        parser.error("--count must be positive")
    if args.max_length < 1:
        parser.error("--max-length must be positive")
    return args


def taxonomy_entries() -> list[dict[str, object]]:
    entries = []
    seen = set()
    with TAXONOMY.open(encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            fields = line.rstrip("\n\r").split("\t")
            if len(fields) != 23:
                raise ValueError(
                    f"{TAXONOMY}:{line_number}: expected 23 fields, got {len(fields)}"
                )
            identifier = fields[0]
            if identifier in seen:
                raise ValueError(f"duplicate taxonomy identifier: {identifier}")
            seen.add(identifier)
            entries.append(
                {
                    "id": identifier,
                    "declared_length": int(fields[11]),
                    "taxonomy_fields": fields[1:],
                }
            )
    return entries


def selected_sequences(selected_ids: set[str]) -> tuple[dict[str, tuple[str, str]], int]:
    selected = {}
    record_count = 0
    header = None
    chunks: list[str] = []

    def finish_record() -> None:
        nonlocal record_count
        if header is None:
            return
        record_count += 1
        identifier = header.split(None, 1)[0]
        if identifier not in selected_ids:
            return
        if identifier in selected:
            raise ValueError(f"duplicate FASTA identifier: {identifier}")
        sequence = "".join(chunks).upper()
        invalid = sorted(set(sequence) - IUPAC)
        if invalid:
            raise ValueError(f"invalid bases in {identifier}: {''.join(invalid)}")
        selected[identifier] = (header, sequence)

    with RAW_FASTA.open(encoding="ascii") as source:
        for line_number, line in enumerate(source, 1):
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                finish_record()
                header = line[1:]
                if not header:
                    raise ValueError(f"{RAW_FASTA}:{line_number}: empty header")
                chunks = []
            elif header is None:
                raise ValueError(f"{RAW_FASTA}:{line_number}: sequence before header")
            else:
                chunks.append(line)
    finish_record()
    return selected, record_count


def atomic_text(path: Path, content: str) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    os.replace(temporary, path)


def main() -> None:
    args = arguments()
    entries = taxonomy_entries()
    eligible = [entry for entry in entries if entry["declared_length"] <= args.max_length]
    eligible.sort(key=lambda entry: (entry["declared_length"], entry["id"]))
    if len(eligible) < args.count:
        raise ValueError(f"only {len(eligible)} records satisfy the requested limits")
    if args.selection == "shortest":
        chosen = eligible[: args.count]
    elif args.count == 1:
        chosen = [eligible[0]]
    else:
        chosen = [
            eligible[index * (len(eligible) - 1) // (args.count - 1)]
            for index in range(args.count)
        ]

    sequences, source_record_count = selected_sequences(
        {str(entry["id"]) for entry in chosen}
    )
    if len(sequences) != len(chosen):
        missing = sorted({str(entry["id"]) for entry in chosen} - sequences.keys())
        raise ValueError(f"selected taxonomy identifiers missing from FASTA: {missing}")

    fasta_parts = []
    selected_manifest = []
    for entry in chosen:
        identifier = str(entry["id"])
        header, sequence = sequences[identifier]
        if len(sequence) != entry["declared_length"]:
            raise ValueError(
                f"length mismatch for {identifier}: taxonomy says "
                f"{entry['declared_length']}, FASTA has {len(sequence)}"
            )
        fasta_parts.append(f">{header}\n")
        fasta_parts.extend(sequence[offset : offset + 80] + "\n" for offset in range(0, len(sequence), 80))
        selected_manifest.append(
            {"id": identifier, "length": len(sequence), "header": header}
        )

    READY.mkdir(parents=True, exist_ok=True)
    stem = f"earlyvir_{args.selection}{args.count}"
    fasta_path = READY / f"{stem}.fasta"
    manifest_path = READY / f"{stem}.manifest.json"
    fasta_text = "".join(fasta_parts)
    atomic_text(fasta_path, fasta_text)

    manifest = {
        "source": "raw/all.curated.vOTUs.EarlyVir.fna",
        "taxonomy": "raw/taxtable.tsv",
        "selection": (
            "shortest declared length, then OTU identifier"
            if args.selection == "shortest"
            else "even positions in declared-length order, then OTU identifier"
        ),
        "maximum_length": args.max_length,
        "requested_records": args.count,
        "eligible_source_records": len(eligible),
        "source_records": source_record_count,
        "output": f"ready/{fasta_path.name}",
        "output_sha256": hashlib.sha256(fasta_text.encode("utf-8")).hexdigest(),
        "records": selected_manifest,
    }
    atomic_text(manifest_path, json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {fasta_path} ({len(chosen)} records)")
    print(f"wrote {manifest_path}")


if __name__ == "__main__":
    main()
