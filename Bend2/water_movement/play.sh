#!/bin/sh
# Build & open the water_movement browser visualization.
#
# The Bend program is pure (no IO): it prints the simulation as JSON. This
# wrapper runs it, saves frames.json, and writes a standalone water.html that
# animates the result in your browser (auto-looping, like a gif).
#
# Usage:  sh demo/water_movement/play.sh
#         (edit `args` in main.bend to change which containers are shown)

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
JS="${TMPDIR:-/tmp}/water_data.js"

echo "compiling main.bend ..."
bun run "$ROOT/bend/src/CLI.ts" "$DIR/main.bend" -o "$JS"
echo "rendering ..."
bun "$DIR/build.mjs" "$JS" "$DIR/water.html" "$DIR/frames.json"
echo "done → open $DIR/water.html"

# Try to open it automatically (harmless if no GUI).
( command -v open >/dev/null 2>&1 && open "$DIR/water.html" ) \
  || ( command -v xdg-open >/dev/null 2>&1 && xdg-open "$DIR/water.html" ) \
  || true
