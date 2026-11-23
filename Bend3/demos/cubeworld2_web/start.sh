#!/bin/sh
# Starts CubeWorld 2 from the repository root (its page path is root-relative).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

if [ ! -x Bend3/demos/cubeworld2_web/build/web_cubeworld2 ]; then
  ./Bend3/demos/cubeworld2_web/build.sh
fi

exec ./Bend3/demos/cubeworld2_web/build/web_cubeworld2
