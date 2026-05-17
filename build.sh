#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DISTFILES_DIR="$BUILD_DIR/distfiles"
WORK_DIR="$BUILD_DIR/work"
ROOTFS_DIR="$BUILD_DIR/rootfs"
TOOLCHAIN_SRC_DIR="$ROOT_DIR/toolchain/holyc-lang"
TOOLCHAIN_PREFIX="$ROOT_DIR/toolchain/prefix"
KERNEL_DIR="$ROOT_DIR/kernel"
KERNEL_IMAGE="$KERNEL_DIR/bzImage"
KERNEL_CONFIG_FRAGMENT="$KERNEL_DIR/x86_64_holy.fragment"
KERNEL_CONFIG_SNAPSHOT="$KERNEL_DIR/x86_64_holy.config"
INITRAMFS_IMAGE="$BUILD_DIR/initramfs.cpio.gz"
DISK_IMAGE="$BUILD_DIR/holy-linux.img"

HOLYC_REPO="https://github.com/Jamesbarford/holyc-lang.git"
HOLYC_COMMIT="3e1d278d7ee41350d64999332b2a6a9b14fd3573"
LINUX_VERSION="6.12.89"
LINUX_SERIES="v6.x"
LINUX_TARBALL="linux-$LINUX_VERSION.tar.xz"
LINUX_URL="https://cdn.kernel.org/pub/linux/kernel/${LINUX_SERIES}/${LINUX_TARBALL}"
LINUX_SRC_DIR="$WORK_DIR/linux-$LINUX_VERSION"
LINUX_BUILD_DIR="$WORK_DIR/linux-build"
KERNEL_MAKE_JOBS="${KERNEL_MAKE_JOBS:-$(nproc)}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

