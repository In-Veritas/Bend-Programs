# Independent C clustering baseline

This directory is an independent C11 implementation of clustering over a
Vclust complete-format ANI table. It does not include, import, generate from,
or translate the Bend implementation.

The input contract is deliberately shared with Vclust/Clusty so the clustering
kernel benchmark can use exactly the same graph:

```sh
make
./cluster_graph \
  --input ani.tsv \
  --ids ani.ids.tsv \
  --output clusters.tsv \
  --algorithm single \
  --metric ani \
  --threshold 0.95 \
  --threads 1
```

Algorithms: `single`, `complete`, `uclust`, `cd-hit`, `set-cover`, and
`leiden`. The first five have deterministic tie breaking. The Leiden entry is
currently a deterministic Constant Potts Model local-moving baseline with a
connected-community refinement; it is kept out of accepted Vclust comparisons
until membership validation establishes equivalence for the selected settings.
Set-cover follows Clusty's MMseqs mode-0 behavior: sort once by initial graph
degree, preserving input order for ties, then assign each still-unassigned
seed's unassigned neighbors. It does not recompute residual degrees.

Storage is sparse `O(N + E)`. The program never allocates an `N × N` matrix.
`--threads` is accepted and reported now so the benchmark interface is stable;
the current clustering kernels are single-threaded. Parallel FASTA-to-graph
construction will be a separate stage, since claiming thread scaling for a
serial kernel would be misleading.
