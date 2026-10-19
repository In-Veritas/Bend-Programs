# Public viral FASTA datasets

Downloaded on 2026-10-15. Original downloads are preserved byte-for-byte under
`original/`; smaller derived inputs are under `ready/`. All files contain
nucleotide sequences, and all downloaded bases validated as A/C/G/T.

## Original downloads

| File | Records | Length range (bases) | Download size |
| --- | ---: | ---: | ---: |
| `original/canu_viral.fasta` | 767 | 1,909–180,278 | 15,167,392 bytes |
| `original/wtdbg2_viral.fasta` | 209 | 4,913–131,960 | 6,539,512 bytes |
| `original/vclust_example.fasta` | 12 | 38,815–64,164 | 586,070 bytes |

The first two are real gut-virome contig collections from different assemblers,
drawn from a study of 95 virus-like-particle-enriched fecal samples. They are
collections across samples, not two individual sample viromes. Attribution:
Wei-Hua Chen, **Viral contigs of Virome Benchmark**, Figshare v1 (2024),
[doi:10.6084/m9.figshare.25060193.v1](https://doi.org/10.6084/m9.figshare.25060193.v1),
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Related paper: Wang et al.,
[Complementary insights into gut viral genomes](https://doi.org/10.1186/s40168-024-01981-z).
The publisher's MD5 checksums matched both downloads.

The source reports prior CD-HIT dereplication at 99% identity before viral
identification. These are useful biological inputs, but substantial further
reduction is not guaranteed. None of the three originals contains identical
full-sequence records.

The third is the [Vclust example](https://github.com/refresh-bio/vclust/tree/59b350c87428540ed9290701ae376c98dd1cfb2e/example):
bacteriophage references plus simulated substitutions, insertions, deletions,
duplications, inversions, and translocations. It is a semi-synthetic benchmark,
not a natural virome. Its repository declares GPL-3.0; no separate example-data
license was identified. The original description is saved in
`vclust_example_description.txt`.

## Inputs for the current suite

| File under `ready/` | Records | Length range | Preparation |
| --- | ---: | ---: | --- |
| `canu_viral_short8.fasta` | 8 | 1,909–3,162 | Eight shortest whole contigs |
| `wtdbg2_viral_short8.fasta` | 8 | 4,913–5,966 | Eight shortest whole contigs |
| `vclust_example_prefix1000.fasta` | 12 | 1,000 | First 1,000 bases of each Vclust record |

The virome subsets preserve original headers and complete sequences, ordered
as in the source. Selection ties use original record index. Only line wrapping
changes. These deliberately small, length-biased subsets are for exercising
the programs; they do not represent the biological diversity of the study.

The Vclust fragment file preserves each identifier but replaces the remaining
header with fragment coordinates and original length. Its clustering results
describe those fragments, not whole-genome relatedness. Source tANI annotations
do not apply to these fragments and were removed from their headers.

Every original contains records above the suite's 30,000-base limit, so the
originals cannot be passed directly to the current algorithms. All `ready/`
files fit the limits. Full dynamic-programming alignment can still make even
these small virome subsets noticeably slower than the 1,000-base example.

From the clustering package directory:

```sh
# Start with the small phage-fragment example.
python3 run.py single-linkage datasets/public_viromes/ready/vclust_example_prefix1000.fasta \
  --identity 0.95 --strand both \
  --output /tmp/phage-clusters.tsv --representatives /tmp/phage-representatives.fasta

# Process each prepared input independently.
python3 run.py cd-hit datasets/public_viromes/ready \
  --identity 0.95 --strand both \
  --output-dir datasets/public_viromes/results/cd-hit
```

`sources.json` records download URLs, the pinned Vclust revision, SHA-256
checksums, original record indices, and each subset/fragment transformation.
`figshare_metadata.json` preserves the publisher's metadata and license.
