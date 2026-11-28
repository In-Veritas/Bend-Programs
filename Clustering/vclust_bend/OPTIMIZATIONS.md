# Optimizations on branch `vclust-optimized`

Every stage keeps its CLI and its output: each change below is byte-identical
to Vclust 1.3.1 on `~/vclust-work/check.sh` (all sets, including acc100000 and
acc323556), the repo suites and the differential fuzzer `tests/fuzz_vclust.py`. Each entry
says why the output cannot change and what it measured (wall time / max RSS,
12 threads, same minute, bench lock held unless noted).

## Prefilter

### P1. Sparse pair counts instead of the dense triangle

Before: every shared k-mer added 1 to a dense lower-triangular U32 matrix of
n(n-1)/2 cells (1.8 GB at 30k, 21 GB at 100k; n <= 92,681 without
`--batch-size`). Now the rows of a batch are cut into R = 2^lr blocks of
h = ceil(rows / R) consecutive rows, a pair a < b of row b gets the block-local
code (b - r0) * n + a (lr is chosen so h * n < 2^32), and each block owns an
open-addressing hash table (linear probing, load <= 1/2, grown by rehash)
from code to count. At the end a block's (code, count) records are radix-sorted
(3 x 11-bit LSD passes) and walked from the end, producing the rows of the
block with entries in ascending a.

Why the output is unchanged: the table is a finite map holding exactly the
non-zero cells of the old matrix (the same increments, in any order:
addition is commutative), and a missing code is a zero cell, which the old
final scan never printed (it required c > 0 and c >= min-kmers). The sorted
walk visits, for every row b, exactly the non-zero cells of row b in
ascending a, i.e. the old scan's output order restricted to the cells it
could print; the formatting and filters are the same functions.

Memory now scales with the number of sample pairs sharing a k-mer (7.6 M for
the full 323,556-contig set, measured with a C counter) instead of n^2.

### P2. Sample chunks in the leaves of the sample tree

Before: one tree leaf per sample, each with a P x Q bucket-count array and Q
per-pass group arrays: for 323k samples, 2.6 GB of counts and 20.7 M tiny
arrays per pass (x 32 passes). Now a leaf holds a chunk of consecutive
samples (at most 2^10 leaves), extracts them one after the other into one
array per pass, with 3-word records (hi, lo, sample) so the sample travels
with the k-mer.

Why the output is unchanged: within a group the records are still gathered
in ascending sample order (chunks ascend, samples ascend within a chunk), so
the stable sort still leaves equal k-mers in sample order, and the per-sample
deduplication/pair emission sees the same sequences.

| set | before | after P1 | after P1+P2 | Vclust 1.3.1 |
|---|---|---|---|---|
| acc30000 | 2.13 s / 2.59 GB | 2.00 s / 497 MB | 1.73 s / 488 MB | 28.2 s / 535 MB |
| acc100000 | OOM (> 9 GB) | 15.4 s / 1.09 GB | 7.5 s / 783 MB | 191 s / 1.3 GB |
| acc323556 | OOM (> 9 GB) | 219 s / 4.87 GB | 31.0 s / 1.63 GB | 293 s / 3.5 GB |

(First table: single runs, heavy lock, other agent active.)

### P3. Parallel FASTA parsing

