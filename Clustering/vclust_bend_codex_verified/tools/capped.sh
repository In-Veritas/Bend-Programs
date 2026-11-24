#!/bin/sh
# Durable replacement for the previous session's /tmp-only memory wrapper.
set -eu
systemctl --user set-property --runtime bendwork.slice \
  MemoryHigh=9G MemoryMax=10G MemorySwapMax=0
exec systemd-run --user --scope --quiet --collect --slice=bendwork.slice \
  -p "MemoryMax=${CAP:-3G}" -p MemorySwapMax=0 -- "$@"
