#!/usr/bin/env bash
set -euo pipefail

dataset_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
raw_dir="$dataset_dir/raw"
mkdir -p "$raw_dir"

verify_md5() {
  local expected="$1"
  local file="$2"
  local actual

  if command -v md5sum >/dev/null 2>&1; then
    actual="$(md5sum "$file" | awk '{print $1}')"
  else
    actual="$(md5 -q "$file")"
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "MD5 mismatch for $file: expected $expected, got $actual" >&2
    return 1
  fi
}

download_file() {
  local file_id="$1"
  local name="$2"
  local expected_md5="$3"
  local output="$raw_dir/$name"
  local partial="$output.part"

  if [[ -f "$output" ]]; then
    verify_md5 "$expected_md5" "$output"
    echo "verified $name"
    return
  fi

  curl --fail --location --retry 3 --continue-at - \
    --output "$partial" "https://ndownloader.figshare.com/files/$file_id"
  verify_md5 "$expected_md5" "$partial"
  mv "$partial" "$output"
  echo "downloaded and verified $name"
}

curl --fail --location --retry 3 \
  --output "$raw_dir/figshare_article_21102805_v2.json" \
  "https://api.figshare.com/v2/articles/21102805"

download_file 37467115 fig1.svg db9d0f4f958cc9744b2b9a81caae8f3d
download_file 37467121 taxtable.tsv 9ea2c77f8576116a90700a6b2cf1d5c3
download_file 37467124 all.curated.vOTUs.EarlyVir.fna c981d0450bead795491dc3db8c06ce49
