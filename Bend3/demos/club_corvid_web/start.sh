#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

if [ ! -x gabriel_demos/club_corvid_web/web_club_corvid ]; then
  ./gabriel_demos/club_corvid_web/build.sh
fi

exec ./gabriel_demos/club_corvid_web/web_club_corvid
