#!/bin/sh
# Starts Farmhands from the repository root (index.html and the default
# data/ directory are relative to it), building it first when needed.
# FARMHANDS_PORT (default 8093) and FARMHANDS_DATA_DIR are honoured.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

mkdir -p Bend3/demos/farmhands_web/data
if [ ! -x Bend3/demos/farmhands_web/build/web_farmhands ]; then
  ./Bend3/demos/farmhands_web/build.sh
fi
exec ./Bend3/demos/farmhands_web/build/web_farmhands
