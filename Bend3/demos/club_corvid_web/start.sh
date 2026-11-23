#!/bin/sh
# Starts Club Corvid from the repository root (its page path is root-relative).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

if [ ! -x Bend3/demos/club_corvid_web/build/web_club_corvid ]; then
  ./Bend3/demos/club_corvid_web/build.sh
fi

exec ./Bend3/demos/club_corvid_web/build/web_club_corvid
