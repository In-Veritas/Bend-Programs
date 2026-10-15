# FASTA clustering in Bend

Six independent algorithm entry points for **DNA/RNA FASTA** files. Parsing,
normalization, alignment, clustering, TSV output, and representative FASTA
output are implemented in Bend. `run.py` validates command-line options,
discovers input files, builds the selected program, and launches it once per
input file.

Tested with `bend2-core` **87355989791e12e0f29026ea1f65dc344290c24c**
(Bend 2.0.16), the remote `main` fetched and verified on 2026-10-11. The entry point is
`bend2/main.ts`. The older `Bend2 Core/GUIDE.md` in the parent repository
describes an earlier language revision; use the compiler's `guide/GUIDE.md`
for this package.

## Run

Requires Python 3.10+, Bun, and Clang for the default native C backend.
The sibling `../../bend2-core` checkout is detected automatically.

```sh
cd "/Users/macolas/Software/Gabriel/Bend-Programs/CLustering algorithms"

python3 run.py single-linkage reads.fasta --identity 0.97 \
  --strand both --output clusters.tsv --representatives representatives.fasta

python3 run.py complete-linkage reads.fasta --identity 0.97
python3 run.py uclust reads.fasta --identity 0.97
python3 run.py set-cover reads.fasta --identity 0.97
python3 run.py cd-hit reads.fasta --identity 0.97
python3 run.py leiden reads.fasta --identity 0.97 --resolution 0.5 --seed 42
```

### Folders: one independent clustering per FASTA file

```sh
python3 run.py cd-hit ./fasta-folder --identity 0.97 --strand both \
  --output-dir ./results

# Include files in subfolders and mirror their directory structure in results.
python3 run.py single-linkage ./fasta-folder --recursive --identity 0.97 \
  --output-dir ./results
```

Every input file produces **both** a membership TSV and a representative FASTA.
For example, `sample.fna` produces `sample.fna.clusters.tsv` and
`sample.fna.representatives.fasta`. The full filename is retained so `sample.fa`
and `sample.fasta` cannot overwrite one another's outputs. With `--recursive`,
`sub/sample.fna` produces the corresponding pair under `results/sub/`.
Record indices restart at zero for each file; sequences in different files are
never clustered together. Each representative is an actual input sequence,
normalized as described below, rather than a consensus sequence.

Folder discovery accepts `.fasta`, `.fa`, `.fna`, `.ffn`, `.frn`, `.fas`, and
`.fsa`, case-insensitively, in sorted relative-path order. Other files are
ignored. The selected output directory and files ending in
`.representatives.fasta` are excluded from folder discovery, including repeat
recursive runs. An explicitly supplied single file is accepted regardless of
its name. A folder with no matching files is an error; an empty FASTA file is a
valid dataset with zero records.

The default folder output directory is `INPUT/clusters/ALGORITHM`; directories
are created as needed. Use `--output-dir` for folders and `--output` /
`--representatives` for a single input file. Folder output cannot be the input
directory itself or its ancestor. All files are clustered successfully before
any named result is replaced, so malformed input leaves existing results
untouched. Replacements are atomic per file, not a filesystem transaction
across the entire batch. Limits apply independently to each input file.

Use `--backend js` to run generated JavaScript with Bun. Use `--compiler PATH`
or `BEND_CORE=PATH` to select another checkout. Build products are cached under
the system temporary directory and rebuilt when the sources, compiler, or
toolchain change. Runs use one CPU thread; this implementation does not request
GPU execution. Compilation disables the compiler's optional update telemetry.

`--identity` defaults to `0.9` and accepts `(0, 1]` with up to four decimal
places. Threshold comparisons are inclusive. `--strand plus` is the default;
`--strand both` uses the better of the forward and reverse-complement comparisons.
Leiden's `--passes` defaults to 100 local-move sweeps per level. A sweep-limit
failure exits with an error instead of reporting an unfinished clustering.

Output goes to stdout unless `--output` is supplied. Named outputs are prepared
in temporary files and replaced after a successful run. The launcher rejects
input/output path aliases, including existing hard links.

Try the included small example:

```sh
python3 run.py single-linkage tests/fixtures/chain.fasta --identity 0.75
```

```text
record_index  cluster_representative  length  header
0             0                       4       a first
1             0                       4       b bridge
2             0                       4       c last
3             3                       4       d separate
```

The actual separators are tabs. Every record appears once, in input order.
Indices are zero-based. `cluster_representative` is an original record index,
so cluster labels need not be consecutive. Repeated FASTA identifiers remain
distinct records. Header tabs are converted to spaces. Representatives retain
their headers and are written as uppercase, normalized sequences, wrapped at
80 residues. RNA representatives therefore contain `T` in place of `U`.

## Algorithms

