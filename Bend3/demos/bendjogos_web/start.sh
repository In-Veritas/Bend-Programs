#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

exec ./gabriel_demos/bendjogos_web/web_bendjogos
