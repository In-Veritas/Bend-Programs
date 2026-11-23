#!/bin/sh
# Builds the native poker server into Bend3/demos/poker_web/build/ (gitignored).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

mkdir -p Bend3/demos/poker_web/build
bend Bend3/demos/poker_web/web_poker.bend --check-only
bend Bend3/demos/poker_web/web_poker.bend -o Bend3/demos/poker_web/build/web_poker
printf '%s\n' 'Built Bend3/demos/poker_web/build/web_poker.'
