#!/bin/sh
# Build & open the water_movement browser version, and refresh frames.json.
#
# Needs `bend` (2.0.40+) and `bun` on PATH. For the native window instead:
#   bend main.bend -o /tmp/water && /tmp/water
#
# Usage:  sh play.sh        (edit `Wm.args` in main.bend to change the panels)

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

bun "$DIR/build.mjs"
echo "done -> open $DIR/water.html"

# Try to open it automatically (harmless if no GUI).
( command -v open >/dev/null 2>&1 && open "$DIR/water.html" ) \
  || ( command -v xdg-open >/dev/null 2>&1 && xdg-open "$DIR/water.html" ) \
  || true