| Entry point | Method and deterministic choices |
| --- | --- |
| `single_linkage.bend` | Connected components of the inclusive identity-threshold graph, using disjoint sets. Transitive chains join a cluster even if their endpoints fail the threshold. The smallest original index represents each component. |
| `complete_linkage.bend` | Agglomerative complete linkage. Repeatedly merges the pair whose minimum cross-cluster identity is greatest, then updates similarities by taking minima. Stops below the threshold. Ties use the lexicographically smallest representative pair. Every within-cluster pair meets the threshold. |
| `uclust.bend` | Length-descending centroid clustering with exhaustive centroid search. Assigns to the highest-identity qualifying centroid, breaking ties by original index; otherwise creates a centroid. Equal-length input order is stable. |
| `set_cover.bend` | Greedy set-cover clustering of the residual threshold graph: choose the uncovered record covering the most uncovered neighbors, assign its closed neighborhood, remove those records, and repeat. Ties use original index. There is no subsequent reassignment or claim of an optimal minimum cover. |
| `cd_hit.bend` | Length-descending greedy incremental clustering. Uses the first qualifying representative in creation order, with a conservative hashed 3-mer filter before alignment. Identity is normalized by the shorter sequence length. |
| `leiden.bend` | A multilevel Leiden iteration on an unweighted threshold graph, optimizing the Constant Potts Model (CPM). Performs seeded local moves, constrained singleton refinement, aggregation, and projection back to original records. The smallest input index names each final community. |

