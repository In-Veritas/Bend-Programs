# Feature request (not a bug): read a file chunk into an `Array<U32>` (bulk byte input)

## Description

Base's file input answers bytes only as cons lists: `File.read_bytes` and
`File.read_at` give `List<&2, U32>`; `File.read` and `File.read_line` give
`String` (a list of `Char`). `effs/file_read.c` packs each chunk with
`io_list`, which allocates one heap cell per byte. No effect fills an `Array`.
Simply walking a 48 MB table therefore costs ≈ 1 s, about 20× more than the
same loop in C. Effects run serially on the event loop, so parallel calls
cannot hide this. For the Vclust `cluster` stage (`Clustering/vclust_bend`),
it is about 90 % of the end-to-end time on the full EarlyVir ANI table
(Bend ≈ 2.5 s against Clusty's 0.27 s, with the clustering kernels themselves
taking milliseconds).

Wanted: e.g. `File.read_array(file, max) -> IO(File & Result<.., Array<U32> & U32>)`
(bytes into a flat array, plus the count), or a variant that fills a
caller-supplied `Array<U32>` in place. A pure parser can then index the
chunk, and split it across a fork-join or a `!` call without first walking a
list.

## Benchmark

`mre.bend` reads the file in 1 MiB chunks with `File.read_bytes` and sums
every byte; `baseline.c` does the same with `read(2)`.

```sh
. scratchpad/env.sh
bend mre.bend --check-only          # ALL PROOFS CHECK
bend mre.bend -o mre && cc -O2 baseline.c -o base_c
F=.../scratchpad/vc/full/ani12.tsv  # 47,886,704 bytes
flock bench.lock capped /usr/bin/time -f "%e s %U u %M KB" ./mre $F +RTS --threads 1 -RTS
flock bench.lock capped /usr/bin/time -f "%e s %U u %M KB" ./base_c $F
```

Output (2026-11-23, load average 6–14 from other jobs):

```
2354183224
bend 0.95 s 0.87 u 0.05 s 19580 KB      (3 runs: 0.95, 1.17, 0.95 s)
2354183224
C 0.05 s 0.01 u 2732 KB                 (3 runs: 0.05, 0.05, 0.04 s)
```

Earlier probe (same machine, quiet): about 0.5 s for the Bend read+walk.
Chunk sizes of 64 KiB, 256 KiB and 1 MiB gave the same cost.

## Environment

bend 2.0.40 (bendlang/bend 6b806192), Linux x86_64, Ubuntu clang 21.1.8.

## Workaround

None inside Base: streaming `File.read_bytes` chunks into a byte-level state
machine is the fastest path available (`vclust_bend/cl_load.bend`).
A custom C effect could fill an Array, but that is foreign code outside Bend's
guarantees, so the Vclust port does not use one.

## Hit in

`Clustering/vclust_bend/cluster.bend` / `cl_load.bend` (Clusty input stage).
Probably also the prefilter/align FASTA readers.
