# musl sysroot builder

Build minimal musl libc sysroots for cross-compilation with Clang/LLVM (`toolchains_llvm`).

Each sysroot contains musl headers + static libraries and Linux kernel UAPI headers — everything a C/Rust cross-compiler needs to target `x86_64-linux-musl` or `aarch64-linux-musl`.

## Prerequisites

Run on **Linux** (amd64 or arm64). Install build dependencies:

```bash
sudo apt update
sudo apt install build-essential wget xz-utils rsync
```

For **cross-compilation** (building a sysroot for a different arch than the host), install a cross-compiler:

```bash
# On amd64, to build aarch64 sysroot:
sudo apt install gcc-aarch64-linux-gnu

# On arm64, to build x86_64 sysroot:
sudo apt install gcc-x86-64-linux-gnu
```

Alternatively, `clang` works as a cross-compiler for any target.

## Usage

```bash
./create-sysroot.sh --arch=ARCH [--musl-version=VER] [--linux-version=VER] [--profile=PROFILE] [--variant=VARIANT] [--out=DIR]
```

| Flag              | Default    | Description                                                             |
| ----------------- | ---------- | ----------------------------------------------------------------------- |
| `--arch`          | `x86_64`   | Target architecture: `x86_64`/`amd64` or `aarch64`/`arm64`              |
| `--musl-version`  | `1.2.5`    | musl libc version                                                       |
| `--linux-version` | `6.12.76`  | Linux kernel version (for UAPI headers)                                 |
| `--profile`       | `release`  | Build profile: `release` (`-O3`, stripped) or `debug` (`-O0 -g`)        |
| `--variant`       | *(none)*   | x86-64 microarchitecture level: `v1`, `v2`, `v3`, or `v4` (x86_64 only) |
| `--out`           | `./output` | Output directory for the tarball                                        |

### x86-64 microarchitecture levels

| Variant | `-march`    | Key features                                      |
| ------- | ----------- | ------------------------------------------------- |
| `v1`    | `x86-64`    | Baseline (SSE, SSE2)                              |
| `v2`    | `x86-64-v2` | + SSE3, SSE4.1, SSE4.2, SSSE3, POPCNT, CMPXCHG16B |
| `v3`    | `x86-64-v3` | + AVX, AVX2, BMI1, BMI2, F16C, FMA, LZCNT, MOVBE  |
| `v4`    | `x86-64-v4` | + AVX-512F/BW/CD/DQ/VL                            |

See [x86-64 microarchitecture levels](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) for details.

## Build sysroots

### x86_64 (baseline)

```bash
./create-sysroot.sh --arch=x86_64
```

### x86_64 with microarchitecture variant

```bash
./create-sysroot.sh --arch=x86_64 --variant=v3
```

### aarch64

```bash
./create-sysroot.sh --arch=aarch64
```

### Debug build

```bash
./create-sysroot.sh --arch=x86_64 --profile=debug
```

Output tarballs are written to `./output/`:

```text
output/
├── musl-1.2.5-linux-6.12.76-sysroot-x86_64.tar.xz
├── musl-1.2.5-linux-6.12.76-sysroot-x86_64-v2.tar.xz
├── musl-1.2.5-linux-6.12.76-sysroot-x86_64-v3.tar.xz
├── musl-1.2.5-linux-6.12.76-sysroot-x86_64-v4.tar.xz
├── musl-1.2.5-linux-6.12.76-sysroot-x86_64-debug.tar.xz
└── musl-1.2.5-linux-6.12.76-sysroot-aarch64.tar.xz
```

## Sysroot contents

```text
usr/
├── include/          ← musl libc + Linux kernel headers
│   ├── stdio.h
│   ├── stdlib.h
│   ├── linux/
│   ├── asm/
│   └── ...
└── lib/              ← static libraries + CRT objects
    ├── libc.a
    ├── libm.a
    ├── libpthread.a
    ├── librt.a
    ├── libdl.a
    ├── crt1.o
    ├── crti.o
    ├── crtn.o
    ├── Scrt1.o
    └── rcrt1.o
```

## Versions

| Component            | Version       |
| -------------------- | ------------- |
| musl libc            | 1.2.5         |
| Linux kernel headers | 6.12.76 (LTS) |
