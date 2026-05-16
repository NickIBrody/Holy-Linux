# holy-linux

`holy-linux` is a minimal bootable `x86_64` Linux image for QEMU that uses a real HolyC toolchain and real `.hc` source files in userspace.

What it does:

- boots a Linux kernel with a generated initramfs
- does not ship BusyBox in guest userspace
- runs `holyinit` as `PID 1`
- launches `holysh`, a simple custom HolyC shell
- provides `holybox`, a custom HolyC multicall command binary

## Dependencies

Host tools required:

- `bash`
- `git`
- `curl`
- `make`
- `gcc`
- `clang`
- `tar`
- `cpio`
- `gzip`
- `ldd`
- `qemu-system-x86_64`

The build downloads:

- `holyc-lang` from GitHub at pinned commit `3e1d278d7ee41350d64999332b2a6a9b14fd3573` dated `2026-05-16`
- Alpine Linux `vmlinuz-virt` from `v3.22.4`

## Commands

Build:

```bash
./build.sh
```

Run:

```bash
./run.sh
```

Clean:

```bash
./clean.sh
```

## Layout

```text
holy-linux/
  build.sh
  run.sh
  clean.sh
  README.md
  kernel/
  rootfs/
    init
    bin/
  src/
    holy/
      holyinit.hc
      holysh.hc
      holybox.hc
  toolchain/
  scripts/
```

## How it works

`build.sh` does the following:

1. clones `holyc-lang` into `toolchain/holyc-lang`
2. builds and installs `hcc` plus `libtos` into `toolchain/prefix`
3. downloads a prebuilt `x86_64` Linux kernel into `kernel/vmlinuz-virt`
4. compiles the HolyC sources in `src/holy/*.hc`
5. creates `/init -> /bin/holyinit` and the `holybox` applet symlinks
6. copies the dynamic loader and shared libraries needed by the HolyC ELF binaries into the initramfs root
7. stages a minimal guest-side HolyC toolchain so `hcc` also works inside the VM
8. packs `build/initramfs.cpio.gz`

`run.sh` starts:

```bash
qemu-system-x86_64 -kernel kernel/vmlinuz-virt -initrd build/initramfs.cpio.gz -append "console=ttyS0 rdinit=/init" -nographic
```

## What is real HolyC here

The init process, shell, and command box are real `.hc` files compiled by a real existing HolyC compiler: `hcc` from `holyc-lang`.

This repository does not invent a new language and does not rename C files to `.hc`.

## Toolchain limits

This is not full TempleOS userspace compatibility.

Important limitations:

- `holyc-lang` is a Linux-hosted HolyC compiler, not the original TempleOS compiler
- the generated HolyC binaries here are dynamically linked against the host glibc runtime, so the build copies `ld-linux`, `libc`, and `libm` into the initramfs
- the in-guest `hcc` also needs staged `clang`, `ld`, GCC CRT objects, and runtime libs, which makes the initramfs much larger
- `holysh` is intentionally simple and only supports whitespace tokenization, not full POSIX shell syntax
- `holybox` is intentionally small and only implements a compact set of applets
- this repo avoids BusyBox in guest userspace, but still relies on Linux libc/syscall ABI through `holyc-lang`

## What actually works

After boot, the system reaches `holysh`.

From the QEMU console you should be able to run:

```text
help
holybox --help
holybox --version
holysh --help
holysh --version
hello
echo one two three
cat /etc/passwd
ls /
uname
clear
hcc /src/hello.hc -o /tmp/hello
/tmp/hello
exit
```

`holyinit`, `holysh`, and `holybox` are compiled from the `.hc` files in [src/holy](/home/brody/holy-linux/src/holy).
