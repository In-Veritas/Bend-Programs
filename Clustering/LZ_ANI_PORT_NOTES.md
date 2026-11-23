# LZ-ANI port notes

This log records implementation defects and behavioral risks in the clustering
application. They are deliberately **not** Bend `unexpected_behavior` reports:
none of these observations is attributable to the Bend parser, checker,
compiler, runtime, or backend.

## Fixed during differential testing

### Long-anchor result was not reclassified as close

The first indexed parser preserved whether an anchor came from the long-anchor
or nearby-seed table. Upstream instead classifies the *selected* factor as
close whenever its final reference position is within 40 bases of the predicted
position, regardless of which table found it. The old behavior discarded five
valid reverse-direction regions in the nine-record fixture. The parser now
reclassifies after selection; all 72 directed fixture rows match LZ-ANI 1.2.3.

### Overlapping reference gaps scanned too many symbols

The first gap scorer optimized over the complete pending query gap. Upstream
limits the two-sided scan when the previous predicted reference interval and
the new anchor overlap, leaving the overlap-induced middle as literals. The old
behavior counted one extra match for one of 272 generated directed comparisons.
The indexed scorer now computes the upstream `to_scan` boundary and uses the
latest split on ties. All 272 generated rows and the 72 focused rows match.

### Backward extension was initially absent

A distant anchor can invalidate a preceding region shorter than 35 bases.
Upstream converts that region to pending literals and attempts a rolling-window
extension backwards from the new anchor. Omitting this step can lose a region
that should be joined to the new anchor. The indexed parser now implements the
same 15-base window, seven-mismatch bound, and final three-match run in both
directions.

## Open risks and missing behavior

- Bend Core exposes F32 rather than upstream's binary64 calculation. The
  close/distant probability comparison uses three negative-log series terms
  and the binary64 subtraction cutoff at factor length 27. The 344-row
  differential suite passes, but this is not a proof of identical choices for
  every geometry.
- Kmer-db computes `ani-shorter` in binary64 while the Bend filter uses F32.
  Candidate pairs and exact common-k-mer counts match the official 2.3.1
  differential fixture at the default 0.70 threshold, but a value extremely
  close to a configured cutoff could round to a different side.
- The canonical 25-mer prefilter stores every unique `(k-mer, sample)` posting
  in memory. It removes exhaustive pair discovery and LZ scoring keeps only two
  reference indexes resident, but there is no multipart/on-disk posting batch
  yet. The 2.9 MB shortest-1,000 EarlyVir sample completed candidate discovery
  in 6.71 s and retained 103,754 unordered pairs. The 25.5 MB
  length-stratified 1,000 sample had not completed after 120 s and was stopped;
  this linked-posting implementation is therefore not ready to claim full
  EarlyVir scalability.
- K-mer sampling, multipart samples, on-disk batches, candidate caps, and independent
  ANI/gANI/query-coverage/reference-coverage filters are not implemented.
- No full EarlyVir `--lz-ani` timing or memory result exists yet. Existing
  whole-dataset figures belong to the separate MinHash mode.

## Validation commands

Last re-run on 2026-11-23 with Bend 2.0.40
(`6b806192284fc9c64404d9b0b59c937f568d87ec`, Linux x86_64). The native C and
JavaScript fixture test passed, and `lz_ani.bend` all-to-all output was
identical on both backends. The comparisons against the official binaries were
skipped because Vclust 1.3.1 was not installed. The proof-kernel checks could
not run because Lean was not installed; `--check-only` passes.

```sh
python3 Clustering/tests/test_lz_ani_numeric.py
python3 Clustering/tests/test_kmer_db.py
python3 Clustering/tests/test_clustering.py
```

The first command compares native C and generated JavaScript with official
LZ-ANI 1.2.3 on 344 directed rows and checks the small proof kernel. The middle
command compares canonical candidate pairs and exact shared 25-mer counts with
Kmer-db 2.3.1 in both backends and checks the sparse-omission proof. The last
checks all six clusterizers and both backends, including explicit tANI graph
mode.
