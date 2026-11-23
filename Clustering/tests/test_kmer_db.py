#!/usr/bin/env python3
"""Differential tests for the Bend canonical 25-mer sparse prefilter."""

import csv
import os
from pathlib import Path
import random
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
import importlib.util
spec = importlib.util.spec_from_file_location("launcher", ROOT / "run.py")
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)
COMPILER = launcher.default_compiler()
BEND = launcher.compiler_command(COMPILER)
SOURCE = ROOT / "tests" / "kmer_db.bend"
KERNEL = ROOT / "lib" / "kmer_score.bend"
OFFICIAL = (ROOT / ".tools" / "vclust-1.3.1" / "lib" / "python3.14" /
            "site-packages" / "bin" / "kmer-db")


class KmerDbTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="bend-kmer-db-")
        cls.folder = Path(cls.temporary.name)
        cls.c_source = cls.folder / "kmer_db.c"
        cls.js_source = cls.folder / "kmer_db.js"
        cls.executable = cls.folder / "kmer_db"
        for output in (cls.c_source, cls.js_source):
            subprocess.run(
                [*BEND, str(SOURCE), "-o", str(output)],
                check=True, capture_output=True, text=True)
        subprocess.run(
            ["clang", "-O2", "-std=c11", "-lpthread", "-lm",
             str(cls.c_source), "-o", str(cls.executable)],
            check=True, capture_output=True, text=True)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def run_bend(self, command, fixture):
        process = subprocess.run(
            command, env=dict(os.environ, CLUSTER_INPUT=str(fixture)),
            capture_output=True, text=True, timeout=30)
        self.assertEqual(process.returncode, 0, process.stderr)
        rows = csv.DictReader(process.stdout.splitlines(), delimiter="\t")
        return {(int(row["left"]), int(row["right"])):
                int(row["common_kmers"]) for row in rows
                if int(row["left"]) < int(row["right"])}

    def run_official(self, fixture):
        database = self.folder / "fixture.kdb"
        common = self.folder / "fixture.common"
        subprocess.run(
            [str(OFFICIAL), "build", "-multisample-fasta", "-k", "25",
             "-f", "1", "-t", "1", str(fixture), str(database)],
            check=True, capture_output=True, text=True, timeout=30)
        subprocess.run(
            [str(OFFICIAL), "all2all-sp", "-sparse", "-min",
             "num-kmers:20", "-min", "ani-shorter:0.7", "-t", "1",
             str(database), str(common)],
            check=True, capture_output=True, text=True, timeout=30)
        lines = common.read_text().splitlines()
        expected = {}
        for query, line in enumerate(lines[2:]):
            fields = line.split(",")
            for entry in fields[2:]:
                if not entry:
                    continue
                reference, count = entry.split(":")
                left = int(reference) - 1
                expected[min(left, query), max(left, query)] = int(count)
        return expected

    @unittest.skipUnless(OFFICIAL.is_file(), "official Kmer-db binary not installed")
    def test_native_and_javascript_match_kmer_db_2_3_1(self):
        rng = random.Random(20261029)
        base = "".join(rng.choice("ACGT") for _ in range(220))
        changed = list(base)
        for position in (17, 89, 173):
            changed[position] = rng.choice(
                [nucleotide for nucleotide in "ACGT"
                 if nucleotide != changed[position]])
        sequences = [
            ("base", base),
            ("identical", base),
            ("reverse", base.translate(str.maketrans("ACGT", "TGCA"))[::-1]),
            ("substitutions", "".join(changed)),
            ("ambiguous_gap", base[:105] + "NNNNN" + base[110:]),
            ("unrelated", "".join(rng.choice("ACGT") for _ in range(220))),
            ("repetitive", "ACGT" * 55),
        ]
        fixture = self.folder / "fixture.fasta"
        fixture.write_text("".join(f">{name}\n{sequence}\n"
                                   for name, sequence in sequences))
        expected = self.run_official(fixture)
        native = self.run_bend(
            [str(self.executable), "--threads", "1", "--gpu", "off"],
            fixture)
        javascript = self.run_bend(["bun", str(self.js_source)], fixture)
        self.assertEqual(native, expected)
        self.assertEqual(javascript, expected)

    def test_sparse_omission_law_is_proven(self):
        process = subprocess.run(
            [*BEND, str(KERNEL), "--verdict"],
            capture_output=True, text=True, timeout=30)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertIn("ALL PROOFS CHECK", process.stdout)


if __name__ == "__main__":
    unittest.main()
