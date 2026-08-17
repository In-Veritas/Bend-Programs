#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

bun bend-ts/src/bend.ts gabriel_demos/cubeworld2_web/web_cubeworld2.bend --no-halt -o gabriel_demos/cubeworld2_web/web_cubeworld2
printf '%s\n' 'CubeWorld 2 built.'
