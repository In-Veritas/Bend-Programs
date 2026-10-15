#!/usr/bin/env python3
"""Independent algorithm oracles and end-to-end JS/native-C regression tests."""

import csv
import functools
import importlib.util
import io
import os
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor

os.environ["BEND_NO_TELEMETRY"] = "1"
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("launcher", ROOT / "run.py")
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)
COMPILER = Path(os.environ.get("BEND_CORE", ROOT.parent.parent / "bend2-core"))
ALGORITHMS = tuple(launcher.ALGORITHMS)


@functools.lru_cache(maxsize=None)
def alignment(left, right):
    # Each entry is (edit cost, negative match count). Lexicographic minimization
    # independently specifies the alignment tie break used by the Bend programs.
    row = [(j, 0) for j in range(len(right) + 1)]
    for i, a in enumerate(left, 1):
        following = [(i, 0)]
        for j, b in enumerate(right, 1):
            cost, matches = row[j - 1]
            diagonal = cost + (a != b), matches - (a == b)
            delete = row[j][0] + 1, row[j][1]
            insert = following[j - 1][0] + 1, following[j - 1][1]
            following.append(min(diagonal, delete, insert))
        row = following
    cost, negative_matches = row[-1]
    return cost, -negative_matches


def reverse_complement(text):
    return text.translate(str.maketrans("ACGTRYSWKMBDHVN", "TGCAYRSWMKVHDBN"))[::-1]


def similarity(left, right, shorter=False, reverse=False):
    def one(a, b):
        cost, matches = alignment(a, b)
        denominator = min(len(a), len(b)) if shorter else cost + matches
        return matches * 10000 // denominator
    forward = one(left, right)
    return max(forward, one(left, reverse_complement(right))) if reverse else forward


def reference(sequences, algorithm, threshold, reverse=False):
    n = len(sequences)
    scores = [[similarity(a, b, algorithm == "cd-hit", reverse)
               for b in sequences] for a in sequences]
    if algorithm in ("uclust", "cd-hit"):
        centers = []
        labels = [None] * n
        for index in sorted(range(n), key=lambda x: (-len(sequences[x]), x)):
            candidates = [c for c in centers if scores[index][c] >= threshold]
            if not candidates:
                centers.append(index)
                labels[index] = index
            elif algorithm == "cd-hit":
                labels[index] = candidates[0]
            else:
                labels[index] = min(candidates, key=lambda c: (-scores[index][c], c))
        return labels
    clusters = {i: {i} for i in range(n)}
    if algorithm in ("single-linkage", "complete-linkage"):
        while len(clusters) > 1:
            choices = []
            for a in sorted(clusters):
                for b in sorted(clusters):
                    if a < b:
                        pairs = [scores[i][j] for i in clusters[a] for j in clusters[b]]
                        score = max(pairs) if algorithm == "single-linkage" else min(pairs)
                        choices.append((-score, a, b))
            negative, a, b = min(choices)
            if -negative < threshold:
                break
            clusters[a].update(clusters.pop(b))
        labels = [None] * n
        for center, members in clusters.items():
            for member in members:
                labels[member] = center
        return labels
    uncovered = set(range(n))
    labels = [None] * n
    while uncovered:
        center = min(uncovered, key=lambda i: (
            -sum(scores[i][j] >= threshold for j in uncovered), i))
        covered = {j for j in uncovered if scores[center][j] >= threshold}
        for j in covered:
            labels[j] = center
        uncovered -= covered
    return labels


def read_table(text):
    rows = list(csv.DictReader(io.StringIO(text), delimiter="\t"))
    for index, row in enumerate(rows):
        if int(row["record_index"]) != index:
            raise AssertionError("records were reordered or omitted")
    return [int(row["cluster_representative"]) for row in rows], rows


def connected_partition(labels, scores, threshold):
    for center in set(labels):
        members = {i for i, label in enumerate(labels) if label == center}
        reached = {next(iter(members))}
        while True:
            added = {j for i in reached for j in members if scores[i][j] >= threshold}
            if added <= reached:
                break
            reached |= added
        if reached != members:
            return False
    return True


class ClusteringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="bend-clustering-tests-")
        cls.folder = Path(cls.temporary.name)
        cls.commands = {}
        jobs = [(algorithm, backend) for algorithm in ALGORITHMS for backend in ("c", "js")]
        def compile_one(job):
            algorithm, backend = job
            return job, launcher.build(algorithm, backend, COMPILER)
        with ThreadPoolExecutor(max_workers=3) as pool:
            for job, command in pool.map(compile_one, jobs):
                cls.commands[job] = command
        cls.graph_commands = {}
        for backend in ("c", "js"):
            emitted = cls.folder / f"graph.{backend}"
            subprocess.run(["bun", str(COMPILER / "bend2/main.ts"),
                            str(ROOT / "tests/leiden_graph.bend"), "-o", str(emitted)],
                           check=True)
            if backend == "c":
                executable = cls.folder / "graph"
                subprocess.run(["clang", "-O2", "-std=c11", "-lpthread", "-lm",
                                str(emitted), "-o", str(executable)], check=True)
                cls.graph_commands[backend] = [str(executable), "--threads", "1", "--gpu", "off"]
            else:
                cls.graph_commands[backend] = ["bun", str(emitted)]

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def run_program(self, algorithm, fasta, backend="c", threshold=9000,
                    reverse=False, seed=1, resolution=5000, passes=100, **settings):
        path = self.folder / "input.fasta"
        path.write_bytes(fasta if isinstance(fasta, bytes) else fasta.encode())
        env = dict(os.environ, CLUSTER_INPUT=str(path), CLUSTER_DNA="1",
                   CLUSTER_IDENTITY=str(threshold), CLUSTER_REVERSE=str(int(reverse)),
                   CLUSTER_SEED=str(seed), CLUSTER_RESOLUTION=str(resolution),
                   CLUSTER_PASSES=str(passes), CLUSTER_REPRESENTATIVES="")
        env.update(settings)
        return subprocess.run(self.commands[algorithm, backend], env=env,
                              capture_output=True, text=True, timeout=45)

    def assert_success(self, process):
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(process.stderr, "")
        return read_table(process.stdout)[0]

    def check_fixture(self, sequences, threshold=9000, reverse=False):
        fasta = "".join(f">record_{i}\n{s}\n" for i, s in enumerate(sequences))
        scores = [[similarity(a, b, reverse=reverse) for b in sequences] for a in sequences]
        for algorithm in ALGORITHMS:
            with self.subTest(algorithm=algorithm, sequences=sequences,
                              threshold=threshold, reverse=reverse):
                c = self.run_program(algorithm, fasta, threshold=threshold, reverse=reverse)
                js = self.run_program(algorithm, fasta, "js", threshold, reverse)
                labels = self.assert_success(c)
                self.assert_success(js)
                self.assertEqual(c.stdout, js.stdout)
                self.assertEqual(len(labels), len(sequences))
                self.assertTrue(all(0 <= x < len(sequences) for x in labels))
                self.assertTrue(all(labels[x] == x for x in labels))
                if algorithm != "leiden":
                    self.assertEqual(labels, reference(sequences, algorithm, threshold, reverse))
                else:
                    self.assertTrue(connected_partition(labels, scores, threshold))
                    quality = sum((10000 if scores[i][j] >= threshold else 0) - 5000
                                  for i in range(len(labels)) for j in range(i)
                                  if labels[i] == labels[j])
                    self.assertGreaterEqual(quality, 0)

    def test_chain_distinguishes_algorithms(self):
        self.check_fixture(["AAAA", "AAAT", "AATT", "GGGG"], 7500)
        cover = self.run_program("set-cover", ">a\nAAAA\n>b\nAAAT\n>c\nAATT\n", threshold=7500)
        self.assertEqual(self.assert_success(cover), [1, 1, 1])

    def test_centroid_modes_and_fragments(self):
        self.check_fixture(["AAAAAA", "CCCAAA", "CCAAAA"], 6500)
        self.check_fixture(["ACGTACGT", "GTAC", "GTTC", "TTTTTTTT"], 10000)
        self.check_fixture(["ACGTACGT", "GTAC", "GTTC", "TTTTTTTT"], 7500)

    def test_empty_singleton_duplicates(self):
        self.check_fixture([])
        self.check_fixture(["ACGT"])
        self.check_fixture(["ACGT"] * 7, 10000)
        self.check_fixture(["A", "C", "G", "T"], 1)

    def test_reverse_complement_and_iupac(self):
        for reverse in (False, True):
            self.check_fixture(["AAAC", "GTTT", "AAAG", "GAAA"], 10000, reverse)
            self.check_fixture(["ARYKMBDHVSWN", "NWSBDHVKMRYT"], 10000, reverse)
        self.check_fixture(["NNNN", "AAAA", "NNNA"], 7500)

    def test_rna_case_crlf_comments_and_duplicate_headers(self):
        fasta = b"; comment\r\n\r\n>same\tdescription\r\n acg u\r\nAC\r\n>same\r\nACGTAC"
        for algorithm in ALGORITHMS:
            for backend in ("c", "js"):
                process = self.run_program(algorithm, fasta, backend, threshold=10000)
                self.assertEqual(self.assert_success(process), [0, 0])
                rows = read_table(process.stdout)[1]
                self.assertEqual([r["length"] for r in rows], ["6", "6"])
                self.assertEqual(rows[0]["header"], "same description")

    def test_randomized_reference_comparison(self):
        rng = random.Random(4257)
        for fixture in range(24):
            sequences = []
            ancestor = "".join(rng.choices("ACGT", k=rng.randrange(4, 11)))
            for i in range(rng.randrange(2, 9)):
                value = list(ancestor)
                for _ in range(rng.randrange(4)):
                    if value:
                        value[rng.randrange(len(value))] = rng.choice("ACGT")
                if rng.random() < .25:
                    value.insert(rng.randrange(len(value) + 1), rng.choice("ACGT"))
                if rng.random() < .25 and len(value) > 1:
                    value.pop(rng.randrange(len(value)))
                sequences.append("".join(value))
            self.check_fixture(sequences, rng.choice([5000, 6666, 7500, 9000, 10000]),
                               bool(fixture % 3 == 0))

    def test_short_word_filter_repetitions_and_indels(self):
        rng = random.Random(548)
        for _ in range(8):
            a = "".join(rng.choices("ACGT", k=45))
            b = a[:12] + "A" + a[12:28] + a[29:]
            self.check_fixture([a, b, reverse_complement(a), "A" * 45, "A" * 44], 9000, True)

    def test_invalid_inputs_and_settings(self):
        bad = ["ACGT\n", ">\nACGT\n", ">a\n>b\nACGT\n", ">a\n",
               ">a\nAC-GT\n", ">a\n123\n", ">a\nAC?T\n", ">a\nMEEP\n",
               b">a\x00\nACGT\n", ">a\n" + "A" * 30001]
        for backend in ("c", "js"):
            for fasta in bad:
                process = self.run_program("uclust", fasta, backend)
                self.assertNotEqual(process.returncode, 0, repr(fasta[:40]))
                self.assertEqual(process.stdout, "")
                self.assertIn("FASTA", process.stderr)
            for setting in ("", "0", "10001", "-1", "90x", "42949672960"):
                process = self.run_program("uclust", ">a\nACGT\n", backend,
                                           CLUSTER_IDENTITY=setting)
                self.assertNotEqual(process.returncode, 0, setting)
                self.assertEqual(process.stdout, "")

    def test_record_limit(self):
        fasta = ">a\nA\n" * 2049
        for backend in ("c", "js"):
            process = self.run_program("uclust", fasta, backend)
            self.assertNotEqual(process.returncode, 0)
            self.assertIn("2048-record", process.stderr)

    def test_chunk_boundary(self):
        # Several records cross the 64 KiB file-read boundary without quadratic DP.
        fasta = ">a " + "x" * 66000 + "\nACGT\n>b\nACGT\n"
        for backend in ("c", "js"):
            process = self.run_program("uclust", fasta, backend)
            self.assertEqual(self.assert_success(process), [0, 0])

    def test_supported_input_boundaries(self):
        for backend in ("c", "js"):
            process = self.run_program("uclust", ">long\n" + "ACGT" * 7500, backend)
            self.assertEqual(self.assert_success(process), [0])
            process = self.run_program("uclust", ">duplicate\nA\n" * 2048, backend)
            self.assertEqual(self.assert_success(process), [0] * 2048)

    def test_leiden_seed_resolution_and_pass_failure(self):
        fasta = ">a\nAAAA\n>b\nAAAT\n>c\nAATT\n>d\nATTT\n>e\nTTTT\n"
        for seed in (0, 1, 42, 4294967295):
            for resolution in (1, 2500, 5000, 10000):
                c = self.run_program("leiden", fasta, threshold=7500, seed=seed,
                                     resolution=resolution)
                js = self.run_program("leiden", fasta, "js", 7500, seed=seed,
                                      resolution=resolution)
                self.assert_success(c)
                self.assert_success(js)
                self.assertEqual(c.stdout, js.stdout)
                if resolution == 10000:
                    self.assertEqual(read_table(c.stdout)[0], list(range(5)))
        process = self.run_program("leiden", ">a\nAAAA\n>b\nAAAA\n", passes=1)
        self.assertNotEqual(process.returncode, 0)
        self.assertIn("CLUSTER_PASSES", process.stderr)
        self.assertEqual(process.stdout, "")

    def test_representatives_and_launcher_atomicity(self):
        path = self.folder / "source with spaces.FASTA"
        path.write_text(">one long\n" + "acgu" * 25 + "\n>two\n" + "ACGT" * 25 + "\n")
        table = self.folder / "clusters.tsv"
        reps = self.folder / "representatives.fasta"
        command = [sys.executable, str(ROOT / "run.py"), "uclust", str(path),
                   "--compiler", str(COMPILER), "--identity", "1",
                   "--output", str(table), "--representatives", str(reps)]
        process = subprocess.run(command, capture_output=True, text=True, timeout=60)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(read_table(table.read_text())[0], [0, 0])
        self.assertEqual(reps.read_text(), ">one long\n" + "ACGT" * 20 + "\n" + "ACGT" * 5 + "\n")
        path.write_text("invalid\n")
        before = table.read_bytes(), reps.read_bytes()
        process = subprocess.run(command, capture_output=True, text=True, timeout=60)
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual((table.read_bytes(), reps.read_bytes()), before)
        process = subprocess.run([sys.executable, str(ROOT / "run.py"), "uclust",
                                  str(path), "--output", str(path)],
                                 capture_output=True, text=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertIn("different files", process.stderr)

    def test_interpreter_entry_and_missing_file(self):
        source = ROOT / "single_linkage.bend"
        path = self.folder / "direct.fasta"
        path.write_text(">a\nACGT\n>b\nACGT\n")
        env = dict(os.environ, CLUSTER_INPUT=str(path), CLUSTER_DNA="1",
                   CLUSTER_REPRESENTATIVES="", CLUSTER_IDENTITY="9000")
        direct = subprocess.run(["bun", str(COMPILER / "bend2/main.ts"), str(source)],
                                env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(self.assert_success(direct), [0, 0])
        missing = self.run_program("single-linkage", "", CLUSTER_INPUT="/missing/file.fasta")
        self.assertNotEqual(missing.returncode, 0)

    def run_launcher(self, algorithm, source, *options, backend="c"):
        return subprocess.run(
            [sys.executable, str(ROOT / "run.py"), algorithm, str(source),
             "--compiler", str(COMPILER), "--backend", backend, *map(str, options)],
            capture_output=True, text=True, timeout=60)

    def test_folder_independent_files_all_algorithms_and_backends(self):
        with tempfile.TemporaryDirectory(dir=self.folder) as folder:
            source = Path(folder) / "input folder"
            source.mkdir()
            # Same basename, repeated identifiers, and shared sequences must
            # neither merge datasets nor overwrite one another's output.
            (source / "sample.fa").write_bytes(b">same\r\nacgu\r\n>other\r\nACGT")
            (source / "sample.FASTA").write_text(">same\nACGT\n>other\nAAAA\n")
            (source / "empty.fna").write_text("")
            (source / "notes.txt").write_text("not FASTA")
            for algorithm in ALGORITHMS:
                snapshots = []
                for backend in ("c", "js"):
                    out = Path(folder) / algorithm / backend
                    process = self.run_launcher(algorithm, source, "--identity", "1",
                                                "--output-dir", out, backend=backend)
                    self.assertEqual(process.returncode, 0, process.stderr)
                    self.assertEqual(process.stdout, "")
                    self.assertIn("3 FASTA files independently", process.stderr)
                    expected = {
                        "sample.fa": ([0, 0], ">same\nACGT\n"),
                        "sample.FASTA": ([0, 1], ">same\nACGT\n>other\nAAAA\n"),
                        "empty.fna": ([], ""),
                    }
                    for name, (labels, representatives) in expected.items():
                        self.assertEqual(read_table((out / (name + ".clusters.tsv")).read_text())[0],
                                         labels)
                        self.assertEqual((out / (name + ".representatives.fasta")).read_text(),
                                         representatives)
                    snapshots.append({p.name: p.read_bytes() for p in out.iterdir()})
                self.assertEqual(snapshots[0], snapshots[1])

    def test_folder_recursion_and_repeat_runs(self):
        with tempfile.TemporaryDirectory(dir=self.folder) as folder:
            source = Path(folder)
            nested = source / "nested"
            nested.mkdir()
            (source / "sample.fna").write_text(">one\nA\n")
            (nested / "sample.fna").write_text(">two\nC\n")
            for recursive, count in ((False, 1), (True, 2), (True, 2)):
                process = self.run_launcher("uclust", source, *(["--recursive"] if recursive else []))
                self.assertEqual(process.returncode, 0, process.stderr)
                self.assertIn(f"{count} FASTA files independently", process.stderr)
            out = source / "clusters" / "uclust"
            self.assertEqual((out / "sample.fna.representatives.fasta").read_text(), ">one\nA\n")
            self.assertEqual((out / "nested/sample.fna.representatives.fasta").read_text(), ">two\nC\n")
            # A different algorithm's generated FASTA must not become input.
            process = self.run_launcher("single-linkage", source, "--recursive")
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertIn("2 FASTA files independently", process.stderr)

    def test_representative_payload_matches_algorithm_labels(self):
        fixtures = [(["AAAA", "AAAT", "AATT", "GGGG"], 7500),
                    (["ACGT", "ACGTACGT", "ACGTACGA", "TTTTTTTT"], 7500)]
        for sequences, threshold in fixtures:
            fasta = "".join(f">record_{i}\n{s.lower()}\n" for i, s in enumerate(sequences))
            for algorithm in ALGORITHMS:
                for backend in ("c", "js"):
                    with self.subTest(algorithm=algorithm, backend=backend, sequences=sequences):
                        reps = self.folder / "chosen-representatives.fasta"
                        process = self.run_program(algorithm, fasta, backend, threshold,
                                                   CLUSTER_REPRESENTATIVES=str(reps))
                        labels = self.assert_success(process)
                        if algorithm != "leiden":
                            self.assertEqual(labels, reference(sequences, algorithm, threshold))
                        expected = "".join(f">record_{i}\n{sequences[i]}\n"
                                           for i in sorted(set(labels)))
                        self.assertEqual(reps.read_text(), expected)

    def test_folder_failure_preserves_all_outputs(self):
        with tempfile.TemporaryDirectory(dir=self.folder) as folder:
            source = Path(folder) / "inputs"
            source.mkdir()
            (source / "a.fasta").write_text(">good\nACGT")
            (source / "b.fasta").write_text("ACGT\n")
            for backend in ("c", "js"):
                out = Path(folder) / backend
                out.mkdir()
                before = {}
                for name in ("a.fasta", "b.fasta"):
                    for suffix in (".clusters.tsv", ".representatives.fasta"):
                        p = out / (name + suffix)
                        p.write_text("existing output\n")
                        before[p.name] = p.read_bytes()
                process = self.run_launcher("uclust", source, "--output-dir", out, backend=backend)
                self.assertNotEqual(process.returncode, 0)
                self.assertIn("b.fasta", process.stderr)
                self.assertIn("FASTA line 1", process.stderr)
                self.assertEqual({p.name: p.read_bytes() for p in out.iterdir()}, before)

    def test_folder_validation_and_output_aliases(self):
        with tempfile.TemporaryDirectory(dir=self.folder) as folder:
            source = Path(folder) / "inputs"
            source.mkdir()
            process = self.run_launcher("uclust", source)
            self.assertNotEqual(process.returncode, 0)
            self.assertIn("no FASTA files", process.stderr)
            fasta = source / "a.fasta"
            fasta.write_text(">one\nA\n")
            for options in (("--output", Path(folder) / "table.tsv"),
                            ("--representatives", Path(folder) / "reps.fa"),
                            ("--output-dir", source),
                            ("--output-dir", source.parent)):
                process = self.run_launcher("uclust", source, *options)
                self.assertNotEqual(process.returncode, 0)
            out = Path(folder) / "out"
            out.mkdir()
            alias = out / "a.fasta.representatives.fasta"
            os.link(fasta, alias)
            process = self.run_launcher("uclust", source, "--output-dir", out)
            self.assertNotEqual(process.returncode, 0)
            self.assertIn("different files", process.stderr)
            self.assertEqual(fasta.read_text(), ">one\nA\n")
            for options in (("--recursive",), ("--output-dir", out)):
                process = self.run_launcher("uclust", fasta, *options)
                self.assertNotEqual(process.returncode, 0)

    def test_folder_limits_apply_per_file(self):
        with tempfile.TemporaryDirectory(dir=self.folder) as folder:
            source = Path(folder)
            # Sparse files exercise discovery limits without expensive parsing.
            for name in ("a.fasta", "b.fasta"):
                with (source / name).open("wb") as file:
                    file.truncate(launcher.MAX_INPUT_BYTES)
            self.assertEqual(len(launcher.input_files(source)), 2)
            with (source / "b.fasta").open("wb") as file:
                file.truncate(launcher.MAX_INPUT_BYTES + 1)
            process = self.run_launcher("uclust", source)
            self.assertNotEqual(process.returncode, 0)
            self.assertIn("64 MiB", process.stderr)
            self.assertIn("b.fasta", process.stderr)

    def graph_run(self, graph, backend, seed=1, resolution=5000, **settings):
        env = dict(os.environ, GRAPH_SIZE=str(len(graph)), GRAPH_MODE="cluster",
                   GRAPH_EDGES="".join(str(x) for row in graph for x in row),
                   CLUSTER_SEED=str(seed), CLUSTER_RESOLUTION=str(resolution))
        env.update(settings)
        process = subprocess.run(self.graph_commands[backend], env=env,
                                 capture_output=True, text=True, timeout=30)
        self.assertEqual(process.returncode, 0, process.stderr)
        return [int(x) for x in process.stdout.splitlines()]

    def test_leiden_graph_invariants(self):
        rng = random.Random(91205)
        for sample in range(80):
            size = rng.randrange(2, 20)
            graph = [[0] * size for _ in range(size)]
            density = rng.uniform(.08, .8)
            for i in range(size):
                for j in range(i):
                    graph[i][j] = graph[j][i] = int(rng.random() < density)
            resolution = rng.choice([1000, 2500, 5000, 7500, 10000])
            seed = rng.randrange(4294967296)
            with self.subTest(sample=sample, size=size, resolution=resolution, seed=seed):
                labels = self.graph_run(graph, "c", seed, resolution)
                self.assertEqual(labels, self.graph_run(graph, "js", seed, resolution))
                self.assertEqual(len(labels), size)
                self.assertTrue(connected_partition(labels, graph, 1))
                quality = sum(graph[i][j] * 10000 - resolution
                              for i in range(size) for j in range(i)
                              if labels[i] == labels[j])
                self.assertGreaterEqual(quality, 0)
                for center in set(labels):
                    self.assertEqual(center, min(i for i, c in enumerate(labels) if c == center))
        graph = [[int(i != j and i // 4 == j // 4) for j in range(12)] for i in range(12)]
        graph[3][4] = graph[4][3] = graph[7][8] = graph[8][7] = 1
        for backend in ("c", "js"):
            self.assertEqual(self.graph_run(graph, backend), [0] * 4 + [4] * 4 + [8] * 4)

    def test_leiden_aggregation_preserves_weights_and_partition(self):
        # Deliberately nonuniform group sizes, with self-loops and parallel edges
        # in the aggregate. Coarse parents are inherited across refined groups.
        graph = [[int(i != j and (i + j) % 3 != 0) for j in range(6)] for i in range(6)]
        groups = [0, 0, 1, 2, 2, 2]
        parents = [0, 0, 0, 1, 1, 1]
        expected_edges = [sum(graph[i][j] for i in range(6) for j in range(6)
                              if groups[i] == a and groups[j] == b)
                          for a in range(3) for b in range(3)]
        expected = expected_edges + [2, 1, 3] + [0, 0, 1]
        for backend in ("c", "js"):
            actual = self.graph_run(graph, backend, GRAPH_MODE="aggregate",
                                    GRAPH_NEW_SIZE="3", GRAPH_LABELS="001222",
                                    GRAPH_PARENTS="000111")
            self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
