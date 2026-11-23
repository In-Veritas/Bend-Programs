#!/bin/sh
# Builds Club Corvid with Bend 2.0.40 into club_corvid_web/build/ (gitignored).
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$repo_root"

mkdir -p Bend3/demos/club_corvid_web/build
bend Bend3/demos/club_corvid_web/web_club_corvid.bend -o Bend3/demos/club_corvid_web/build/web_club_corvid
printf '%s\n' 'Club Corvid built: Bend3/demos/club_corvid_web/build/web_club_corvid'