fetch() {
  local url="$1"
  local out="$2"

  if [[ -f "$out" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$out")"
  printf '[fetch] %s\n' "$url"
  curl -L --fail --retry 3 -o "$out" "$url"
}

prepare_toolchain() {
  mkdir -p "$ROOT_DIR/toolchain"

  if [[ ! -d "$TOOLCHAIN_SRC_DIR/.git" ]]; then
    printf '[toolchain] cloning holyc-lang\n'
    git clone "$HOLYC_REPO" "$TOOLCHAIN_SRC_DIR"
  fi

  printf '[toolchain] checkout %s\n' "$HOLYC_COMMIT"
  git -C "$TOOLCHAIN_SRC_DIR" fetch --depth 1 origin "$HOLYC_COMMIT"
  git -C "$TOOLCHAIN_SRC_DIR" checkout --force "$HOLYC_COMMIT"

  mkdir -p "$TOOLCHAIN_PREFIX/lib"
  printf '[toolchain] build/install hcc\n'
  make -C "$TOOLCHAIN_SRC_DIR" -j"$(nproc)" INSTALL_PREFIX="$TOOLCHAIN_PREFIX"
  make -C "$TOOLCHAIN_SRC_DIR" install INSTALL_PREFIX="$TOOLCHAIN_PREFIX"
}

prepare_kernel_source() {
  local tarball_path="$DISTFILES_DIR/$LINUX_TARBALL"

  mkdir -p "$WORK_DIR" "$KERNEL_DIR"
  fetch "$LINUX_URL" "$tarball_path"

  if [[ ! -d "$LINUX_SRC_DIR" ]]; then
    printf '[kernel] extract %s\n' "$LINUX_TARBALL"
    tar -C "$WORK_DIR" -xf "$tarball_path"
  fi
}

build_kernel() {
  printf '[kernel] configure linux-%s\n' "$LINUX_VERSION"
  rm -rf "$LINUX_BUILD_DIR"
  mkdir -p "$LINUX_BUILD_DIR"

  make -C "$LINUX_SRC_DIR" O="$LINUX_BUILD_DIR" tinyconfig >/dev/null
  "$LINUX_SRC_DIR/scripts/kconfig/merge_config.sh" \
    -m \
    -O "$LINUX_BUILD_DIR" \
    "$LINUX_BUILD_DIR/.config" \
    "$KERNEL_CONFIG_FRAGMENT" >/dev/null
  make -C "$LINUX_SRC_DIR" O="$LINUX_BUILD_DIR" olddefconfig >/dev/null

  printf '[kernel] build bzImage\n'
  make -C "$LINUX_SRC_DIR" O="$LINUX_BUILD_DIR" -j"$KERNEL_MAKE_JOBS" bzImage >/dev/null

  cp "$LINUX_BUILD_DIR/arch/x86/boot/bzImage" "$KERNEL_IMAGE"
  cp "$LINUX_BUILD_DIR/.config" "$KERNEL_CONFIG_SNAPSHOT"
}

prepare_rootfs() {
  printf '[rootfs] reset\n'
  rm -rf "$ROOTFS_DIR"
  mkdir -p "$ROOTFS_DIR"

  cp -a "$ROOT_DIR/rootfs/." "$ROOTFS_DIR/"
  mkdir -p "$ROOTFS_DIR"/{bin,dev,proc,sys,tmp,etc,root,usr/bin}
  chmod 1777 "$ROOTFS_DIR/tmp"
  mknod -m 600 "$ROOTFS_DIR/dev/console" c 5 1 2>/dev/null || true
  mknod -m 666 "$ROOTFS_DIR/dev/null" c 1 3 2>/dev/null || true
  mknod -m 666 "$ROOTFS_DIR/dev/tty" c 5 0 2>/dev/null || true
}

build_holy_binaries() {
  local hcc="$TOOLCHAIN_PREFIX/bin/hcc"

  printf '[holyc] compile userspace\n'
  "$ROOT_DIR/scripts/build-holy.sh" \
    "$hcc" \
    "$TOOLCHAIN_PREFIX" \
    "$ROOTFS_DIR/bin" \
    "$ROOT_DIR/src/holy"

  printf '[rootfs] install holybox links\n'
  rm -f "$ROOTFS_DIR/init"
  ln -sf bin/holyinit "$ROOTFS_DIR/init"
  ln -sf holysh "$ROOTFS_DIR/bin/sh"
  ln -sf holybox "$ROOTFS_DIR/bin/hello"
  ln -sf holybox "$ROOTFS_DIR/bin/pwd"
  ln -sf holybox "$ROOTFS_DIR/bin/echo"
  ln -sf holybox "$ROOTFS_DIR/bin/cat"
  ln -sf holybox "$ROOTFS_DIR/bin/read"
  ln -sf holybox "$ROOTFS_DIR/bin/write"
  ln -sf holybox "$ROOTFS_DIR/bin/clear"
  ln -sf holybox "$ROOTFS_DIR/bin/ls"
  ln -sf holybox "$ROOTFS_DIR/bin/htree"
  ln -sf holybox "$ROOTFS_DIR/bin/uname"
  ln -sf holybox "$ROOTFS_DIR/bin/holyfetch"
  ln -sf holybox "$ROOTFS_DIR/bin/touch"
  ln -sf holybox "$ROOTFS_DIR/bin/mkdir"
  ln -sf holybox "$ROOTFS_DIR/bin/rm"
  ln -sf holybox "$ROOTFS_DIR/bin/mv"
  ln -sf holybox "$ROOTFS_DIR/bin/cp"
  ln -sf holybox "$ROOTFS_DIR/bin/ps"
  ln -sf holybox "$ROOTFS_DIR/bin/holytop"
  ln -sf holybox "$ROOTFS_DIR/bin/dmesg"
  ln -sf holybox "$ROOTFS_DIR/bin/mount"
  ln -sf holybox "$ROOTFS_DIR/bin/umount"
  ln -sf holybox "$ROOTFS_DIR/bin/hed"
  ln -sf holybox "$ROOTFS_DIR/bin/reboot"
  ln -sf holybox "$ROOTFS_DIR/bin/poweroff"
}

install_guest_toolchain() {
  printf '[rootfs] install guest toolchain\n'

  mkdir -p \
    "$ROOTFS_DIR/bin" \
    "$ROOTFS_DIR/usr/bin" \
    "$ROOTFS_DIR/usr/lib/llvm-19/bin" \
    "$ROOTFS_DIR/usr/lib/llvm-19/lib" \
    "$ROOTFS_DIR/usr/lib/gcc/x86_64-linux-gnu/14" \
    "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu" \
    "$ROOTFS_DIR/usr/local/include" \
    "$ROOTFS_DIR/usr/local/lib" \
    "$ROOTFS_DIR/src"

  cp -L "$TOOLCHAIN_PREFIX/bin/hcc" "$ROOTFS_DIR/bin/hcc.bin"
  cp -L /usr/lib/llvm-19/bin/clang "$ROOTFS_DIR/usr/lib/llvm-19/bin/clang"
  cp -a /usr/lib/llvm-19/lib/clang "$ROOTFS_DIR/usr/lib/llvm-19/lib/"
  ln -sf ../usr/lib/llvm-19/bin/clang "$ROOTFS_DIR/bin/clang"
  ln -sf ../usr/lib/llvm-19/bin/clang "$ROOTFS_DIR/usr/bin/clang"

  cp -L /usr/bin/x86_64-linux-gnu-ld "$ROOTFS_DIR/usr/bin/x86_64-linux-gnu-ld"
  ln -sf x86_64-linux-gnu-ld "$ROOTFS_DIR/usr/bin/ld"
  ln -sf ../usr/bin/ld "$ROOTFS_DIR/bin/ld"

  cp -L /usr/lib/gcc/x86_64-linux-gnu/14/crtbeginS.o "$ROOTFS_DIR/usr/lib/gcc/x86_64-linux-gnu/14/"
  cp -L /usr/lib/gcc/x86_64-linux-gnu/14/crtendS.o "$ROOTFS_DIR/usr/lib/gcc/x86_64-linux-gnu/14/"
  cp -L /usr/lib/gcc/x86_64-linux-gnu/14/libgcc.a "$ROOTFS_DIR/usr/lib/gcc/x86_64-linux-gnu/14/"
  cp -L /usr/lib/gcc/x86_64-linux-gnu/14/libgcc_s.so "$ROOTFS_DIR/usr/lib/gcc/x86_64-linux-gnu/14/"

  cp -L /usr/lib/x86_64-linux-gnu/libc.so "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/"
  cp -L /usr/lib/x86_64-linux-gnu/libc_nonshared.a "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/"
  cp -L /usr/lib/x86_64-linux-gnu/libm.so "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/"
  cp -L /usr/lib/x86_64-linux-gnu/libpthread.a "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/"
  cp -L /usr/lib/x86_64-linux-gnu/libpthread_nonshared.a "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/"
  cp -L /usr/lib/x86_64-linux-gnu/librt.a "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/"

  mkdir -p "$ROOTFS_DIR/lib/x86_64-linux-gnu"
  cp -L /lib/x86_64-linux-gnu/Scrt1.o "$ROOTFS_DIR/lib/x86_64-linux-gnu/"
  cp -L /lib/x86_64-linux-gnu/crti.o "$ROOTFS_DIR/lib/x86_64-linux-gnu/"
  cp -L /lib/x86_64-linux-gnu/crtn.o "$ROOTFS_DIR/lib/x86_64-linux-gnu/"
  cp -L /lib/x86_64-linux-gnu/libmvec.so.1 "$ROOTFS_DIR/lib/x86_64-linux-gnu/"

  cp -L "$TOOLCHAIN_PREFIX/include/tos.HH" "$ROOTFS_DIR/usr/local/include/"
  cp -L "$TOOLCHAIN_PREFIX/lib/libtos.a" "$ROOTFS_DIR/usr/local/lib/"

  cp -a "$ROOT_DIR/src/holy/." "$ROOTFS_DIR/src/"
}

copy_runtime_libs() {
  local bin
  local tool

  printf '[rootfs] copy ELF runtime deps\n'
  for bin in "$ROOTFS_DIR/bin/"*; do
    if [[ -f "$bin" ]]; then
      "$ROOT_DIR/scripts/copy-libs.sh" "$bin" "$ROOTFS_DIR"
    fi
  done

  for tool in \
    "$ROOTFS_DIR/usr/lib/llvm-19/bin/clang" \
    "$ROOTFS_DIR/usr/bin/x86_64-linux-gnu-ld" \
    "$ROOTFS_DIR/usr/bin/ld"; do
    if [[ -f "$tool" ]]; then
      "$ROOT_DIR/scripts/copy-libs.sh" "$tool" "$ROOTFS_DIR"
    fi
  done
}

pack_initramfs() {
  printf '[initramfs] pack %s\n' "$INITRAMFS_IMAGE"
  mkdir -p "$BUILD_DIR"
  (
    cd "$ROOTFS_DIR"
    find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "$INITRAMFS_IMAGE"
  )
}

build_disk_image() {
  local efi_dir="$BUILD_DIR/efi"
  local grub_cfg="$efi_dir/grub.cfg"
  local efi_bin="$efi_dir/BOOTX64.EFI"

  printf '[img] build %s\n' "$DISK_IMAGE"
  rm -rf "$efi_dir"
  mkdir -p "$efi_dir"

  cat > "$grub_cfg" <<'EOF'
serial --unit=0 --speed=115200
terminal_input console
terminal_output serial console
set timeout=0
set default=0

menuentry "Holy-Linux" {
  search --file --set=root /boot/bzImage
  linux /boot/bzImage console=ttyS0 rdinit=/init
  initrd /boot/initramfs.cpio.gz
}
EOF

  grub-mkstandalone \
    -O x86_64-efi \
    -o "$efi_bin" \
    --modules="part_gpt part_msdos fat ext2 normal linux search search_fs_file serial terminal" \
    "boot/grub/grub.cfg=$grub_cfg"

  dd if=/dev/zero of="$DISK_IMAGE" bs=1M count=128 status=none
  mformat -i "$DISK_IMAGE" -F -v HOLYLINUX ::
  mmd -i "$DISK_IMAGE" ::/EFI
  mmd -i "$DISK_IMAGE" ::/EFI/BOOT
  mmd -i "$DISK_IMAGE" ::/boot
  mcopy -i "$DISK_IMAGE" "$efi_bin" ::/EFI/BOOT/BOOTX64.EFI
  mcopy -i "$DISK_IMAGE" "$KERNEL_IMAGE" ::/boot/bzImage
  mcopy -i "$DISK_IMAGE" "$INITRAMFS_IMAGE" ::/boot/initramfs.cpio.gz
}

main() {
  need_cmd git
  need_cmd curl
  need_cmd make
  need_cmd gcc
  need_cmd clang
  need_cmd cpio
  need_cmd gzip
  need_cmd tar
  need_cmd xz
  need_cmd ldd
  need_cmd file
  need_cmd grub-mkstandalone
  need_cmd dd
  need_cmd mformat
  need_cmd mmd
  need_cmd mcopy
  need_cmd bc
  need_cmd flex
  need_cmd bison
  need_cmd perl

  mkdir -p "$BUILD_DIR" "$DISTFILES_DIR"

  prepare_toolchain
  prepare_kernel_source
  build_kernel
  prepare_rootfs
  build_holy_binaries
  install_guest_toolchain
  copy_runtime_libs
  pack_initramfs
  build_disk_image

  printf '\nready:\n'
  printf '  kernel:    %s\n' "$KERNEL_IMAGE"
  printf '  config:    %s\n' "$KERNEL_CONFIG_SNAPSHOT"
  printf '  initramfs: %s\n' "$INITRAMFS_IMAGE"
  printf '  img:       %s\n' "$DISK_IMAGE"
}

main "$@"
