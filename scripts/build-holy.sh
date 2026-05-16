#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  printf 'usage: %s <hcc> <install-prefix> <out-dir> <src-dir>\n' "$0" >&2
  exit 1
fi

HCC="$1"
INSTALL_PREFIX="$2"
OUT_DIR="$3"
SRC_DIR="$4"

mkdir -p "$OUT_DIR"

build_one() {
  local src="$1"
  local name

  name="$(basename "${src%.hc}")"
  printf '[holyc] %s -> %s/%s\n' "$src" "$OUT_DIR" "$name"
  "$HCC" --install-dir="$INSTALL_PREFIX" -o "$OUT_DIR/$name" "$src"
}

build_one "$SRC_DIR/holyinit.hc"
build_one "$SRC_DIR/holybox.hc"
build_one "$SRC_DIR/holysh.hc"
build_one "$SRC_DIR/hcc.hc"