Before: the file was streamed through one per-byte state machine (about 8 s of
the full set's 31 s). Now 1 MiB chunks are read in batches of 12 and parsed
by fork-join. A split point is a '>' right after a '\n'; a chunk is cut at
its first (index >= 1) and last split points, its body is parsed with a fresh
parser state and closed with the end-of-input rule, and the bytes before the
first / after the last split point join the neighbouring chunks' pieces, which
are parsed (also from a fresh state) in order.

Why the output is unchanged: just before a split point the sequential parser
is in mode 0 or 3 (a '\n' always ends a header line), so the '>' either
closes the open record and opens a header (mode 3) or just opens a header
(mode 0); the piece before the split point ends with the same close
(`final_m`), and the state after closing a record differs from a fresh one
only in buffer words that are always written before being read. The record
lists of the pieces are concatenated in file order. Each piece's packing
buffer is sized from its byte count (> words any record of it can need), so
the old 4 M-word record limit is gone too.

### P4. 128 groups per pass, 2^25 bases per pass

The passes re-extract every k-mer of every sample (only 1/P are kept), so
fewer passes save extraction; doubling the groups instead of the group size
keeps the per-group sort and scan cache-friendly. Any partition of the k-mer
hash space into passes x groups gives the same counts (every k-mer lands in
exactly one group, and the sample order within a group is unchanged).
Interleaved A/B on acc323556 (load 8-11 from the other agent, so wall times
are noisy; user CPU is the steadier figure): 2^24 x 64: 36.6 / 31.7 s, 261 /
243 s user, 1.89 GB; 2^25 x 128: 30.8 / 29.1 s, 222 / 214 s user, 2.26 GB;
2^26 x 256: 27.8 s, 206 s user, 3.0 GB (rejected: memory).

## Cluster

### C1. Parallel chunked parsing of the distance table

Before: the table was streamed in 1 MiB byte lists through one per-byte
state machine (23 s of 30 s on the full set). Now chunks of 512 KiB are read
in batches of 24 and the chunks of a batch are parsed by fork-join. A chunk's
bytes before its first newline (head) and after its last one (tail) are kept
aside; between consecutive bodies the line tail(i) ++ head(i+1) is parsed in
order. Accepted rows keep their global ids; local ids are assigned after
parsing by one pass over the accepted rows in file order (`L.map_edges`).

Why the output is unchanged: after every newline the row parser is in its
initial per-line state (all per-line fields are reset by the row end or were
never set on an empty line), so a body parsed from a fresh state produces the
same rows as the sequential parse; the only cross-line state is the error
bits (OR-ed: commutative) and the local id map, which is now built in exactly
the sequential order (query, then reference, for each accepted row in file
order). Lines are split only at bytes that are newlines for the parser
('\n' and '\r'), so every line is parsed whole, once.

### C2. Linear-time rendering

Before: rendering sorted the (cluster, id) pairs and the cluster sizes with
`List.sort` and built the text reversed, then reversed it. Now: cluster sizes
are counted, renumbered by a stable counting sort on nloc - size (decreasing
size, ties by old id, as Clusty's stable sort), the in-matrix objects are
placed by a counting sort on the new cluster while scanning ids in ascending
order (so each cluster lists its members by ids position, and the first one
placed is the representative), and the text is built from the last line to
the first so the byte list comes out in order.

Why the output is unchanged: both counting sorts are stable sorts on the same
keys as the comparison sorts they replace, so they produce the same orders.

## Align

Phase profile before (ALIGN_TIMING=1, 12 threads, acc100000): FASTA 2.9 s,
filter 2.8 s, plan + alignment 13.8 s, writing ani.tsv 26.1 s (45.6 s
total). The sequential parts, not the LZ parser, dominated at scale:
formatting 1.35 M rows of exact decimal ratios was single-threaded.

### A1. Parallel FASTA reading

Same scheme as P3 on the align reader (`R.fs_byte`, line oriented): split
points are '>' right after '\n'; there the reader is always in mode 0 with no
pending '\r' and an empty header, so a fresh reader started there, with the
previous piece closed by `R.fs_done`, yields the same records. Each piece is
given the byte budget left before the file's last '\n' from its own start
offset, so the rule "an unterminated last line is ignored" is kept.

### A2. Parallel filter reading

After every '\n' the filter row parser is in its initial per-line state;
only the row counter and the pair list carry over. Chunks are cut after their
first and last '\n'; each body is parsed from a fresh row state with rows
counted from 0, and the stretches are merged in file order with their rows
shifted by the rows before them, giving exactly the sequential pair list
(same order). The first stretch, which holds the header line, goes through
the initial (header) state; the open piece at the end goes through
`R.fl_done` as before.

### A3. Parallel row formatting

The values of each pair are read from the result arrays in pair order
(sequential and cheap), then chunks of 1024 pairs are formatted by fork-join,
24 chunks per batch, and written in order. Every pair yields the same two
rows through the same `row` function; only the evaluation order changes.
