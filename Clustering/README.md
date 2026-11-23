# FASTA clustering in Bend

Six independent algorithm entry points for **DNA/RNA FASTA** files. Parsing,
normalization, alignment, clustering, TSV output, and representative FASTA
output are implemented in Bend. `run.py` validates command-line options,
discovers input files, builds the selected program, and launches it once per
input file.

Tested with the public [bendlang/bend](https://github.com/bendlang/bend)
repository at **6b806192284fc9c64404d9b0b59c937f568d87ec** (Bend 2.0.40),
verified on 2026-11-23 on Linux x86_64 (Ubuntu clang 21.1.8, Bun 1.3.14).
All 50 `.bend` files print `ALL PROOFS CHECK` and every program runs without
source changes; outputs are byte-identical to the results recorded with
**de26a917085a249786f185d20233f107462285f1** (Bend 2.0.38, macOS arm64,
verified 2026-10-22). The checkout entry point is `bend2/main.ts`; an
installed `bend` executable also works (see below).
The older `Bend2 Core/GUIDE.md` in the parent repository
describes an earlier language revision; use the compiler's `guide/GUIDE.md`
for this package.

## Run

Requires Python 3.10+, Bun, and Clang for the default native C backend.
The launcher looks for the Bend compiler in this order:

1. `--compiler PATH` (a source checkout or a `bend` executable);
2. `BEND_REPO=PATH` (legacy `BEND_CORE=PATH`): a source checkout containing
   `bend2/main.ts`, run with Bun;
3. `BEND=PATH`: a source checkout or a `bend` executable (a bare command name
   is looked up on `PATH`);
4. the sibling `../../bend` checkout, then the legacy `../../bend2-core`;
5. the `bend` command on `PATH` (for example an installed release).

To obtain the public compiler as a sibling checkout from this package
directory:

```sh
git clone https://github.com/bendlang/bend.git ../../bend
```

```sh
cd path/to/Bend-Programs/Clustering

python3 run.py single-linkage reads.fasta --identity 0.97 \
  --strand both --output clusters.tsv --representatives representatives.fasta

python3 run.py complete-linkage reads.fasta --identity 0.97
python3 run.py uclust reads.fasta --identity 0.97
python3 run.py set-cover reads.fasta --identity 0.97
python3 run.py cd-hit reads.fasta --identity 0.97
python3 run.py leiden reads.fasta --identity 0.97 --resolution 0.5 --seed 42

# Explicit approximate mode for large collections.
python3 run.py single-linkage reads.fasta --identity 0.97 --fast

# Kmer-db-prefiltered LZ-ANI with Vclust's symmetric total-ANI metric.
python3 run.py single-linkage reads.fasta --identity 0.97 --lz-ani \
  --min-kmers 20 --min-ident 0.70
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

Use `--backend js` to run generated JavaScript with Bun. Use `--threads N` to
set the native Bend runtime's CPU thread count; this controls runtime capacity
but only explicitly parallel Bend calls can use additional workers. JavaScript
requires `--threads 1`. Use `--compiler PATH`, `BEND_REPO=PATH`, or
`BEND=PATH` to select another checkout or executable (see the discovery order
above); `BEND_REPO` takes precedence over the legacy `BEND_CORE` and over
`BEND`. The test suites use the same environment settings and discovery.
When the compiler is an executable rather than a checkout, the build cache
key hashes that executable file only, so delete the cache (`bend-fasta-cache/` in the
system temporary directory) after replacing a wrapper script's underlying
compiler.
Build products are cached under
the system temporary directory and rebuilt when the sources, compiler, or
toolchain change. Runs default to one CPU thread and do not request GPU
execution. Compilation disables the compiler's optional update telemetry.

`--identity` defaults to `0.9` and accepts `(0, 1]` with up to four decimal
places. Threshold comparisons are inclusive. `--strand plus` is the default;
`--strand both` uses the better of the forward and reverse-complement comparisons.
`--fast` replaces exact alignment for sequences of at least 15 bases with an
approximate score from the cached 64-bin 15-mer MinHash. In plus-strand mode,
an inverted 65,536-bucket `(bin,value)` index discovers only pairs sharing a
real sketch entry; it does not allocate or scan an `n × n` candidate table.
Length and hashed 3-mer gates still run before an edge is accepted. Short
records and `--strand both` use the previous pairwise fallback. This mode can
miss qualifying pairs and admit nonqualifying pairs; its cluster labels must
not be described as exact identity results. The default without `--fast`
remains exact.
`--lz-ani` instead selects the indexed Bend LZ-ANI parser. It searches both
reference orientations and uses Vclust's default symmetric total ANI,
`(matches_ab + matches_ba) / (length_a + length_b)`, for the inclusive
`--identity` threshold. Before parsing, [`lib/kmer_db.bend`](lib/kmer_db.bend)
builds an inverted index of unique canonical 25-mers, counts only pairs sharing
a complete key, and applies Kmer-db's `ani-shorter` formula. `--min-kmers`
(default 20) and `--min-ident` (default 0.70) expose the same two default Vclust
candidate gates. Hash buckets are only an index: the complete 50-bit key is
checked, so a bucket collision is not counted as a common k-mer.

Only retained candidates are scored in both directions. The graph keeps
`O(n + E)` sparse rows, and LZ scoring retains one reusable row index plus one
temporary partner index instead of one 81,920-bucket index per record. The
in-memory k-mer posting table is still proportional to the number of unique
sample k-mers; on-disk multipart batches, k-mer sampling and per-row candidate
caps are not implemented yet. Consequently this mode is no longer all-pairs,
but is not yet the bounded-memory equivalent of the complete Vclust frontend.
`--fast` and `--lz-ani` are mutually exclusive.
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
| `single_linkage.bend` | Connected components of the sparse inclusive identity-threshold graph, using disjoint sets. Transitive chains join a cluster even if their endpoints fail the threshold. The smallest original index represents each component. |
| `complete_linkage.bend` | Agglomerative complete linkage over sparse adjacency rows. Repeatedly merges the pair whose minimum cross-cluster identity is greatest and intersects their neighbor rows, taking minimum scores. A missing edge is below threshold. Ties use the lexicographically smallest representative pair. Every within-cluster pair meets the threshold. |
| `uclust.bend` | Length-descending centroid clustering with exhaustive centroid search after a conservative hashed 3-mer filter. Assigns to the highest-identity qualifying centroid, breaking ties by original index; otherwise creates a centroid. Equal-length input order is stable. |
| `set_cover.bend` | Greedy set-cover clustering of the residual sparse threshold graph: choose the uncovered record covering the most uncovered neighbors, assign its closed neighborhood, remove those records, and repeat. Ties use original index. There is no subsequent reassignment or claim of an optimal minimum cover. |
| `cd_hit.bend` | Length-descending greedy incremental clustering. Uses the first qualifying representative in creation order, with a conservative hashed 3-mer filter before alignment. Identity is normalized by the shorter sequence length. |
| `leiden.bend` | A multilevel Leiden iteration on an unweighted sparse threshold graph, optimizing the Constant Potts Model (CPM). Performs seeded local moves, constrained singleton refinement, sparse weighted aggregation, and projection back to original records. The smallest input index names each final community. |

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
FASTA-to-membership-and-representatives workflow. Its memory architecture now
uses the same important separation: a k-mer candidate filter runs before exact
alignment, only qualifying pairs become sparse adjacency rows, and clustering
consumes those rows without first allocating an `n × n` matrix. Complete
linkage intersects sparse neighbor rows; Leiden also keeps aggregate graphs
sparse. FASTA input is parsed incrementally in 64 KiB chunks; completed
sequences use two bits per A/C/G/T base or four bits when IUPAC ambiguity
symbols occur. A 256-counter 3-mer signature and a 64-bin 15-mer sketch are
computed once per record. The exact graph path sorts records by length and
stops a row once all remaining records are too short to meet the threshold.

The default and `--fast` paths are not numerical equivalents of Vclust. The fast path now
implements Vclust's core sparse organization—an inverted candidate index,
candidate-only scoring, and sparse graph clustering—in Bend. Vclust itself uses
Kmer-db's sampled k-mers, local alignment with LZ-ANI, and Clusty's optimized
sparse graph structures. The fast implementation uses a 64-bin MinHash score
and does not call that score ANI. The separate explicit `--lz-ani` path uses
canonical unique 25-mer Kmer-db candidate semantics, the port described below,
and Vclust's default tANI edge metric. The default
Bend algorithms use conservative
length/3-mer rejection and global edit alignment for survivors. The explicit
`--fast` mode publishes approximate, clearly labeled cluster assignments; it
is never enabled silently.
Vclust supports ANI, global ANI, total ANI, and alignment-coverage thresholds.
An ordinary or `--fast --identity 0.95` run here must not be interpreted as
Vclust's `--ani 0.95`, nor as its ANI-plus-coverage workflow for viral contigs.
In `--lz-ani` mode the same option is specifically a tANI threshold;
ANI/gANI/coverage filters are not yet exposed.

Vclust also offers longest-sequence representative labeling. Here the selected
representative follows each algorithm's documented rule (for example, the
smallest input index for single linkage and the selected center for set-cover).
On-disk/batched databases, sampled k-mers, candidate caps, multipart sample
semantics, reusable ANI tables, and Vclust's additional filter metrics remain
outside this implementation's current capabilities. See
[`VCLUST_ARCHITECTURE.md`](VCLUST_ARCHITECTURE.md) for the source audit and the
exact correspondence with the Bend implementation.

#### Indexed numeric LZ-ANI port

[`lib/lz_ani_numeric.bend`](lib/lz_ani_numeric.bend) remains the small
list-based specification oracle. [`lib/lz_ani_indexed.bend`](lib/lz_ani_indexed.bend)
is the scalable pair scorer: it builds checked 65,536-bucket 11-mer anchor and
16,384-bucket 7-mer seed indexes, reuses each reference index, searches the
forward and reverse-complement reference, performs the close/distant anchor
choice, splits overlapping gaps in both directions, applies forward and
backward rolling approximate extension, and reports ANI, gANI, and coverage in
basis points. Defaults match upstream: 11-base anchors, 7-base nearby seeds,
40-base query/reference distance, 35-base accepted regions, and a 15-base
approximation window with at most seven mismatches and a final three-match run.

[`lz_ani.bend`](lz_ani.bend) is a streaming all-to-all table driver: it builds
one reference index per row, emits directed results immediately, and retains no
pair matrix. [`lib/lz_ani_graph.bend`](lib/lz_ani_graph.bend) builds the
undirected sparse tANI graph used by all six production entry points when
`--lz-ani` is selected. [`lib/kmer_db.bend`](lib/kmer_db.bend) first retains
only Kmer-db-compatible candidates. Each retained pair is scored in both
directions; only accepted edges survive. The row reference index is reused and
the partner index is temporary, bounding resident LZ index storage.

The native-C and JavaScript backends agree with the official LZ-ANI 1.2.3
binary bundled with the local Vclust 1.3.1 environment on all 344 directed
comparisons in the deterministic differential suite. It includes the original
nine-record fixture and a generated 17-record set with substitutions,
insertions, deletions, reverse complements, and unrelated sequences. The suite
compares exact `nt_match`, `nt_mismatch`, and `num_alns` fields. Run it with:

```sh
python3 Clustering/tests/test_lz_ani_numeric.py
python3 Clustering/tests/test_kmer_db.py
```

The proof boundary contains three universal laws plus one closed certificate:
integer ANI equals its matches/total specification for every U32 pair; every
empty gap contributes zero matches for every reference and positions; every
empty query has an empty approximate extension; and an empty alignment scores
zero. These claims validate numeric seams, not whole-parser equivalence. Bend
Core exposes F32 rather than binary64; the close/distant probability comparison
therefore uses a three-term negative-log approximation plus the upstream
binary64 cutoff at anchor length 27. The deterministic differential suite is
evidence, not a proof that every possible parser trace is identical.

The Kmer-db differential test compares native C and JavaScript output against
Kmer-db 2.3.1 for exact shared-k-mer counts after deduplication, canonical
reverse complements, ambiguous bases and repetitive input. Its pure
`kmer_score.bend` seam proves universally that zero-overlap pairs cannot pass
the positive default shared-k-mer gate.

This remains a validation-stage port rather than a drop-in replacement for the
complete Vclust pipeline. On-disk batching, sampling, candidate caps, multipart
sample semantics, ANI/gANI/coverage filtering, and full EarlyVir LZ execution
are still pending. The existing whole-dataset benchmark numbers are from the
MinHash path, not from `--lz-ani`.
Fixed porting defects and the remaining behavioral risks are tracked in
[`LZ_ANI_PORT_NOTES.md`](LZ_ANI_PORT_NOTES.md).

### Alignment and identity

The shared aligner computes a unit-cost global edit alignment:
substitution, insertion, and deletion each cost one; exact matches cost zero.
Among minimum-cost alignments, it chooses the greatest exact-match count.
It uses one dynamic-programming row and a threshold-derived exact band. Cells
outside the maximum edit distance that could still reach the requested
identity are saturated and skipped. A surviving alignment therefore has the
same minimum-edit/maximum-match result as the full matrix; low thresholds can
expand the band to the full row. If `M` is the match count and `D` the edit
cost, alignment length is `M + D`.

- Single linkage, complete linkage, UCLUST, set-cover, and the Leiden graph use
  `floor(10000 * M / (M + D))` basis points.
- CD-HIT uses `floor(10000 * M / min(sequence_lengths))` basis points.

The CD-HIT filter counts hashed 3-mers with multiplicity. Hash collisions can
only increase the common-word count, so they cannot reject a qualifying pair.
With a required match count `m`, the conservative lower bound is
`max(0, m - 2 * (len_a + len_b - 2*m + 1))`. If the bound is zero, filtering
is skipped. This favors sensitivity over the original CD-HIT filter's speed.

The shared sparse-graph builder and UCLUST use a corresponding conservative
filter for global identity. A qualifying alignment must contain at least
`ceil(threshold * max(lengths))` exact matches. Length-incompatible pairs are
rejected immediately; otherwise the same match-run bound determines the
minimum common 3-mer count. A rejected pair therefore cannot meet the requested
global-identity threshold. The filter can admit false positives, which are
resolved by the exact aligner.

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
to **16384 records, 300000 residues per record, and 256 MiB**. Alignment cells
store edit cost and exact matches independently, so these bounds leave U32
headroom for score arithmetic; they are not a speed guarantee.

The executable reader does not materialize the whole FASTA as one linked
`String`: it carries one file chunk and the current record, then packs each
completed sequence. Representative output decodes only records that must be
written. The 256 MiB limit is an input validation boundary, not a request to
allocate a linked representation of that size.

These are reference implementations for small and moderate datasets. Full
alignment costs `O(length_a * length_b)` for every pair that survives the
filter. Single linkage, complete linkage, set cover, and Leiden store sparse
adjacency rows using `O(n + E)` graph memory instead of allocating an `n²`
identity matrix; `E` is the number of threshold-passing directed edges. Their
candidate builder is streamed one query row at a time and prunes the
length-sorted tail when the threshold becomes impossible.

This removes the unconditional quadratic allocation, not every quadratic worst
case. A highly redundant dataset can have `E = O(n²)`. The exact and
reverse-complement paths can still examine all `n(n-1)/2` pairs, while the
exact graph builder skips length-incompatible tails. Plus-strand `--fast` uses
the inverted index for all six algorithms; UCLUST and CD-HIT consume its graph
while retaining their documented centroid choices.
Large collections of long reads can therefore take substantial time. Packed
streaming input removes the former multi-GiB load spike. Threshold banding
reduces exact work substantially, but exact dynamic programming remains much
more expensive than LZ-ANI on long survivors. `--fast` avoids that alignment
with an explicit sensitivity/precision tradeoff.

## Direct Bend use

Each algorithm can be run or compiled without the Python launcher:

```sh
export BEND_NO_TELEMETRY=1
export CLUSTER_INPUT=/absolute/path/reads.fasta
export CLUSTER_IDENTITY=9700
export CLUSTER_REVERSE=1
bend single_linkage.bend

bend single_linkage.bend -o /tmp/fasta-cluster
/tmp/fasta-cluster --threads 1 --gpu off
```

`bend` here is an installed Bend CLI; from a source checkout use
`bun path/to/bend/bend2/main.ts` in its place.

The same environment settings work with native binaries and emitted `.js`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `CLUSTER_INPUT` | required | Input FASTA path |
| `CLUSTER_IDENTITY` | `9000` | Integer identity in `1..10000` basis points |
| `CLUSTER_REVERSE` | `0` | `1` enables reverse-complement comparisons |
| `CLUSTER_FAST` | `0` | `1` enables explicit approximate MinHash scoring |
| `CLUSTER_REPRESENTATIVES` | empty | Optional representative FASTA path |
| `CLUSTER_RESOLUTION` | `5000` | Leiden CPM resolution in `1..10000` basis points |
| `CLUSTER_SEED` | `1` | Leiden unsigned 32-bit seed |
| `CLUSTER_PASSES` | `100` | Local-move sweep limit per Leiden level |
| `CLUSTER_DNA` | `1` | DNA/RNA mode; the launcher always sets `1` |

Direct Bend output goes to stdout and direct representative-file writes are
ordinary file writes. Use distinct input and output paths. The launcher's
atomic replacement and path-alias checks apply only when using `run.py`.

## Validation

On 2026-10-25, all 27 tests passed against public Bend 2.0.38 at
`de26a917085a249786f185d20233f107462285f1`, including native C and JavaScript
execution, a proven-kernel verdict, folder workflows, and representative-sequence output. No Bend source
compatibility changes were needed. The launcher and tests now prefer the public
checkout. The suite also previously passed against the legacy `bend2-core`
2.0.16 snapshot at `87355989791e12e0f29026ea1f65dc344290c24c`; that repository's
unchanged `main` did not reflect the newer public repository's releases.

On 2026-11-23 the suite was re-run against Bend 2.0.40 at
`6b806192284fc9c64404d9b0b59c937f568d87ec` on Linux x86_64: 27 of 28 tests
passed. The exception, `test_fast_score_laws_pass_proven_kernel`, needs
`--verdict`, which cannot build its BendTT kernel without Lean v4.34.0; the
same applies to the proof tests in `test_kmer_db.py` and
`test_lz_ani_numeric.py`. `bend lib/fast_score.bend --check-only` and every
other `.bend` file print `ALL PROOFS CHECK`. The tests that compare with the
official Kmer-db/LZ-ANI binaries skip when `.tools/vclust-1.3.1` is absent.
Recorded dataset outputs were reproduced byte-for-byte; see
`datasets/infant_gut_virome/README.md` and `benchmark/README.md`.

```sh
python3 tests/test_clustering.py
python3 tests/test_lz_ani_numeric.py
python3 tests/test_kmer_db.py
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
It also checks exact threshold-banded alignment, cross-backend stability of the
explicit fast mode, and rejects any production regression that restores the
removed dense pair matrix, whole-file linked FASTA reader, or non-packed
persistent sequences.

`lib/fast_score.bend` and `lib/vclust_index.bend` add universal laws that the
indexed final score equals the original fast score for every input counter and
that zero shared indexed entries always produce score zero. They justify the
candidate-omission seam; they do not assert that MinHash equals biological ANI.
The pure laws pass Bend's proven `--verdict` kernel. A verdict over the whole
imported clustering book is presently blocked by a minimized checker/kernel
mismatch in its optional-file-output path, documented under
`errors_bugs_and_problems_found/bend_verdict_affine_branch`.

The `law`/type system checks and executable tests are not a formal proof of all
clustering properties. `lib/common.bend` contains shared data handling and the
aligner; every algorithm's clustering routine lives in its own top-level file.
`apply` and `branch` keep matches inside function values because this Bend
revision rejects a match applied directly to a computed value.
