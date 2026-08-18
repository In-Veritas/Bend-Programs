#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

bun bend-ts/src/main.ts gabriel_demos/farmhands_web/farmhands_logic.bend --eval test
bun bend-ts/src/main.ts gabriel_demos/farmhands_web/web_farmhands.bend --no-halt -o gabriel_demos/farmhands_web/web_farmhands
printf '%s\n' 'Farmhands built; all pure rule proofs checked.'
