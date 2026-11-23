# EarlyVir infant gut virome

Public data associated with Shah et al., *Expanding known viral diversity in
the healthy infant gut*, Nature Microbiology 8, 986–998 (2023),
[doi:10.1038/s41564-023-01345-7](https://doi.org/10.1038/s41564-023-01345-7),
PubMed [37037943](https://pubmed.ncbi.nlm.nih.gov/37037943/).

The paper reports 362,668 species-level OTUs in its virus-discovery benchmark,
not 362,669 reference viral genomes. That benchmark includes the non-viral
sequence clusters. The openly published, taxonomically curated sequence set
contains 10,021 viral OTUs from faecal viromes of 647 one-year-old children.
It contains 248 virus family-level clades, with host predictions for most
phages.

## Official files

Figshare item [21102805 version 2](https://doi.org/10.6084/m9.figshare.21102805.v2)
is licensed CC BY 4.0. `download.sh` retrieves and verifies all three files
listed by the public Figshare API:

| File | Bytes | Publisher MD5 | Purpose |
| --- | ---: | --- | --- |
| `all.curated.vOTUs.EarlyVir.fna` | 255,006,683 | `c981d0450bead795491dc3db8c06ce49` | 10,021 curated viral genome sequences |
| `taxtable.tsv` | 1,638,731 | `9ea2c77f8576116a90700a6b2cf1d5c3` | Taxonomy, host and genome annotations |
| `fig1.svg` | 1,178,204 | `db9d0f4f958cc9744b2b9a81caae8f3d` | Interactive family-level atlas |

The downloaded files and Figshare API metadata are stored under `raw/`. That
directory is intentionally ignored by Git because the FASTA exceeds GitHub's
ordinary 100 MiB per-file limit. Reproduce it from this directory with:

```sh
./download.sh
```

## Local validation

Downloaded and validated on 2026-10-19. The FASTA has 10,021 unique record
identifiers, 250,720,859 nucleotide bases, a length range of 1,022–266,223
bases, and no sequence characters outside the uppercase IUPAC nucleotide
alphabet. The taxonomy file has exactly 10,021 rows of 23 tab-separated fields
and no header. Every taxonomy identifier maps to exactly one FASTA record and
vice versa. `manifest.json` records sizes, publisher MD5 values, locally
calculated SHA-256 values, and these structural checks.

The article also names `http://copsac.com/earlyvir/f1y/benchmark.tsv` as the
benchmark table containing non-viral clusters. On 2026-10-19 that legacy host
returned HTTP 455 to both HTTP and HTTPS requests. The Figshare record does not
list a FASTA containing all 362,668 benchmark OTUs. The study's raw FASTQ reads
are a different, much larger resource under ENA project `PRJEB46943` and are
not downloaded here.

## Using it with this clustering suite

The production limits were raised to 16,384 records, 300,000 bases per record,
and 256 MiB after replacing the packed 16-bit alignment score with independent
U32 edit and match fields. The complete EarlyVir FASTA now passes those bounds.
The shared stable length sort was also changed from insertion sort to a
bottom-up merge sort. These changes remove representation and sorting blockers;
they do not remove the exact default path's pairwise candidate/alignment time.
The separate explicit fast path now has an inverted MinHash index.

Before the 2026-10-22 streaming/packing integration, both complete-file CD-HIT
and UCLUST attempts on this 16 GB Apple M4 loaded the data and stabilized at
about 6.05 GB RSS (5.77 GiB),
with one CPU core saturated. CD-HIT still produced no partial result after
several minutes. Its 16-shortest smoke input took 16.8 seconds for only 120
candidate pairs; extrapolating that short-input cost to the 50,205,210
worst-case pairs is about 81 days, before accounting for the much longer mean
genome. UCLUST reached exhaustive alignment: its first two length-sorted
genomes alone require 113,832,162,786 DP-cell evaluations across both strands.
The complete attempts were therefore stopped without publishing misleading
partial cluster files. This is an application scalability limit, not a Bend
compiler/runtime issue.

### Reproducible smoke-test subset

`prepare_subset.py` creates `ready/earlyvir_shortest16.fasta` by selecting the
16 shortest whole genomes whose declared and observed lengths agree. The
30,000-base selection ceiling is retained to keep this smoke test quick, not as
a production parser limit. Ties use the OTU identifier. It also writes a manifest
with every selected source identifier and length:

```sh
python3 prepare_subset.py
```

This subset is intentionally biased toward short genomes. It exists to confirm
that the downloaded EarlyVir records pass through the Bend clustering program;
it is not representative of EarlyVir diversity and must not be used for
biological conclusions.

For scalability measurements, `--selection stratified` selects evenly spaced
positions from the declared-length ordering. The checked 1,000-record sample
spans the complete EarlyVir length distribution instead of favoring short
records:

```sh
python3 prepare_subset.py --selection stratified --count 1000 --max-length 300000
```

The original standalone prefilter visited all 499,500 unordered pairs in this
25,133,250-base sample at 95% global identity in 13.08 seconds and 589.30 MiB
RSS. After incremental parsing, packed sequences, and cached signatures, the
same sample took 4.82 seconds and 30.75 MiB. The compact hash intentionally
retained more false positives: 15,790 rather than 8,641. The independent
`tests/prefilter_reference.py` oracle reproduced the new conservative and
sketch counters exactly.

### Completed full-dataset prefilter

The native-C instrumentation completed all 50,205,210 unordered pairs in the
complete 10,021-record FASTA at 95% identity, plus strand. Of those pairs,
48,251,356 failed the necessary length bound, another 324,485 failed the
conservative 3-mer bound, and 1,629,369 remained as exact-alignment candidates.
The conservative pass took 171.37 seconds and peaked at 222.52 MiB RSS.

The optional approximate 64-bin MinHash retained 6,758 pairs at an eight-bin
cut; a subsequent conservative 15-mer bound retained 6,526. The fully
instrumented run took 229.37 seconds and 227.97 MiB. These are candidate
counts, not confirmed clusters: MinHash can have false negatives, and passing a
q-gram lower bound does not prove 95% identity. A real exact single-linkage run
was stopped after 120.01 seconds with 342.64 MiB RSS and no partial TSV. Full
input memory is therefore solved, while exact global alignment remains the
runtime blocker. Metadata and source hashes are in
`results/full_prefilter_identity_0.95.run.json`; the earlier representation
baseline remains in `results/prefilter_identity_0.95.run.json`.

### Completed full-dataset approximate clustering

The explicit `--fast` mode uses the conservative length and hashed 3-mer gates,
then scores long-sequence survivors with the cached 64-bin 15-mer MinHash
instead of global dynamic programming. All six native-C algorithms completed
the complete dataset at a configured 95% threshold:

| Algorithm | Concurrent wall time | Observed RSS | Approximate clusters |
| --- | ---: | ---: | ---: |
| single linkage | 219.68 s | 88.56 MiB | 7,354 |
| complete linkage | 223.42 s | 88.47 MiB | 7,906 |
| set cover | 224.15 s | 88.72 MiB | 7,549 |
| UCLUST | 286.88 s | 89.44 MiB | 7,771 |
| CD-HIT | 315.35 s | 89.48 MiB | 5,517 |
| Leiden | 350.63 s | 88.39 MiB | 7,768 |

The processes ran concurrently with one thread each, so times overlap; RSS is
an observed snapshot rather than a certified peak. Every output contains all
10,021 records in input order with valid representative indices. These results
are complete over the input but approximate in similarity semantics: MinHash
can produce false positives and false negatives. The six TSVs and their hashes
are under `results/`; full metadata is in
`results/fast_clustering_identity_0.95.run.json`.

### Indexed full-dataset approximate clustering

On 2026-10-25 the plus-strand fast path was changed from an unconditional pair
walk to a Bend-owned inverted table over exact `(MinHash bin, value)` entries.
All six complete outputs remained byte-identical to the preceding TSVs:

| Algorithm | Indexed wall time | Run group | Output hash preserved |
| --- | ---: | --- | --- |
| single linkage | 55.81 s | isolated warm run | yes |
| UCLUST | 58.54 s | concurrent with CD-HIT | yes |
| CD-HIT | 57.81 s | concurrent with UCLUST | yes |
| complete linkage | 74.95 s | concurrent three-process group | yes |
| set cover | 75.85 s | concurrent three-process group | yes |
| Leiden | 198.62 s | concurrent three-process group | yes |

One late process was observed at 430.6 MiB RSS. This is not a certified peak;
the recursive Bend posting representation trades additional memory for much
less candidate work. The run stayed below 1 GiB. Timings from different run
groups are not a controlled scaling comparison.

The pure score module passes Bend's proven `--verdict` kernel for two universal
laws: indexed scoring is the canonical fast score for every counter/population/
threshold input, and zero common entries always score zero. Those laws justify
omitting pairs absent from the index; they do not prove MinHash is ANI. Full
metadata is in `results/indexed_fast_clustering_identity_0.95.run.json`.

### Completed Bend smoke runs

The native C backend completed CD-HIT and UCLUST with Bend compiler revision
`87355989791e12e0f29026ea1f65dc344290c24c`:

```sh
mkdir -p datasets/infant_gut_virome/results
python3 run.py cd-hit \
  datasets/infant_gut_virome/ready/earlyvir_shortest16.fasta \
  --identity 0.90 --strand both --backend c \
  --output datasets/infant_gut_virome/results/cd_hit_identity_0.90.tsv \
  --representatives \
    datasets/infant_gut_virome/results/cd_hit_identity_0.90.representatives.fasta

python3 run.py uclust \
  datasets/infant_gut_virome/ready/earlyvir_shortest16.fasta \
  --identity 0.90 --strand both --backend c \
  --output datasets/infant_gut_virome/results/uclust_identity_0.90.tsv \
  --representatives \
    datasets/infant_gut_virome/results/uclust_identity_0.90.representatives.fasta
```

Both algorithms placed all 16 records in singleton clusters at 90% identity.
Their TSV files are byte-identical, and both representative FASTAs are
byte-identical to the input. This is a successful smoke execution, not evidence
that the records are broadly unrelated at lower thresholds or under other
similarity definitions. Run metadata and output hashes are under `results/`.

The launcher's named-output mode currently requires its parent directory to
exist. If `results/` is absent it exits before building or running Bend. This is
an ordinary launcher UX limitation and is not recorded as unexpected Bend
behavior.

## Attribution

Shah, S. A. et al. Expanding known viral diversity in the healthy infant gut.
*Nature Microbiology* **8**, 986–998 (2023). Dataset: *Atlas of infant gut DNA
virus diversity with taxonomy and curated sequences*, Figshare,
[doi:10.6084/m9.figshare.21102805.v2](https://doi.org/10.6084/m9.figshare.21102805.v2),
CC BY 4.0.
