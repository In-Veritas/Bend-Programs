#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

mkdir -p gabriel_demos/farmhands_web/data
if [ ! -x gabriel_demos/farmhands_web/web_farmhands ]; then
  ./gabriel_demos/farmhands_web/build.sh
fi
exec ./gabriel_demos/farmhands_web/web_farmhands
