#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISK_IMAGE="$ROOT_DIR/build/holy-linux.img"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.fd"
OVMF_VARS_TEMPLATE="/usr/share/OVMF/OVMF_VARS_4M.fd"
OVMF_VARS="$ROOT_DIR/build/OVMF_VARS_4M.fd"

if [[ ! -f "$DISK_IMAGE" ]]; then
  printf 'missing disk image, run ./build.sh first\n' >&2
  exit 1
fi

if [[ ! -f "$OVMF_CODE" || ! -f "$OVMF_VARS_TEMPLATE" ]]; then
  printf 'missing OVMF firmware files\n' >&2
  exit 1
fi

if [[ ! -f "$OVMF_VARS" ]]; then
  cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"
fi

exec qemu-system-x86_64 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS" \
  -drive file="$DISK_IMAGE",format=raw,if=virtio \
  -nographic \
  -serial mon:stdio \
  -m 2048M
