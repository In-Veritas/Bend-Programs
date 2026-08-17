#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

exec ./gabriel_demos/cubeworld2_web/web_cubeworld2
