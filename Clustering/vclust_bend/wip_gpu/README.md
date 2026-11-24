# Prefilter GPU layout — work in progress (does not check yet)

`pf_core.bend` and `prefilter.bend` here are the unfinished GPU variant of the
prefilter (64-bit row blocks with a per-task table and sparse blocks), stopped
mid-edit on 2026-11-24 at 03:02. They fail `--check-only`. The stage files in the
parent folder are the stable CPU prefilter (byte-identical to Vclust on every
tested dataset and option). Resume from here, keeping the stable files intact.
