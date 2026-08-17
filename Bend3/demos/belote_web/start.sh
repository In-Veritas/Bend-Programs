#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

if [ ! -x gabriel_demos/belote_web/web_belote ]; then
  ./gabriel_demos/belote_web/build.sh
fi

exec ./gabriel_demos/belote_web/web_belote
