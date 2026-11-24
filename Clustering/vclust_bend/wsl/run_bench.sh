#!/usr/bin/env bash
# Runs the time + energy benchmark: Vclust 1.3.1 vs Bend->C (CPU) vs Bend->CUDA (GPU),
# per stage (prefilter, align, cluster) and end to end, and packs the results.
#   bash Clustering/vclust_bend/wsl/run_bench.sh                       # small dataset only
#   bash Clustering/vclust_bend/wsl/run_bench.sh /path/all_clean_contigs.fasta   # + large
# Every cell is checked byte for byte against Vclust's own output.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
VB=$(cd "$HERE/.." && pwd)
ENV_FILE="$HOME/.bend-vclust-env.sh"
[ -f "$ENV_FILE" ] || { echo "Run wsl/setup.sh first."; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"
BIG=${1:-}
STAMP=$(date +%Y%m%dT%H%M%S)
OUT="$VB/evidence/energy"
mkdir -p "$OUT" "$VB/.work"

echo "== Machine"
{ uname -a; echo; lscpu | grep -E 'Model name|^CPU\(s\)|Thread|MHz'; echo; free -g; echo;
  nvidia-smi --query-gpu=name,driver_version,power.limit,power.default_limit,memory.total,pstate --format=csv;
  echo; clang --version 2>/dev/null | head -1; /usr/local/cuda/bin/nvcc --version 2>/dev/null | tail -2;
  git -C "$BEND_REPO" log -1 --format='bend %h %s'; } | tee "$OUT/machine-$STAMP.txt"
echo
echo "Close games/browsers using the GPU before continuing (GPU energy is measured for the whole board)."
echo "Keep the PC plugged in, and do not use it heavily while this runs."
sleep 5

cd "$VB"
echo "== 1/2 small dataset: earlyvir_stratified1000 (1,000 genomes), 3 repeats"
python3 tools/run_energy_matrix.py --datasets stratified1000 --timeout 1800 2>&1 | tee "$OUT/run-stratified1000-$STAMP.log"

if [ -n "$BIG" ]; then
  [ -f "$BIG" ] || { echo "Large dataset not found: $BIG"; exit 1; }
  export ALL_CLEAN_CONTIGS=$(readlink -f "$BIG")
  echo "== 2/2 large dataset: $ALL_CLEAN_CONTIGS, 1 repeat"
  echo "   probing Vclust prefilter memory first"
  /usr/bin/time -v "$VB/../.tools/vclust-1.3.1/bin/vclust" prefilter -i "$ALL_CLEAN_CONTIGS" \
      -o "$VB/.work/probe-fltr.txt" -t "$(nproc)" -v 1 2> "$OUT/probe-vclust-prefilter-$STAMP.txt" || true
  grep -E 'Maximum resident|Elapsed' "$OUT/probe-vclust-prefilter-$STAMP.txt" || true
  python3 tools/run_energy_matrix.py --datasets all_clean_contigs --timeout 14400 2>&1 | tee "$OUT/run-all_clean_contigs-$STAMP.log"
fi

python3 tools/run_energy_matrix.py --report-only >/dev/null 2>&1 || true
TAR="$HOME/bend-vclust-results-$STAMP.tar.gz"
tar czf "$TAR" -C "$VB" evidence/energy
echo
echo "== Done. Results: $OUT/RESULTS.md"
echo "   Send back this file (or commit evidence/energy on the branch): $TAR"
