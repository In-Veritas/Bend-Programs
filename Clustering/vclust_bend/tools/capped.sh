#!/bin/sh
# capped CMD...: run CMD in its own memory-capped cgroup scope (per-process $CAP,
# default 3G; all capped work shares bendwork.slice, MemoryHigh 9G / MemoryMax 10G,
# no swap), so a runaway is OOM-killed alone instead of taking the terminal down.
# Where a systemd user manager is unavailable (e.g. WSL2 without systemd), CMD runs
# directly with a warning; WSL's own VM memory limit then bounds it.
set -eu
if systemd-run --user --scope --quiet --collect -- true >/dev/null 2>&1; then
  systemctl --user set-property --runtime bendwork.slice \
    MemoryHigh="${BENDWORK_HIGH:-9G}" MemoryMax="${BENDWORK_MAX:-10G}" MemorySwapMax=0 >/dev/null 2>&1 || true
  exec systemd-run --user --scope --quiet --collect --slice=bendwork.slice \
    -p "MemoryMax=${CAP:-3G}" -p MemorySwapMax=0 -- "$@"
fi
[ -n "${CAPPED_QUIET:-}" ] || echo "capped: no systemd user manager; running without a cgroup memory cap" >&2
exec "$@"
