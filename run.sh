#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_IMAGE="$ROOT_DIR/kernel/bzImage"
INITRAMFS_IMAGE="$ROOT_DIR/build/initramfs.cpio.gz"

if [[ ! -f "$KERNEL_IMAGE" || ! -f "$INITRAMFS_IMAGE" ]]; then
  printf 'missing kernel/initramfs, run ./build.sh first\n' >&2
  exit 1
fi

exec qemu-system-x86_64 \
  -kernel "$KERNEL_IMAGE" \
  -initrd "$INITRAMFS_IMAGE" \
  -append "console=ttyS0 rdinit=/init" \
  -nographic \
  -serial mon:stdio \
  -m 2048M
