#!/bin/sh
# Preserves the memory controls from the recovered Claude environment.
# Usage: sh tools/render-capped.sh [--pdf]
set -eu
cd "$(dirname "$0")/.."
PRESENTATION_NODE="${PRESENTATION_NODE:-/home/veritas/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
systemctl --user set-property --runtime bendwork.slice MemoryHigh=9G MemoryMax=10G MemorySwapMax=0
exec systemd-run --user --scope --quiet --collect --slice=bendwork.slice \
  -p MemoryMax="${CAP:-2G}" -p MemorySwapMax=0 \
  -- "$PRESENTATION_NODE" tools/render.cjs "$@"