UCLUST's centroid rules and the distinction between ordering and searching
follow the [UCLUST algorithm documentation](https://www.drive5.com/usearch/manual/uclust_algo.html).
CD-HIT's length order, first-hit mode, word filtering, and shorter-sequence
denominator are described in its [user guide](https://github.com/weizhongli/cdhit/blob/master/doc/cdhit-user-guide.tex).
The residual-graph set-cover procedure is the sequence-clustering variant
described by [MMseqs2](https://github.com/soedinglab/MMseqs2/wiki#clustering-modes).

These are independent algorithm implementations. They do **not** reproduce
USEARCH's approximate search, CD-HIT's banded/scoring heuristics, MMseqs2's
alignment pipeline, or those products' output formats. Results can differ from
the original tools, particularly for fragments, gaps, and ambiguous bases.

### Relationship to Vclust

The suite offers the same six clustering method families as
[Vclust](https://github.com/refresh-bio/vclust) and a direct
FASTA-to-membership-and-representatives workflow. It is not currently a
numerical or performance equivalent of Vclust. Vclust separates k-mer
prefiltering, local alignment with LZ-ANI, and graph clustering with Clusty.
It supports ANI, global ANI, total ANI, and alignment-coverage thresholds;
this suite currently uses the global edit-alignment identities defined below.
An `--identity 0.95` run here must therefore not be interpreted as Vclust's
`--ani 0.95`, nor as its ANI-plus-coverage workflow for viral contigs.

Vclust also offers longest-sequence representative labeling. Here the selected
representative follows each algorithm's documented rule (for example, the
smallest input index for single linkage and the selected center for set-cover).
Large-genome alignment, sparse prefiltering, reusable ANI tables, and Vclust's
additional metrics remain outside this implementation's current capabilities.

### Alignment and identity

The shared aligner computes a full, unit-cost global edit alignment:
substitution, insertion, and deletion each cost one; exact matches cost zero.
Among minimum-cost alignments, it chooses the greatest exact-match count.
It uses one dynamic-programming row, without a band or a length-equality
assumption. If `M` is the match count and `D` the edit cost, alignment length
is `M + D`.

- Single linkage, complete linkage, UCLUST, set-cover, and the Leiden graph use
  `floor(10000 * M / (M + D))` basis points.
- CD-HIT uses `floor(10000 * M / min(sequence_lengths))` basis points.

The CD-HIT filter counts hashed 3-mers with multiplicity. Hash collisions can
only increase the common-word count, so they cannot reject a qualifying pair.
With a required match count `m`, the conservative lower bound is
`max(0, m - 2 * (len_a + len_b - 2*m + 1))`. If the bound is zero, filtering
is skipped. This favors sensitivity over the original CD-HIT filter's speed.

### Leiden details

For an undirected graph with no initial self-loops, the objective is
`sum_C (internal_edges(C) - gamma * |C| * (|C| - 1) / 2)`.
An edge exists exactly when global identity meets `--identity`. Thus identity
controls graph construction, while resolution controls community granularity.
Membership does not imply a threshold match to the reported representative.

The implementation follows the refinement/aggregation construction in the
[Leiden paper, Appendix A](https://arxiv.org/html/1810.08473v3#A1).
It uses shuffled sweeps for local moving, and uniform reservoir selection among
eligible non-decreasing refinement merges. This is the uniform-selection
variant, rather than exponential weighting by a finite temperature. Refinement
checks both the node and target community's connectivity to their parent
community. Aggregate node masses and edge multiplicities are preserved, along
with the coarse starting partition. Integer/Nat score comparisons avoid
floating-point tolerances. The PRNG is an explicitly seeded 32-bit LCG.

One run performs one complete multilevel iteration starting from singletons.
It does not claim the asymptotic optimality obtained by indefinitely iterating
Leiden. Non-contraction during refinement and exhausted local-move fuel are
reported as errors. `--resolution` accepts `(0, 1]`, defaults to `0.5`, and
`--seed` accepts `0..4294967295`, defaulting to `1`.

## FASTA handling and practical limits

Accepts uncompressed FASTA, regardless of filename suffix, with LF or CRLF,
multiline sequences, lowercase letters, sequence spaces/tabs, blank lines,
and semicolon comment lines. DNA/RNA IUPAC symbols are accepted; `U` becomes
`T`. Ambiguity codes are compared literally, including `N`: they are not
wildcards. Reverse complementation supports all accepted ambiguity codes.

Empty files produce the TSV header and zero clusters. Empty headers, empty
records, sequence text before a header, gaps, digits, and invalid symbols fail
with a nonzero exit status and a line-numbered diagnostic. Inputs are bounded
to **2048 records, 30000 residues per record, and 64 MiB**. These limits protect
array indexing and packed alignment arithmetic; they are not a speed guarantee.

These are reference implementations for small and moderate datasets. Full
alignment costs `O(length_a * length_b)` per pair. The graph/linkage methods
store a dense `O(n²)` identity matrix. Complete linkage, residual set-cover,
and the current Leiden implementation also scan dense structures repeatedly.
Large collections of long reads can therefore take substantial time; these
programs are not intended to replace industrial tools for millions of reads.

## Direct Bend use

Each algorithm can be run or compiled without the Python launcher:

```sh
export BEND_NO_TELEMETRY=1
export CLUSTER_INPUT=/absolute/path/reads.fasta
export CLUSTER_IDENTITY=9700
export CLUSTER_REVERSE=1
bun ../../bend2-core/bend2/main.ts single_linkage.bend

bun ../../bend2-core/bend2/main.ts single_linkage.bend -o /tmp/fasta-cluster
/tmp/fasta-cluster --threads 1 --gpu off
```

The same environment settings work with native binaries and emitted `.js`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `CLUSTER_INPUT` | required | Input FASTA path |
| `CLUSTER_IDENTITY` | `9000` | Integer identity in `1..10000` basis points |
| `CLUSTER_REVERSE` | `0` | `1` enables reverse-complement comparisons |
| `CLUSTER_REPRESENTATIVES` | empty | Optional representative FASTA path |
| `CLUSTER_RESOLUTION` | `5000` | Leiden CPM resolution in `1..10000` basis points |
| `CLUSTER_SEED` | `1` | Leiden unsigned 32-bit seed |
| `CLUSTER_PASSES` | `100` | Local-move sweep limit per Leiden level |
| `CLUSTER_DNA` | `1` | DNA/RNA mode; the launcher always sets `1` |

Direct Bend output goes to stdout and direct representative-file writes are
ordinary file writes. Use distinct input and output paths. The launcher's
atomic replacement and path-alias checks apply only when using `run.py`.

## Validation

On 2026-10-11, fetching upstream and checking its remote default branch confirmed
that `87355989791e12e0f29026ea1f65dc344290c24c` was still the latest `main`.
A fresh build with an empty cache compiled all six algorithms for native C and
JavaScript; all 22 tests passed in 22.902 seconds, including folder workflows
and representative-sequence output. No compatibility changes were needed.

```sh
python3 tests/test_clustering.py
```

The standard-library-only test suite builds all six entry points for native C
and JavaScript, checks byte-identical outputs, and also exercises direct Bend
execution. It compares the first five algorithms with independent Python
reference implementations over authored and randomized FASTA fixtures. Leiden
tests include planted communities, 80 generated graphs, connectivity and
nonnegative CPM quality, seed reproducibility, iteration-limit failure, and an
independent check of aggregate edge weights, node masses, and inherited labels.
Parser tests include read-chunk boundaries, accepted and rejected size limits,
malformed records, RNA, ambiguity codes, and reverse complements. Output tests
cover representatives, paths with spaces, and preserving files after failure.
Folder tests run all six methods on both backends and verify independent
datasets, representative FASTAs, colliding filename stems, empty inputs,
recursive discovery, repeat runs, output aliases, per-file size limits, and
preservation of all batch outputs when any input fails.

The `law`/type system checks and executable tests are not a formal proof of all
clustering properties. `lib/common.bend` contains shared data handling and the
aligner; every algorithm's clustering routine lives in its own top-level file.
`apply` and `branch` keep matches inside function values because this Bend
revision rejects a match applied directly to a computed value.
