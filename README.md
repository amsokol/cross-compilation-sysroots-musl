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
./create-sysroot.sh --arch=ARCH [--musl-version=VER] [--linux-version=VER] [--out=DIR]
```

| Flag              | Default    | Description                                                |
| ----------------- | ---------- | ---------------------------------------------------------- |
| `--arch`          | `x86_64`   | Target architecture: `x86_64`/`amd64` or `aarch64`/`arm64` |
| `--musl-version`  | `1.2.5`    | musl libc version                                          |
| `--linux-version` | `6.12.73`  | Linux kernel version (for UAPI headers)                    |
| `--out`           | `./output` | Output directory for the tarball                           |

## Build sysroots

### x86_64

```bash
./create-sysroot.sh --arch=x86_64
```

### aarch64

```bash
./create-sysroot.sh --arch=aarch64
```

Output tarballs are written to `./output/`:

```text
output/
├── musl-1.2.5-linux-6.12.73-sysroot-x86_64.tar.xz
└── musl-1.2.5-linux-6.12.73-sysroot-aarch64.tar.xz
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
| Linux kernel headers | 6.12.73 (LTS) |
