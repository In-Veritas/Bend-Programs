#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

if [ ! -x gabriel_demos/poker_web/web_poker ]; then
  ./gabriel_demos/poker_web/build.sh
fi

exec ./gabriel_demos/poker_web/web_poker
