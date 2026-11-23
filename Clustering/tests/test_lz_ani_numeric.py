#!/usr/bin/env python3
"""Native-C/JS/proven-kernel regression tests for the numeric LZ-ANI port."""

import csv
import os
from pathlib import Path
import random
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
COMPILER = ROOT.parents[1] / "bend"
SOURCE = ROOT / "tests" / "lz_ani_numeric.bend"
INDEXED_SOURCE = ROOT / "tests" / "lz_ani_indexed.bend"
ALL_TO_ALL_SOURCE = ROOT / "lz_ani.bend"
REFERENCE = "TCTCACAGTTCAAGAACCCAAAGTACCCCCCATAGCCCTCCTAAAGCCACCTAAAGCCAG"
CASES = {
    "identical": (REFERENCE, "60\t0\t1\t10000\t10000\t10000"),
    "one_substitution":
        ("TCTCACAGTTCAAGAACCCAAAGTACCCCACATAGCCCTCCTAAAGCCACCTAAAGCCAG",
         "59\t1\t1\t9833\t9833\t10000"),
    "reverse_complement":
        ("CTGGCTTTAGGTGGCTTTAGGAGGGCTATGGGGGGTACTTTGGGTTCTTGAACTGTGAGA",
         "60\t0\t1\t10000\t10000\t10000"),
    "unrelated":
        ("GAGATGTCAAGTCTGATCGATGACCTGACTAGGTCATGCTAGCTACGATCGTACGTAGTC",
         "0\t0\t0\t0\t0\t0"),
    "deletion":
        ("TCTCACAGTTCAAGAACCCAAAGTACCCCCATAGCCCTCCTAAAGCCACCTAAAGCCAG",
         "59\t0\t1\t10000\t10000\t10000"),
    "insertion":
        ("TCTCACAGTTCAAGAACCCAAAGTACCCCCGCATAGCCCTCCTAAAGCCACCTAAAGCCAG",
         "61\t0\t1\t10000\t10000\t10000"),
    "two_substitutions":
        ("TCTCACAGTTCAAGAACCGAAAGTACCCCCCATAGCCCTCCTATAGCCACCTAAAGCCAG",
         "58\t2\t1\t9666\t9666\t10000"),
    "five_base_block":
        ("TCTCACAGTTCAAGAACCCAAAGTGGGTTCCATAGCCCTCCTAAAGCCACCTAAAGCCAG",
         "55\t5\t1\t9166\t9166\t10000"),
}
OFFICIAL = (ROOT / ".tools" / "vclust-1.3.1" / "lib" / "python3.14" /
            "site-packages" / "bin" / "lz-ani")


class LzAniNumericTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="bend-lz-ani-")
        cls.folder = Path(cls.temporary.name)
        cls.c_source = cls.folder / "lz_ani_numeric.c"
        cls.js_source = cls.folder / "lz_ani_numeric.js"
        cls.executable = cls.folder / "lz_ani_numeric"
        cls.indexed_c_source = cls.folder / "lz_ani_indexed.c"
        cls.indexed_js_source = cls.folder / "lz_ani_indexed.js"
        cls.indexed_executable = cls.folder / "lz_ani_indexed"
        cls.all_c_source = cls.folder / "lz_ani_all.c"
        cls.all_js_source = cls.folder / "lz_ani_all.js"
        cls.all_executable = cls.folder / "lz_ani_all"
        for source, output in (
                (SOURCE, cls.c_source), (SOURCE, cls.js_source),
                (INDEXED_SOURCE, cls.indexed_c_source),
                (INDEXED_SOURCE, cls.indexed_js_source),
                (ALL_TO_ALL_SOURCE, cls.all_c_source),
                (ALL_TO_ALL_SOURCE, cls.all_js_source)):
            subprocess.run(
                ["bun", "bend2/main.ts", str(source), "-o", str(output)],
                cwd=COMPILER, check=True, capture_output=True, text=True)
        for source, executable in ((cls.c_source, cls.executable),
                                   (cls.indexed_c_source,
                                    cls.indexed_executable),
                                   (cls.all_c_source, cls.all_executable)):
            subprocess.run(
                ["clang", "-O2", "-std=c11", "-lpthread", "-lm",
                 str(source), "-o", str(executable)],
                check=True, capture_output=True, text=True)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def run_case(self, command, query):
        environment = dict(os.environ, LZ_REFERENCE=REFERENCE, LZ_QUERY=query)
        process = subprocess.run(command, env=environment, capture_output=True,
                                 text=True, timeout=20)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(process.stderr, "")
        return process.stdout.strip()

    def test_native_c_and_javascript_match_official_fixture(self):
        for name, (query, expected) in CASES.items():
            with self.subTest(name=name):
                native = self.run_case(
                    [str(self.executable), "--threads", "1", "--gpu", "off"],
                    query)
                javascript = self.run_case(["bun", str(self.js_source)], query)
                indexed_native = self.run_case(
                    [str(self.indexed_executable), "--threads", "1", "--gpu",
                     "off"], query)
                indexed_javascript = self.run_case(
                    ["bun", str(self.indexed_js_source)], query)
                self.assertEqual(native, expected)
                self.assertEqual(javascript, expected)
                self.assertEqual(indexed_native, expected)
                self.assertEqual(indexed_javascript, expected)

    def assert_all_to_all_matches_official(self, fixture, stem):
        output = self.folder / f"{stem}.official.tsv"
        ids = self.folder / f"{stem}.official.ids.tsv"
        process = subprocess.run(
            [str(OFFICIAL), "all2all", "--in-fasta",
             str(fixture),
             "--out", str(output), "--out-ids", str(ids),
             "--out-format", "complete", "-t", "1", "-V", "1"],
            capture_output=True, text=True, timeout=20)
        self.assertEqual(process.returncode, 0, process.stderr)
        with output.open(newline="") as handle:
            official = {(row["query"], row["reference"]): row
                        for row in csv.DictReader(handle, delimiter="\t")}

        names = [line[1:].split()[0] for line in fixture.read_text().splitlines()
                 if line.startswith(">")]
        self.assertEqual(len(official), len(names) * (len(names) - 1))

        environment = dict(os.environ, CLUSTER_INPUT=str(fixture))
        for backend, command in (
                ("native-c", [str(self.all_executable), "--threads", "1",
                              "--gpu", "off"]),
                ("javascript", ["bun", str(self.all_js_source)])):
            process = subprocess.run(command, env=environment,
                                     capture_output=True, text=True,
                                     timeout=20)
            self.assertEqual(process.returncode, 0, process.stderr)
            rows = list(csv.DictReader(process.stdout.splitlines(),
                                       delimiter="\t"))
            self.assertEqual(len(rows), len(official), backend)
            for row in rows:
                key = (names[int(row["qidx"])], names[int(row["ridx"])])
                expected = official[key]
                with self.subTest(backend=backend, query=key[0], reference=key[1]):
                    self.assertEqual(row["nt_match"], expected["nt_match"])
                    self.assertEqual(row["nt_mismatch"],
                                     expected["nt_mismatch"])
                    self.assertEqual(row["num_alns"], expected["num_alns"])

    @unittest.skipUnless(OFFICIAL.is_file(), "official LZ-ANI binary not installed")
    def test_all_directed_pairs_against_official_lz_ani(self):
        fixture = ROOT / "tests" / "fixtures" / "lz_ani_numeric.fasta"
        self.assert_all_to_all_matches_official(fixture, "focused")

        rng = random.Random(20261029)
        base = "".join(rng.choice("ACGT") for _ in range(180))
        sequences = [("base", base), ("identical", base)]
        for count in (1, 3, 7, 15):
            changed = list(base)
            for position in rng.sample(range(len(changed)), count):
                changed[position] = rng.choice(
                    [nucleotide for nucleotide in "ACGT"
                     if nucleotide != changed[position]])
            sequences.append((f"sub_{count}", "".join(changed)))
        for number, count in enumerate((1, 4, 11)):
            position = 35 + number * 40
            sequences.append((f"del_{count}",
                              base[:position] + base[position + count:]))
            inserted = "".join(rng.choice("ACGT") for _ in range(count))
            sequences.append((f"ins_{count}",
                              base[:position] + inserted + base[position:]))
        sequences.append(("reverse",
                          base.translate(str.maketrans("ACGT", "TGCA"))[::-1]))
        for number in range(4):
            sequences.append((f"random_{number}", "".join(
                rng.choice("ACGT") for _ in range(150 + number * 13))))

        generated = self.folder / "generated.fasta"
        generated.write_text("".join(f">{name}\n{sequence}\n"
                                     for name, sequence in sequences))
        self.assert_all_to_all_matches_official(generated, "generated")

    def test_proven_kernel(self):
        process = subprocess.run(
            ["bun", "bend2/main.ts", str(SOURCE), "--verdict"],
            cwd=COMPILER, capture_output=True, text=True, timeout=20)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertIn("ALL PROOFS CHECK", process.stdout)


if __name__ == "__main__":
    unittest.main()
