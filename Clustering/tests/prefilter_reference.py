#!/usr/bin/env python3
"""Independent counter oracle for the Bend global-identity prefilter."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path


def fasta_sequences(path: Path) -> list[str]:
    sequences: list[str] = []
    chunks: list[str] = []
    seen_header = False
    with path.open(encoding="ascii") as source:
        for raw_line in source:
            line = raw_line.strip()
            if not line or line.startswith(";"):
                continue
            if line.startswith(">"):
                if seen_header:
                    sequences.append("".join(chunks).upper().replace("U", "T"))
                seen_header = True
                chunks = []
            else:
                if not seen_header:
                    raise ValueError("sequence before first FASTA header")
                chunks.append("".join(line.split()))
    if seen_header:
        sequences.append("".join(chunks).upper().replace("U", "T"))
    return sequences


def word_counts(sequence: str) -> Counter[int]:
    counts: Counter[int] = Counter()
    codes = {base: code for code, base in enumerate("ACGTRYSWKMBDHVN")}
    rolling = 0
    for seen, base in enumerate(sequence):
        rolling = (rolling * 16 + codes[base]) % 4096
        if seen >= 2:
            counts[(rolling ^ (rolling >> 8)) & 255] += 1
    return counts


def hash30(word: int) -> int:
    value = word ^ (word >> 16)
    value = value * 2146121005 & 0xFFFFFFFF
    value ^= value >> 15
    value = value * 2221713035 & 0xFFFFFFFF
    return (value ^ (value >> 16)) & 0xFFFFFFFF


def sketch(sequence: str) -> list[int]:
    codes = {base: code for code, base in enumerate("ACGTRYSWKMBDHVN")}
    values = [0xFFFFFFFF] * 64
    rolling = 0
    for seen, base in enumerate(sequence):
        rolling = ((rolling << 2) | (codes[base] & 3)) & 0x3FFFFFFF
        if seen >= 14:
            value = hash30(rolling)
            bin_index = value & 63
            values[bin_index] = min(values[bin_index], value >> 6)
    return values


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fasta", type=Path)
    parser.add_argument("--identity", type=int, default=9500,
                        help="identity in basis points")
    args = parser.parse_args()
    if not 1 <= args.identity <= 10000:
        parser.error("--identity must be in 1..10000")

    sequences = fasta_sequences(args.fasta)
    lengths = [len(sequence) for sequence in sequences]
    words = [word_counts(sequence) for sequence in sequences]
    sketches = [sketch(sequence) for sequence in sequences]
    pairs = length_rejected = word_rejected = candidates = 0
    sketch_counts = {cutoff: 0 for cutoff in (1, 2, 4, 8, 12, 16, 24, 32)}
    for left in range(len(sequences)):
        for right in range(left + 1, len(sequences)):
            pairs += 1
            longer = max(lengths[left], lengths[right])
            shorter = min(lengths[left], lengths[right])
            required_matches = (args.identity * longer + 9999) // 10000
            if required_matches > shorter:
                length_rejected += 1
                continue
            interruptions = lengths[left] + lengths[right] - 2 * required_matches
            required_words = max(0, required_matches - 2 * (interruptions + 1))
            common = sum(min(count, words[right].get(word, 0))
                         for word, count in words[left].items())
            if required_words == 0 or common >= required_words:
                candidates += 1
                matches = sum(a == b and a != 0xFFFFFFFF
                              for a, b in zip(sketches[left], sketches[right]))
                for cutoff in sketch_counts:
                    sketch_counts[cutoff] += matches >= cutoff
            else:
                word_rejected += 1

    print(f"records\t{len(sequences)}")
    print(f"pairs\t{pairs}")
    print(f"length_rejected\t{length_rejected}")
    print(f"word_rejected\t{word_rejected}")
    print(f"candidates\t{candidates}")
    for cutoff, count in sketch_counts.items():
        print(f"sketch{cutoff}\t{count}")


if __name__ == "__main__":
    main()
