#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf "$ROOT_DIR/build"
rm -f "$ROOT_DIR/kernel/vmlinuz-virt"
rm -f "$ROOT_DIR/kernel/bzImage"
rm -f "$ROOT_DIR/kernel/x86_64_holy.config"
rm -rf "$ROOT_DIR/toolchain/prefix"

if [[ -d "$ROOT_DIR/toolchain/holyc-lang" ]]; then
  make -C "$ROOT_DIR/toolchain/holyc-lang" clean >/dev/null 2>&1 || true
  rm -rf "$ROOT_DIR/toolchain/holyc-lang/build"
fi

printf 'cleaned generated artifacts\n'
