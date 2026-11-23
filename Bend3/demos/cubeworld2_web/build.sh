#!/bin/sh
# Builds CubeWorld 2 with Bend 2.0.40 into cubeworld2_web/build/ (gitignored).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

mkdir -p Bend3/demos/cubeworld2_web/build
bend Bend3/demos/cubeworld2_web/web_cubeworld2.bend -o Bend3/demos/cubeworld2_web/build/web_cubeworld2
printf '%s\n' 'CubeWorld 2 built: Bend3/demos/cubeworld2_web/build/web_cubeworld2'
