# Bend common-graph kernel

This benchmark-only Bend executable reads a compact `qidx`, `ridx`, `ani` TSV
whose rows have already passed the selected ANI threshold. It clusters that
same immutable graph as the independent C baseline and Vclust's bundled
Clusty. It does not perform FASTA similarity estimation.

`CLUSTER_GRAPH_ALGORITHM` selects single (`0`), complete (`1`), UCLUST (`2`),
CD-HIT (`3`), or set-cover (`4`). `CLUSTER_GRAPH_SIZE`,
`CLUSTER_GRAPH_THRESHOLD` (six decimal fixed-point), and
`CLUSTER_GRAPH_INPUT` are required benchmark settings.

The numeric object output is mapped back to the ordered Vclust IDs by the
benchmark runner before partition hashes are compared.
