# vclust-faithful: upstream method → Bend, and what still differs

Branch `vclust-faithful` re-implements Vclust 1.3.1 with the methods, algorithms
and data structures of its three tools: Kmer-db 2.3.1 (prefilter), LZ-ANI 1.2.3
(align) and Clusty 1.2.2 (cluster). This file maps each upstream function to
the Bend function that translates it and lists every remaining deviation from
the upstream *method* with its reason. Outputs are byte-identical to Vclust on
every test (see "Equivalence" at the end); none of the deviations below
changes an output.

General, all stages (Bend's model, not choices of the port):

| upstream | Bend | why |
| --- | --- | --- |
| threads + shared mutable memory + atomics (`std::thread`, `atomic::fetch_add`, barriers, task queues) | binary fork-join (`a b = f(x) g(y)`) over owned data; data a task only reads is cloned or shared as immutable `Data` | Bend is pure and affine: a mutable `Array` has one owner; there is no way to share one between parallel tasks without `@unsafe` (`Array.fork`), which this code does not use |
| work-stealing / dynamic queues (`global_task_no.fetch_add`, `AtomicStack`, `parallel_priority_queue`) | static balanced fork-join trees | Bend's scheduler hands every task to a core once (no stealing); the decomposition (what one task does) is kept |
| `std::vector` growth (×1.5 or ×2) | new `Array<U32>` of twice the size + copy | Bend arrays have a power-of-two size fixed at creation |
| pointers into hash tables / vectors | indices (slot numbers, element ids) | no pointers in Bend |
| `double` arithmetic | exact integer / fixed-point / soft-binary64 (`pf_num`, `align_num`, `f64`) | Bend has no F64 type; each replacement is argued exact (or with a stated error bound) in the README |
| SIMD (AVX2 in LZ-ANI's `equal_len`, prefetches) | scalar code | no SIMD in Bend |
| prefetch hints | none | no effect on results |

## Prefilter: Kmer-db 2.3.1

| Kmer-db 2.3.1 | Bend |
| --- | --- |
| `GenomeInputFile::extractSubsequences` (multi-FASTA, one sample per record) | `pf_fasta.read_fasta` |
| `KmerHelper::extract` (rolling 2k-bit forward/reverse k-mers, canonical min, 8-bit prefix widening, `omit_next_n_kmers`) | `kdb_extract.ext_word` / `ext_seg` / `ext_segs`, `act` |
| `MinHashFilter::operator()`, `hash`, thresholds | `kdb_extract.filt`, `pf_num.minhash`, `pf_num.frac_threshold` |
| `KmerHelper::sortAndUnique` (`pdqsort_branchless` + `std::unique`) | `kdb_sort.sort_unique` (quicksort with median-of-3 / ninther pivots, 3-way partition, insertion sort below 24) |
| `CLoaderEx` loading threads + `BuildConsole` add loop | `kdb_build.build` / `ld_step` (extract the next chunk of samples in parallel while the current chunk is added) |
| `PrefixKmerDb::hashtables` (`vector<hash_map_lp<suffix_t, pattern_id_t>>`, one per prefix) | `kdb_db.DB.ht : Array<PT>` (2^prefix_bits slots, `PLeaf{HM}`) |
| `hash_map_lp` (`find_item`, `insert`, `fast_insert`, `reserve_for_additional`, `restruct`, `operator[]`, fill 0.8, `my_hasher_lp<uint32_t>`) | `kdb_hash.find_item`, `fast_insert`, `reserve`, `rehash`, `add` |
| `PrefixKmerDb::addKmers` | `kdb_db.add_kmers` |
| `hashtableJobATP` (per prefix: `reserve_for_additional`, `find_item`, insert new k-mers with pattern 0, samplePatterns = (pid, entry pointer)) | `kdb_db.runs(True, …)` → `leaf_find` / `la_*` |
| samplePatterns sort by pattern id (`pdqsort_branchless_tp`) | `kdb_db.sb_go` + `kdb_sort.sort2` |
| `patternJobATP` (run of pid p, `pid_count`: extend in place when `num_kmers == pid_count && !is_parent`, else `pattern_t(patterns[p], p, s, pid_count)`, parent loses `pid_count` k-mers, entries ← new id) | `kdb_db.pj_run` / `pj_dec` / `pj_ext` / `pj_new` / `mark`, then `runs(False, …)` → `leaf_write` |
| `pattern_t` (num_kmers, parent_id, num_samples, num_local_samples, last_sample_id, is_parent, Elias-gamma local samples) | 8-word record in `kdb_db.PS.pat` + node arena `PS.nod` |
| `patterns.reserve` / `resize` | `kdb_db.ps_room` / `cap_for` |
| `SimilarityCalculator::all2all_sp` | `kdb_a2a.all2all_sp` / `al_go` |
| decompress thread: `decode_pattern_samples` into `patternsBuffer_next` (cacheBufferMb = 8 → 2,000,000 ids, or 2n), bubble test `num_samples >= 8000` | `kdb_a2a.decode_chunk` / `dc_*`, `dw_go` (parent chain), `dl_go` (local samples) |
| barrier pair (workers on buffer *c* while buffer *c+1* is decoded) | `kdb_a2a.al_step`: `a b = work(wt, ch) decode_chunk(ds)` |
| worker `thread_id`: rows with `row_id % 2T ∈ {t, 2T-1-t}`, `my_js`, `row_data[pat_data[k]] += to_add` for k < j | `kdb_a2a.work` / `we_go` / `wj_go` / `kk_go` |
| `SparseMatrix<uint32_t>` rows (`hash_map_lp<uint32_t, uint32_t>`) | per worker `Array<PT>` of row tables (`kdb_hash.HM`, empty value 2^32-1) |
| `CBubbleHelper::add`, `presence1`, `get_adders` (all2all-sp and db2db-sp modes) | `kdb_a2a.dc_bub2`, `bx_of` / `bt_go` (presence), `bubbles` / `bub_ids` / `bub_cols` |
| `SparseMatrix::compact2` (adders, `CombinedFilter`, `pdqsort_branchless` by column) | `kdb_a2a.row_out` / `collect` / `row_emit` / `em_val`, filter in `em_val` / `em_ani` |
| `SparseMatrix::add_to_sampler` + `Sampler` (strategy best) + `saveRowSparse` | raw rows of `row_emit`, then `pf_sel.select` |
| `All2AllPartsConsole::run` (grid of parts, row part i: cells (i, j<i) by `db2db_sp`, diagonal by `all2all_sp`) | `kdb_parts.build_parts`, `row_part`, `cells`, `rp_diag`; `prefilter.parts_loop` |
| `deserialize(CompactedHashtables)` (`suffix_kmers` per prefix) | `kdb_parts.pr_comp` / `tab_comp` / `collect_pid` |
| `db2db_sp`: per prefix sort + merge of the suffix lists → (pid1, pid2) pairs, sort, run counts; decoded pattern pairs; workers add the count to `matrix[s1][s2]`; bubble when `n1 * n2 >= 8000²` | `kdb_parts.matchings` / `mj_*` / `counted`, `decode2` / `de_*`, `work` / `we_*` / `wj_*` |
| `DistanceConsole::run` (ani-shorter, `-min`, `common > 0`, `Double2PChar`) | `prefilter.write_out` / `blk_loop`, `kdb_a2a.em_val`, `pf_num.ani`, `kdb_util.put_entry` |
| header (`kmer-length: K fraction: F ,names,`) | `prefilter.header`, `pf_num.dec_g` |

### Remaining deviations (prefilter)

1. **No database file.** `kmer-db build` writes the database and `all2all-sp`
   reads it back (without the hash tables); here the build hands the patterns
   to all2all-sp in memory and the hash tables are dropped. With
   `--batch-size`, upstream keeps the part databases on disk; here they stay in
   memory in their compacted form (k-mer records + pattern ids + patterns).
   Reason: the files are an inter-process interface, not part of the method;
   Bend's file IO is byte lists (slow) and the stages are one process.
2. **Hash tables are created lazily.** `PrefixKmerDb::initialize` allocates all
   2^prefix_bits tables (16 slots each) upfront and `SparseMatrix::resize`
   allocates every row's table; here a prefix table / row table is created on
   its first insertion with the same initial size. Same tables afterwards.
3. **Local samples of a pattern** are a linked list of (sample, previous node)
   in one arena instead of Elias-gamma coded deltas in a per-pattern bit
   array. The same sequence is stored and decoded from the end, as
   `decodeSamples`. Reason: per-pattern growable bit arrays need shared mutable
   storage; the arena is the nearest owned structure.
4. **Pattern ids are assigned sequentially** within a sample (upstream: an
   atomic counter shared by the pattern-job threads, so ids depend on thread
   timing). Upstream's ids are not deterministic; no output depends on them.
   The pattern count is identical (e.g. 7,841 on strat1000, as `kmer-db build`
   reports).
5. **Within-sample parallelism of addKmers.** Upstream splits the sample's
   k-mers into 8T prefix-range tasks (hash-table job) and T pid-range tasks
   (pattern job) and sorts samplePatterns in parallel. Here one sample is added
   sequentially (prefix runs in order, then the sort, then the pattern runs);
   the parallelism is across samples in the loader (as upstream's loader
   threads) and in all2all-sp. Reason: the per-sample tasks share the
   samplePatterns array and the hash tables; splitting them by ownership
   would copy every sample's arrays at each fork, and the typical sample of
   the large sets (median contig 623 bp, ~600 k-mers) is far below upstream's
   own 64-k-mer-per-task granularity times the thread count. A version that
   forks the hashtables tree by prefix bits (copying the right half's records)
   was measured: same or slower on strat1000, acc30000 and acc100000, so it
   was not kept.
6. **Pointer write-back.** Upstream stores a pointer to each k-mer's hash-table
   entry and writes the new pattern id through it; here the slot index is
   stored and a second pass over the sample's prefix runs writes the ids.
7. **Sorting algorithm.** pdqsort is replaced by a quicksort with the same
   ingredients (insertion sort below 24, median-of-3/ninther pivot, partition
   grouping equal keys) but without pdqsort's pattern detection and heapsort
   fallback. Only sorted order matters for the output (keys are unique, or
   equal keys are interchangeable).
8. **Workers read a private copy of each buffer** (`Array.clone`), not the
   shared buffer: same O(T × buffer) reads.
9. **The worker count** is `-t` (default 12, the value Vclust passes in the
   reference runs) and is independent of the machine threads (`+RTS
   --threads`). Upstream ties both to `-t`.
10. **all2all-parts cells share the row tables.** Upstream gives every cell
    (row part, column part) its own SparseMatrix, compacts and filters it, and
    concatenates the cells' rows in column order; here all cells of a row
    part add into the same row tables keyed by global sample ids, compacted
    once. The columns of different cells are disjoint and the filter is per
    entry, so the rows are identical. Rows are owned by their global id
    (row mod 2T) rather than by their id inside the part. `db2db_sp`'s
    per-prefix suffix lists are one k-mer-ordered list per part, merged in one
    pass (prefixes ascending), instead of a per-prefix parallel merge.
11. **ani-shorter arithmetic**: 64-bit fixed-point `ln` instead of binary64
    `log` (kept from the previous prefilter; error < 1e-17, a printed value can
    differ only within ~1e-10 of a 6th-decimal rounding boundary — never seen).
    The sampler compares scores as exact rationals c/m instead of the binary64
    ani-shorter (equivalent unless two different rationals round to the same
    double, where upstream breaks the tie by sample index).
12. Not supported: directory input (multi-file samples), gzip, Kmer-db modes
    Vclust does not use. Prefix bits above ~24 (k ≥ 28) allocate a hashtables
    vector of 2^(2k-32) slots, like upstream (which also fails there).

## Align: LZ-ANI 1.2.3

Already a line-by-line port (README "Stage align"). Audit result:

| LZ-ANI 1.2.3 | Bend |
| --- | --- |
| `CSeqReservoir::load_multifasta`, `reorder_items` | `align.bend` reading, `ord_*` (Ordering section) |
| `CFilter::load_filter`, `reorder_items` | `align_io.bend` filter parser, `aj.go` |
| `CLZMatcher::do_matching`: a worker takes the next reference row (`global_task_no.fetch_add`), `prepare_reference` once, then `prepare_data` + `parse` + `calc_stats` for every partner of the row | one work unit per reference row (`plan.c`, `chunk` with no cut); units in a cost-balanced fork-join tree; inside a unit `align_lz` prepares the reference once and parses each partner |
| `CParser::prepare_reference`, `prepare_data`, `parse`, `compare_ranges`, `compare_ranges_both_ways`, `try_extend_forward/backward`, `calc_stats` | `align_lz.bend` (same names in comments) |
| `CLZMatcher::store_results` | `align.bend` Output rows |

Changed on this branch: the previous code cut long rows into several work
units (each re-preparing the reference) to balance the fork tree; now a unit is
exactly one LZ-ANI task (one reference row with all its partners).

### Remaining deviations (align)

1. Static cost-balanced fork-join over the row tasks instead of the dynamic
   atomic task counter (Bend has no work stealing).
2. Results are kept per pair slot and written at the end (upstream: per row in
   `results[row]`, sorted, then written): same rows, same order.
3. `equal_len` compares 2-bit symbols one by one (upstream: 8 bytes / AVX2 at a
   time); the probability test `ipow(1 - 4^-len, n)` uses exact software
   binary64; ratios are printed from exact rationals (README, align).
4. Not supported: multi-part genomes (directory input), gzip, `--out-aln`,
   mal > 16, msl > 12, aw > 32.

## Cluster: Clusty 1.2.2 (+ igraph 0.10.10 for Leiden)

| Clusty 1.2.2 | Bend |
| --- | --- |
| `GraphSparse` / `SparseMatrix` loading, `Conversions::strtod`, row sort + unique | `cl_load.bend`, `cl_graph.build_rows` / `sort_rows` / `dedup` |
| `SingleLinkageBFS` (BFS with a `std::deque` per seed, push only unassigned neighbours) | `cl_graph.single` / `flood` (FIFO queue: front list + reversed back list) |
| `linkage_algorithm_heaptrix::linkage<…, my_max>` (complete) | `cl_heaptrix.complete` |
| `element` (value, row, column, index_heap), `memory_monotonic` + `mma_buf` | `cl_heaptrix` element records (`eset`/`eget`), `alloc` with the free stack |
| `heap` (`sift_up`, `sift_down`, `make_heap`, `insert`, `remove`, `replace`) | `sift_up`, `sift_down`, `make_heap`, `h_insert`, `h_remove`, `h_replace` |
| `matrix_row_ht` (MurMur3 fmix64, linear probing, `removed` tombstones, restruct at `ht_filled == when_restruct`) | `ht_insert`, `restruct`, `ht_find`, `ht_erase`, `entries` |
| `read_matrix` / `add_value` | `rm_go` / `rm_row` / `add_value` |
| `do_clustering` (top, merged row of common neighbours with max, `replace`/`remove` + `erase`, insert the rest) | `cl_go` / `st_*`, `m1_go`, `mc_go`, `m2_go`, `ins_rev` |
| `dendrogramToAssignments` | `cl_complete.fin_loop` / `leaf_asg` |
| `UClust`, `CdHit`, `SetCover` | `cl_graph.uclust`, `greedy`, `by_degree` + `greedy` |
| Leiden (`igraph_community_leiden` and its helpers) | `cl_leiden.bend` (README, cluster) |
| `Graph::sortClustersBySize`, `GraphNumbered::print` | `cluster.bend` rendering |

Changed on this branch: complete linkage is now the heaptrix structure (it was
a lazy min-heap with dead pairs skipped on pop); single linkage is now a BFS
with a FIFO queue that pushes only unassigned neighbours (it was a DFS stack).

### Remaining deviations (cluster)

1. Complete linkage group ids start at n instead of `get_max_row() + 1`, and
   the loop bound `number_of_objects` starts at n. Both are larger than every
   object id with a row and grow by one per merge, so every key comparison is
   unchanged; the heap empties before either bound matters.
2. The second loop of the merged-row construction (columns of c absent from r)
   is not run: for complete linkage `my_max(MAX_DOUBLE, d) = MAX_DOUBLE` and
   such entries are always dropped; the loop has no other effect.
3. UCLUST's `seeds2clusters` (`unordered_map`) is an array indexed by object.
4. The stages run sequentially (as Clusty does); Leiden is the bit-exact port
   described in the README.

## Equivalence

All on this branch, 2026-11-27/28, 12 threads:

- `~/vclust-work/check.sh ~/Bend-Programs-faithful` (prefilter + 3 option sets on
  the small sets, align, cluster with 8 algorithm/threshold combos):

  ```
  vclust_example: prefilter=ok align=ok cluster=ok (2s)
  wtdbg2_viral: prefilter=ok align=ok cluster=ok (8s)
  canu_viral: prefilter=ok align=ok cluster=ok (20s)
  strat1000: prefilter=ok align=ok cluster=ok (33s)
  acc1000: prefilter=ok align=ok cluster=ok (2s)
  acc10000: prefilter=ok align=ok cluster=ok (7s)
  acc30000: prefilter=ok align=ok cluster=ok (29s)
  acc100000: prefilter=ok align=ok cluster=ok (236s)
  acc323556: prefilter=ok align=ok cluster=ok (751s)
  ```
- `tests/test_prefilter.py`: 60/60 identical (k 15/16/19, kmers-fraction,
  max-seqs 1/3/5/50, batch-size 300, min-kmers 0/1 with min-ident 0, and the
  Bend-only `--bubble-size 2/3` and `-t 1/5`, which must give the plain run).
- `tests/fuzz_prefilter.py --cases 15 --seed 1`: 150/150 identical (random
  families of mutated copies, duplicates, repeats, N runs, IUPAC/lowercase,
  records shorter than k, empty records; 10 option sets each, incl. bubbles,
  batch parts and worker counts).
- `--bubble-size 2` / `7` with and without `--batch-size 300` / `--max-seqs 50` on
  vclust_example, strat1000, acc1000: 18/18 equal to the Vclust output.
- `tests/test_cluster.py`: 368/368 identical (now including 200 random graphs
  with heavily tied distances for complete / single / uclust / cd-hit /
  set-cover).
- `tests/test_align.py`: 14/14 identical.

Timings (single runs, `/usr/bin/time`, bench lock held, but other agents'
jobs were sometimes running outside the lock; treat as indicative):

| set | stage | Vclust 1.3.1 | this branch |
| --- | --- | ---: | ---: |
| strat1000 | prefilter | 5.87 s | 5.4 s / 976 MB |
| acc30000 | prefilter | 28.2 s / 535 MB | 7.2 s / 933 MB |
| acc100000 | prefilter | 191 s / 1.3 GB | 25.9 s / 2.07 GB |
| acc323556 | prefilter | 31.5 s / 3.5 GB (coordinator, hyperfine) | 75.6 s / 5.04 GB |
| acc100000 | align | 11.2 s | 59.7 s (old per-chunk units: 57.8 s, same minute) |
| acc323556 | cluster complete 0.95 | — | 32.4 s, kernel 3.3 s (old lazy heap: 32.5 s, kernel 2.5 s) |
| acc323556 | cluster single 0.95 | — | 27.8 s, kernel 0.75 s (old DFS: 27.8 s, kernel 0.55 s) |

On the full set the prefilter time is almost all `build`: a PF_TIME run
(contended, 161 s total) gave read 6.6 s, build 142.7 s, all2all-sp 1.5 s,
compact + distance + write 10.0 s — 323,556 samples added one by one, as
Kmer-db does, each with its own per-sample sequential work.
