#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "cluster_graph"
VCLUST = ROOT.parent / ".tools/vclust-1.3.1/bin/vclust"
ALGORITHMS = ("single", "complete", "uclust", "cd-hit", "set-cover")

IDS = """id\tseq_len\tno_parts
a\t1000\t1
b\t990\t1
c\t980\t1
d\t970\t1
e\t960\t1
"""

HEADER = (
    "qidx\tridx\tquery\treference\ttani\tgani\tani\tqcov\trcov\t"
    "num_alns\tlen_ratio\tqlen\trlen\tnt_match\tnt_mismatch\n"
)


def row(a, b, score):
    names = "abcde"
    lengths = (1000, 990, 980, 970, 960)
    return (
        f"{a}\t{b}\t{names[a]}\t{names[b]}\t{score}\t{score}\t{score}\t"
        f"1\t1\t1\t{min(lengths[a], lengths[b]) / max(lengths[a], lengths[b])}\t"
        f"{lengths[a]}\t{lengths[b]}\t950\t50\n"
    )


ANI = HEADER + "".join(
    row(a, b, score)
    for a, b, score in (
        (0, 1, 0.99),
        (1, 2, 0.98),
        (0, 2, 0.97),
        (2, 3, 0.96),
    )
)


def membership(path):
    groups = {}
    rows = Path(path).read_text().splitlines()
    assert rows[0] == "object\tcluster"
    for line in rows[1:]:
        object_id, cluster = line.split("\t")
        groups.setdefault(cluster, set()).add(object_id)
    return {frozenset(group) for group in groups.values()}


class ClusterGraphTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not BINARY.is_file():
            subprocess.run(["make"], cwd=ROOT, check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cluster-c-test-")
        self.folder = Path(self.temp.name)
        self.ids = self.folder / "graph.ids.tsv"
        self.ani = self.folder / "graph.ani.tsv"
        self.ids.write_text(IDS)
        self.ani.write_text(ANI)

    def tearDown(self):
        self.temp.cleanup()

    def run_c(self, algorithm, threshold="0.95"):
        output = self.folder / f"c-{algorithm}.tsv"
        process = subprocess.run(
            [
                str(BINARY),
                "--input", str(self.ani),
                "--ids", str(self.ids),
                "--output", str(output),
                "--algorithm", algorithm,
                "--metric", "ani",
                "--threshold", threshold,
                "--threads", "4",
            ],
            text=True,
            capture_output=True,
            check=True,
        )
        self.assertIn("requested_threads=4 effective_threads=1", process.stderr)
        return output

    def test_expected_partitions(self):
        expected = {
            "single": {frozenset("abcd"), frozenset("e")},
            "complete": {frozenset("abc"), frozenset("d"), frozenset("e")},
            "uclust": {frozenset("abc"), frozenset("d"), frozenset("e")},
            "cd-hit": {frozenset("abc"), frozenset("d"), frozenset("e")},
            "set-cover": {frozenset("abcd"), frozenset("e")},
        }
        for algorithm in ALGORITHMS:
            with self.subTest(algorithm=algorithm):
                self.assertEqual(membership(self.run_c(algorithm)), expected[algorithm])

    def test_threshold_is_inclusive(self):
        output = self.run_c("single", threshold="0.99")
        self.assertEqual(
            membership(output),
            {frozenset("ab"), frozenset("c"), frozenset("d"), frozenset("e")},
        )

    def test_set_cover_uses_initial_degree_order(self):
        count = 11
        self.ids.write_text(
            "id\tseq_len\tno_parts\n"
            + "".join(f"n{i}\t{1000 - i}\t1\n" for i in range(count))
        )
        edges = (
            (0, 3), (0, 4), (0, 5), (0, 6), (0, 7),
            (1, 3), (1, 4), (1, 5), (1, 8),
            (2, 8), (2, 9), (2, 10),
        )
        rows = []
        for a, b in edges:
            rows.append(
                f"{a}\t{b}\tn{a}\tn{b}\t0.99\t0.99\t0.99\t1\t1\t1\t"
                f"0.99\t{1000 - a}\t{1000 - b}\t990\t10\n"
            )
        self.ani.write_text(HEADER + "".join(rows))
        self.assertEqual(
            membership(self.run_c("set-cover")),
            {
                frozenset(("n0", "n3", "n4", "n5", "n6", "n7")),
                frozenset(("n1", "n8")),
                frozenset(("n2", "n9", "n10")),
            },
        )

    @unittest.skipUnless(VCLUST.is_file(), "local Vclust is not installed")
    def test_first_five_match_vclust_on_fixture(self):
        for algorithm in ALGORITHMS:
            with self.subTest(algorithm=algorithm):
                c_output = self.run_c(algorithm)
                vclust_output = self.folder / f"vclust-{algorithm}.tsv"
                subprocess.run(
                    [
                        str(VCLUST), "cluster",
                        "-i", str(self.ani),
                        "--ids", str(self.ids),
                        "-o", str(vclust_output),
                        "--algorithm", algorithm,
                        "--metric", "ani",
                        "--ani", "0.95",
                        "-v", "0",
                    ],
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    env={**os.environ, "NO_COLOR": "1"},
                )
                self.assertEqual(membership(c_output), membership(vclust_output))


if __name__ == "__main__":
    unittest.main(verbosity=2)
