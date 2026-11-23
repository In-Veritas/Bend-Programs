#!/bin/sh
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output=${1:-/tmp/bend-chip8}

bend "$here/chip8.bend" -o "$output"
printf 'built %s\n' "$output"
