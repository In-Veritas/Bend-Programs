# Clustering benchmark

This benchmark compares three implementations:

1. Bend source compiled to a native C executable;
2. an independent C11 implementation under `../c_baseline/`; and
3. Vclust 1.3.1, whose clustering stage is Clusty 1.2.2.

The version and commands are pinned because performance data without an exact
toolchain is not reproducible. Install Vclust locally with:

```sh
./install_vclust.sh
../.tools/vclust-1.3.1/bin/vclust info
```

The local environment is ignored by Git.

## Validity boundary

There are two separate benchmark tracks. They must not be merged into one
ranking.

### Common-graph clustering kernel

Vclust `prefilter` and `align` produce one complete-format ANI table and its
`.ids.tsv` file. Bend, C, and Vclust/Clusty receive those same immutable files,
the same metric and the same threshold. Cluster memberships are normalized and
compared before performance is accepted. This is the apples-to-apples algorithm
benchmark.

`prepare_common_graph.py` filters the complete ANI table once into a compact
three-column graph. All three implementations then parse the same graph, so
ANI filtering and unused alignment columns do not distort kernel time or
memory.

### End-to-end tool pipeline

Each tool reads the same FASTA and writes clusters. This measures practical
throughput, but it is not automatically the same computation: Vclust uses
Kmer-db and LZ-ANI, while the current Bend `--fast` mode uses an approximate
MinHash score. End-to-end results therefore remain a tool comparison unless a
separate equivalence check succeeds.

## Measurements

Every accepted cell records:

- wall, user, and system time;
- maximum resident memory;
- requested and effective thread count;
- output hash and normalized membership hash;
- tool/compiler revision and full command; and
- energy source and joules, or an explicit `unavailable` value.

Thread counts are tested independently; the initial matrix is `1, 2, 4, 8`.
Vclust's `prefilter` and `align` accept `--threads`; its `cluster` command does
not. The bundled Clusty 1.2.2 binary has an undocumented `-t` option, but clamps
the effective count to at least four threads. The independent C kernels are
currently serial. Requested and effective counts are therefore both retained;
a component is not credited with artificial scaling.

Run the validated common-graph matrix with:

```sh
python3 run_common_graph_matrix.py \
  --ani /path/to/graph.ani.tsv \
  --ids /path/to/graph.ani.ids.tsv \
  --output results/common-graph.json \
  --threads 1 2 4 8 \
  --repeats 3
```

This runner aborts if the C and Clusty partitions differ. Leiden is excluded
until the independent implementation matches the pinned igraph behavior. Bend
is compiled to C with `-O2` and included by default; `--without-bend` is only
for focused harness diagnostics.

The current 1,000-sequence validation is recorded in
`results/common_graph_stratified1000.validation.json`. Single, complete,
UCLUST, CD-HIT, and set-cover have identical normalized memberships. The
independent Leiden prototype does not, so it is not an accepted comparison.
The timing matrix is retained for harness validation, but this 5,426-edge graph
finishes in milliseconds and is too small for a meaningful C-versus-Clusty
performance conclusion.

### Full EarlyVir common graph

The larger accepted matrix uses all 10,021 EarlyVir references. Vclust emitted
570,306 ANI rows; at ANI 0.95 there were 17,112 qualifying directional rows.
`prepare_common_graph.py` consolidated asymmetric duplicates by unordered pair,
keeping the maximum similarity, leaving 10,700 edges. Bend-to-C, independent C,
and Clusty produced identical normalized partitions for all five accepted
algorithms in all 60 implementation-independent cells.

Median kernel results at the one-thread request are below. Clusty actually uses
at least four threads; the other two entries are single-worker computations.

| Algorithm | Bend→C time / RSS | C11 time / RSS | Clusty time / RSS |
| --- | ---: | ---: | ---: |
| Single | 14.15 ms / 3.78 MiB | 4.59 ms / 2.41 MiB | 16.06 ms / 133.39 MiB |
| Complete | 3.712 s / 3.83 MiB | 341.86 ms / 3.05 MiB | 18.00 ms / 134.03 MiB |
| UCLUST | 2.202 s / 3.84 MiB | 31.45 ms / 2.44 MiB | 15.88 ms / 134.02 MiB |
| CD-HIT | 1.680 s / 3.84 MiB | 23.31 ms / 2.44 MiB | 15.97 ms / 133.41 MiB |
| Set cover | 33.58 ms / 5.22 MiB | 4.71 ms / 2.48 MiB | 15.95 ms / 133.41 MiB |

These are clustering-kernel results, not FASTA-to-clusters totals. Requested
thread counts 1, 2, 4, and 8 did not materially change any kernel time: the C11
kernels are serial, the Bend kernels contain no explicit parallel form, and
Clusty's extra graph-loading workers do not help this compact graph. Full runs,
commands, hashes, and all repetitions are in
`results/common_graph_full.three_way.matrix.json`.

The one-shot full Vclust frontend feasibility run is recorded separately:
prefilter took 7.81 s and 2.37 GiB RSS; alignment took 27.01 s and 586 MiB RSS,
both with eight threads. Those two values are not three-repeat benchmark
medians and are not merged with the kernel table.

Run the Vclust prefilter/alignment scaling matrix separately:

```sh
python3 run_vclust_frontend_matrix.py \
  --fasta /path/to/input.fasta \
  --output results/vclust-frontend.json \
  --threads 1 2 4 8 \
  --repeats 3
```

`results/vclust_stratified1000_threads.matrix.json` contains three repetitions
per cell on the same 1,000-sequence FASTA. Its canonical filter, ANI, and IDs
hashes are identical across every run and thread count.

On macOS, `powermetrics` reports estimated whole-system subsystem power and
requires elevated privileges. The harness will integrate its CPU-power samples
and label them as estimated system CPU joules. The value is not process energy
and is not comparable across different machines. If permission is unavailable,
the benchmark records energy as unavailable; elapsed time is never converted
into invented energy. Run `sudo -v` immediately before an energy-enabled matrix
so the harness's non-interactive `sudo -n` invocation can start `powermetrics`.

## Fixed versions

- Vclust: 1.3.1, Git tag `d253a1af99db11afab8483ea2ce06e9e276784d6`
- Kmer-db: 2.3.1
- LZ-ANI: 1.2.3
- Clusty: 1.2.2 (`b687638`)
- mfasta: 1.0.4

The Bend revision and C compiler identity are captured at benchmark execution
time because both are active development toolchains.
