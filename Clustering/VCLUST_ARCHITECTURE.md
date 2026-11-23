# Vclust memory architecture and the Bend implementation

This note records the upstream source audit used for the sparse clustering
implementation. Revisions inspected:

- Vclust `59b350c87428540ed9290701ae376c98dd1cfb2e`;
- Kmer-db `bd8c42a862298ef30ef101814db8214ae7074161`;
- LZ-ANI `c898e1e6a91dd90c3926fef583feb9ee5a04bb03`; and
- Clusty `b687638d15822c1a6f69f29a2b7d5c3e87a7c08a`.

## What Vclust does

Vclust is a three-stage pipeline rather than one all-pairs distance matrix:

1. [`vclust prefilter`](https://github.com/refresh-bio/vclust/blob/59b350c87428540ed9290701ae376c98dd1cfb2e/vclust.py)
   calls Kmer-db in sparse mode. `--batch-size` bounds the number of sequences
   held per database part, `--kmers-fraction` samples k-mers, and `--max-seqs`
   caps the candidates retained per query.
2. LZ-ANI aligns only candidate pairs. Its matcher consumes one filter row at a
   time and clears it after use; Lempel-Ziv/k-mer anchors avoid a full
   `length_a × length_b` dynamic-programming matrix.
3. Clusty receives the resulting ANI edges. Its
   [`SparseMatrix`](https://github.com/refresh-bio/clusty/blob/b687638d15822c1a6f69f29a2b7d5c3e87a7c08a/src/sparse_matrix.h)
   is a vector of adjacency vectors. Single linkage, CD-HIT, UCLUST, and set
   cover traverse present neighbors. Complete linkage uses sparse Heaptrix rows
   and a heap, removing old rows after merges.

Kmer-db's sparse matrix is a vector of hash maps rather than an `n × n` array;
its multipart command processes a grid of bounded database batches. LZ-ANI and
Clusty still use memory proportional to retained candidates/edges. If nearly
every pair survives, their sparse structures can approach quadratic size;
batching and candidate caps control that case, with an explicit sensitivity
tradeoff.

## What is implemented in Bend

The shared implementation in [`lib/common.bend`](lib/common.bend) now provides:

- `Neighbors`, a recursive `Data` adjacency row stored in
  `Array<Neighbors>`;
- `SparseGraph`, whose storage is `O(n + E)` instead of an unconditional
  `Array<U32>` of `n²` identities;
- incremental 64 KiB FASTA parsing and persistent 2/4-bit nucleotide arrays;
- one reusable 256-counter hashed 3-mer signature and one 64-bin 15-mer sketch
  per record;
- a length check and conservative hashed 3-mer intersection bound before
  global alignment;
- threshold-derived exact banding for the default global aligner;
- an explicit `--fast` mode that replaces long-sequence alignment with a
  threshold-calibrated 64-bin MinHash score; and
- [`lib/vclust_index.bend`](lib/vclust_index.bend), an inverted 65,536-bucket
  table over the populated `(MinHash bin, value)` entries. Each record adds at
  most 64 postings; hash collisions are checked against the complete key;
  per-query counters exist only for discovered candidates; and only accepted
  edges enter the sparse graph.

The conservative filter on the default path is exact with respect to the
existing global-identity definition: hash collisions cause extra alignments,
not missing qualifying edges. The indexed fast path is exact with respect to
the already documented approximate MinHash relation: any pair accepted by that
relation must share at least one indexed entry, and the final score is the same
`fast_score_counts` calculation used before indexing.

The algorithms consume the sparse representation directly:

- single linkage unions present neighbors;
- set cover counts and assigns only present residual neighbors;
- complete linkage keeps an edge after a merge only when both source rows had
  it, using their minimum score;
- Leiden derives per-community statistics from sparse rows and aggregates
  parallel directed edges without allocating a dense coarse matrix; and
- UCLUST and CD-HIT consume the indexed graph in plus-strand fast mode while
  preserving their best-centroid and first-centroid selection rules. Short
  records and reverse-complement mode retain the prior pairwise fallback.

CD-HIT already had its shorter-sequence 3-mer filter and no dense matrix.

## Kmer-db and LZ-ANI port

This is a Bend implementation of Vclust's central sparse pipeline pattern, not
a byte-for-byte port of its industrial search engine. The conservative default
path still runs the threshold-banded, one-row global edit aligner for surviving
pairs. The explicit fast path now has Kmer-db-style inverted discovery, but
uses a fixed 64-bin MinHash index rather than Kmer-db's sampled k-mer database.

The explicit `--lz-ani` path is separate from that MinHash score.
`lib/kmer_db.bend` extracts per-sample unique canonical 25-mers, represents
each complete 50-bit key as two U32 words, and uses a checked 65,536-bucket
inverted table. Insertion updates sparse per-query counters only for records
sharing the complete key. It then applies Kmer-db's `ani-shorter` formula and
the exposed `--min-kmers`/`--min-ident` gates (defaults 20 and 0.70). Native C
and JavaScript match Kmer-db 2.3.1 candidate pairs and exact common-k-mer counts
on the differential fixture.

`lib/lz_ani_indexed.bend` implements checked 11-mer and 7-mer posting tables,
the close/distant probability choice, two-sided overlap-aware gap splitting,
forward/backward approximate extension, reverse-complement references, and
ANI/gANI/coverage counts. `lz_ani.bend` streams a directed all-to-all table
without retaining a pair matrix. `lib/lz_ani_graph.bend` scores only the
Kmer-db candidates in both directions and retains only edges meeting the
symmetric tANI threshold. It materializes one reusable row index and one
temporary partner index rather than retaining an 81,920-bucket index for every
record. All six clusterizers consume that graph when the mode is selected.

C and JavaScript match the official LZ-ANI 1.2.3 `nt_match`, `nt_mismatch`,
and `num_alns` fields on 344 deterministic directed comparisons. The small
numeric oracle still provides three universal laws and one closed certificate
that pass `--verdict`. This is not whole-parser formal equivalence: Bend's
probability comparison approximates upstream binary64 with F32 negative-log
terms, and the differential suite remains finite evidence.

Consequently:

- ordinary sparse inputs no longer pay `n²` graph storage;
- highly redundant inputs may still produce `O(n²)` edges;
- plus-strand fast clustering visits postings and discovered candidates rather
  than unconditionally scanning all record pairs; exact and reverse-complement
  paths still have pairwise worst cases; and
- `--lz-ani` discovers candidates with full canonical 25-mers and does not walk
  every unordered pair, but its postings are still fully resident; batching,
  sampled k-mers, candidate caps, multipart samples, and additional ANI filters
  remain pending; and
- full EarlyVir parsing and prefiltering now complete, but exact all-candidate
  global alignment remains beyond the measured runtime window.

These limitations are application architecture, not evidence of a Bend
compiler/runtime defect.

## Proof boundary

`vclust_index.bend` contains two universal checked laws rather than a catalog
of dataset cases. `indexed_score_agrees` proves that the indexed final decision
is definitionally the original fast score for every counter/population/
threshold triple. `zero_common_is_rejected` proves for every population and
threshold that a pair sharing no indexed entry scores zero, which is the key
condition permitting omission of non-candidates. End-to-end tests separately
exercise index construction, collision checks, graph clustering, native C, and
JavaScript.

These laws prove the implementation seam they state. They do not prove that a
64-bin MinHash estimate equals biological ANI, nor that the heuristic cannot
miss an LZ-ANI edge. Their pure definitions live in `lib/fast_score.bend` and
pass Bend's proven `--verdict` kernel. A verdict over the entire imported
clustering book is still blocked by a separately minimized checker/kernel
mismatch in the optional-file-output recursion; see
[`../errors_bugs_and_problems_found/bend_verdict_affine_branch/`](../errors_bugs_and_problems_found/bend_verdict_affine_branch/).

`kmer_score.bend` adds a third universal seam: with the positive default shared
k-mer minimum, a zero-overlap pair cannot pass candidate selection, for every
possible pair of sample k-mer counts. Exact 50-bit key extraction, per-sample
deduplication and common-count accumulation are validated differentially rather
than claimed as formally proven.

## Validation snapshot

On 2026-10-29, all 28 end-to-end tests passed with public Bend 2.0.38 at
`de26a917085a249786f185d20233f107462285f1`. They cover native C, JavaScript,
the pure-score BendTT verdict,
independent Python oracles, randomized alignments, both strands, exact
complete-linkage/set-cover labels, 80 generated Leiden graphs, weighted Leiden
aggregation, explicit LZ-ANI graph clustering, and a structural guard against
restoring `n²` pair storage. The separate LZ-ANI differential suite also passed
all 344 directed comparisons in native C and JavaScript. The Kmer-db suite
passed both backends against Kmer-db 2.3.1 and its pure proof kernel.

On 2026-11-23 the package was re-verified on Bend 2.0.40 at
`6b806192284fc9c64404d9b0b59c937f568d87ec` (Linux x86_64) without source
changes. All 50 `.bend` files pass `--check-only`, and 27 of 28 end-to-end
tests pass. The exception is the BendTT `--verdict` test: Lean v4.34.0 is not
installed on that machine, so the kernel cannot build. The official
LZ-ANI/Kmer-db differential tests were skipped because Vclust 1.3.1 is not
installed there. The native C and JavaScript LZ-ANI fixture test passed. The
Kmer-db test program matched an independent Python canonical-25-mer count on
both backends. All six full-EarlyVir `--fast` outputs, the common-graph
memberships and the smoke-test TSVs were byte-identical to the recorded
results.

A single native-C feasibility sample used the 16 shortest EarlyVir references,
95% identity and both strands. Outputs from the old dense snapshot and the new
sparse implementation were byte-identical. These are individual runs, not a
controlled performance benchmark:

| Algorithm | Dense snapshot | Sparse/filter implementation | Peak RSS old/new |
| --- | ---: | ---: | ---: |
| single linkage | 12.77 s | 1.94 s | 2.83 / 2.80 MiB |
| complete linkage | 12.77 s | 1.96 s | 2.83 / 2.80 MiB |
| set cover | 13.02 s | 2.27 s | 2.81 / 2.84 MiB |
| Leiden | 14.73 s | 2.30 s | 2.91 / 2.89 MiB |

The input is too small for graph storage to dominate RSS; the timing difference
primarily shows the conservative filter avoiding unnecessary dynamic-programming
alignments. The structural memory improvement matters as `n²` grows, while the
worst-case caveats above still apply.

### Packed/streaming and full EarlyVir runs

`tests/prefilter_benchmark.bend` isolates candidate discovery and performs no
alignment or clustering. On the length-stratified 1,000-record sample, changing
from whole-file linked strings and per-pair histograms to streaming packed
records and cached signatures reduced one native-C run from 13.08 s / 589.30
MiB to 4.82 s / 30.75 MiB. The compact 256-bucket hash is more collision-prone,
so it deliberately retained 15,790 instead of 8,641 candidates. The independent
Python oracle matched every conservative and sketch counter on this sample.

The same executable then completed all 50,205,210 unordered pairs in the full
10,021-record, 250,720,859-base EarlyVir FASTA at 95% identity, plus strand:

| Stage | Pairs retained | Meaning |
| --- | ---: | --- |
| length compatible | 1,953,854 | exact necessary condition |
| conservative 3-mers | 1,629,369 | no false negatives from this stage |
| MinHash ≥ 8/16/24/32 bins | 6,758 / 3,029 / 1,667 / 786 | approximate cuts |
| conservative 15-mers after MinHash ≥ 8 | 6,526 | necessary, not sufficient |

The conservative-only run took 171.37 s and peaked at 222.52 MiB. The
instrumented sketch/q-gram run took 229.37 s and peaked at 227.97 MiB. The old
whole-file attempt had peaked at 5.77 GiB before publishing clusters. A real
single-linkage exact run with the new architecture was stopped after 120.01 s;
it peaked at 342.64 MiB and emitted no partial TSV. Thus the input-memory limit
is removed, while exact long-genome dynamic programming remains unresolved.

These are individual feasibility runs, not controlled compiler benchmarks.
The full counters, timings, RSS values, source hashes, and caveats are recorded
in `datasets/infant_gut_virome/results/full_prefilter_identity_0.95.run.json`.

### Full approximate clustering runs

On 2026-10-24, the explicit `--fast` mode completed all six algorithms over
all 10,021 EarlyVir records at a configured 95% threshold. The six native
single-threaded processes ran concurrently, so their wall times overlap and
are preliminary throughput measurements rather than isolated benchmarks:

| Algorithm | Wall time | Observed RSS | Approximate clusters |
| --- | ---: | ---: | ---: |
| single linkage | 219.68 s | 88.56 MiB | 7,354 |
| complete linkage | 223.42 s | 88.47 MiB | 7,906 |
| set cover | 224.15 s | 88.72 MiB | 7,549 |
| UCLUST | 286.88 s | 89.44 MiB | 7,771 |
| CD-HIT | 315.35 s | 89.48 MiB | 5,517 |
| Leiden | 350.63 s | 88.39 MiB | 7,768 |

RSS values are one concurrent-run observation, not certified peaks. Every TSV
has 10,021 ordered rows and in-range representative indices. MinHash can admit
and reject the wrong pairs, so these complete outputs are exploratory clusters,
not proofs of 95% global identity. Exact output remains the default when
`--fast` is absent. Hashes and run metadata are in
`datasets/infant_gut_virome/results/fast_clustering_identity_0.95.run.json`.

### Indexed fast-path validation

On 2026-10-25, the new inverted implementation ran single linkage over the
same complete input in 55.81 s in an isolated warm Bend-to-C run. It emitted
the exact previous 240 KiB TSV hash,
`7a0a0a0805709340f25288fee63f6aadf842151f167836b545281a03d00a30cb`.
The earlier 219.68 s result was one of six concurrent processes, so the ratio
is useful evidence that the unconditional pair walk is gone, not a controlled
fourfold speedup claim. The full 27-test C/JavaScript/kernel suite passed after
all six algorithms were connected to the index.

Two concurrent full runs completed in 58.54 s (UCLUST) and 57.81 s (CD-HIT);
another concurrent group completed in 74.95 s (complete linkage), 75.85 s
(set cover), and 198.62 s (Leiden). Each TSV was byte-identical to its
pre-index output. One late
process was observed at 430.6 MiB RSS. That is a point observation, not a peak:
the index trades Bend posting nodes for less candidate work, remains below the
1 GiB question that motivated the test, and must not be presented as the
89 MiB pre-index snapshot.
