#!/bin/sh
# Starts the poker server from the repository root (index.html is read
# relative to it), building it first when needed.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

if [ ! -x Bend3/demos/poker_web/build/web_poker ]; then
  ./Bend3/demos/poker_web/build.sh
fi

exec ./Bend3/demos/poker_web/build/web_poker
