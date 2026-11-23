#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
ENV="$ROOT/.tools/vclust-1.3.1"

if [ ! -x "$ENV/bin/python" ]; then
  python3 -m venv "$ENV"
fi

"$ENV/bin/python" -m pip install --disable-pip-version-check \
  -r "$HERE/requirements-vclust.txt"
"$ENV/bin/vclust" info
