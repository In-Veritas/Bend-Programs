#!/bin/sh
# Starts the BendJogos hub on 0.0.0.0:8090 from the repository root (every
# page path is relative to it), building it first when needed. Pass
# --rebuild to force a fresh build.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

if [ "${1:-}" = "--rebuild" ] || [ ! -x Bend3/demos/bendjogos_web/build/web_bendjogos ]; then
  ./Bend3/demos/bendjogos_web/build.sh
fi
exec ./Bend3/demos/bendjogos_web/build/web_bendjogos
