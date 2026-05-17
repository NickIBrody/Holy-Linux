# Holy-Linux

[![Release](https://img.shields.io/github/v/release/NickIBrody/Holy-Linux?display_name=tag)](https://github.com/NickIBrody/Holy-Linux/releases)
[![Platform](https://img.shields.io/badge/platform-x86__64-blue)](https://github.com/NickIBrody/Holy-Linux)
[![Userspace](https://img.shields.io/badge/userspace-HolyC-gold)](https://github.com/NickIBrody/Holy-Linux/tree/main/src/holy)
[![Runtime](https://img.shields.io/badge/runtime-QEMU%20%2B%20Linux-black)](https://www.qemu.org/)
[![Kernel](https://img.shields.io/badge/kernel-kernel.org%206.12.89--holy-darkgreen)](https://kernel.org/)

`Holy-Linux` is a small bootable `x86_64` Linux system for QEMU that uses real HolyC source files in userspace.

It now boots on its own `kernel.org`-built `x86_64` kernel with a custom `-holy` localversion, so it no longer depends on a prebuilt Alpine kernel image.

This repo exists because I wanted a minimal system that actually boots, drops into its own shell, and runs programs written as `.hc` files, without pretending that C is HolyC and without stopping at pseudocode.

It also exists for a practical reason: I do not consider it rational to fully learn HolyC for one short experimental project. So I built it with `Codex` as an engineering assistant, while keeping the result honest, inspectable, and reproducible.

> "An idiot admires complexity, a genius admires simplicity."  
> Terry A. Davis

That line fits the goal here. `Holy-Linux` is not trying to recreate all of TempleOS. It is trying to do one thing cleanly: boot Linux, enter a custom HolyC userspace, and compile and run `.hc` code inside the guest.

## What It Is

- A real Linux kernel built from `kernel.org` sources and booted by `QEMU`
- A generated `initramfs`
- A bootable UEFI `img`
- A custom HolyC `init`: `holyinit`
- A custom HolyC shell: `holysh`
- A custom HolyC multicall binary: `holybox`
- A guest-side `hcc` setup so `.hc` programs can be compiled inside the running VM

## What It Is Not

- It is not TempleOS
- It is not original native TempleOS userspace compatibility
- It is not a full Linux distribution
- It is not a fake demo with renamed C files

## Dependencies

Host tools:

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

The build fetches:

- `holyc-lang` at pinned commit `3e1d278d7ee41350d64999332b2a6a9b14fd3573`
- Linux `6.12.89` from `kernel.org`

## Commands

Build:

```bash
./build.sh
```

Run:

```bash
./run.sh
```

Run UEFI disk image:

```bash
./run-img.sh
```

Clean:

```bash
./clean.sh
```

## How It Works

`build.sh`:

1. Clones `holyc-lang` into `toolchain/holyc-lang`
2. Builds and installs `hcc` and `libtos` into `toolchain/prefix`
3. Downloads Linux `6.12.89` from `kernel.org`
4. Builds a custom `x86_64` kernel with localversion `-holy`
5. Compiles the HolyC sources in `src/holy/*.hc`
6. Builds the rootfs and wires `/init` to `holyinit`
7. Installs `holybox` applet links
8. Stages the runtime pieces needed by HolyC ELF binaries
9. Stages a minimal guest-side compile toolchain for in-VM `hcc`
10. Packs `build/initramfs.cpio.gz`
11. Builds `build/holy-linux.img`

`run.sh` starts:

```bash
qemu-system-x86_64 \
  -kernel kernel/bzImage \
  -initrd build/initramfs.cpio.gz \
  -append "console=ttyS0 rdinit=/init" \
  -nographic \
  -serial mon:stdio \
  -m 2048M
```

`run-img.sh` starts the UEFI image with:

```bash
qemu-system-x86_64 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=build/OVMF_VARS_4M.fd \
  -drive file=build/holy-linux.img,format=raw,if=virtio \
  -nographic \
  -serial mon:stdio \
  -m 2048M
```

## What Is Real HolyC Here

The important parts are real `.hc` files:

- `holyinit.hc`
- `holysh.hc`
- `holybox.hc`
- `hcc.hc`
- `hello.hc`
- `echo.hc`
- `cat.hc`
- `clear.hc`

They are compiled by a real existing HolyC compiler: `hcc` from `holyc-lang`.

No fake syntax layer was invented for this repo.

## What Actually Works

After boot, the system reaches `holysh`.

Inside QEMU, the following flow works:

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

The guest-compiled program prints:

```text
hello from guest-compiled HolyC
```

The branded kernel identity is now visible too:

```text
uname -a
Linux holy-linux 6.12.89-holy ... x86_64
```

## Toolchain Limits

This project is honest about its compromises.

- `holyc-lang` is a Linux-hosted HolyC compiler, not the original TempleOS compiler
- The produced binaries use the Linux libc/syscall ABI
- The guest-side `hcc` needs staged `clang`, `ld`, GCC CRT objects, and runtime libraries
- Because of that, the `initramfs` is much larger than a tiny toy boot image
- The current `initramfs` is heavy enough that `QEMU` should be given `2048M` of RAM for reliable boot
- `holysh` is intentionally simple: whitespace tokenization only, no pipes, no redirects, no full POSIX parsing
- `holybox` is intentionally small and only covers a compact command set

## Why Codex Is Mentioned

This project was built with `Codex` because the goal was to ship a working system, not to roleplay a purist learning exercise.

I did not want to spend disproportionate time learning HolyC deeply for a single experiment when the real task was systems integration:

- find a working HolyC compiler on Linux
- wire it into a bootable image
- make `.hc` userspace binaries actually run
- get in-guest compilation working too

`Codex` helped accelerate the plumbing. The result is still a normal repository with normal scripts, normal source files, and a reproducible build.

## Bottom Line

If you run:

```bash
./build.sh
./run.sh
```

you get a bootable Linux guest that enters a custom HolyC shell and can run, and compile, real `.hc` programs.
