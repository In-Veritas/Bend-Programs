#!/bin/sh
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
core_repo=${BEND2_CORE_REPO:-"$here/../../../../bend2-core"}
output=${1:-/tmp/bend2-core-chip8}

bun "$core_repo/src/main.ts" "$here/chip8.bend" --to "$output.c"
clang -O2 "$output.c" -o "$output"
printf 'built %s\n' "$output"
