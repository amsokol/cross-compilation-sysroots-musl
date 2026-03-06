#!/bin/bash
set -euo pipefail

MUSL_VERSION="1.2.5"
LINUX_VERSION="6.12.76"
TARGET_ARCH="x86_64"
OUT_DIR="$(pwd)/output"

for arg in "$@"; do
  case $arg in
    --arch=*)
      TARGET_ARCH="${arg#*=}"
      ;;
    --musl-version=*)
      MUSL_VERSION="${arg#*=}"
      ;;
    --linux-version=*)
      LINUX_VERSION="${arg#*=}"
      ;;
    --out=*)
      OUT_DIR="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

case "$TARGET_ARCH" in
  amd64|x86_64)
    TARGET_ARCH="x86_64"
    LINUX_ARCH="x86"
    MUSL_TRIPLE="x86_64-linux-musl"
    ;;
  arm64|aarch64)
    TARGET_ARCH="aarch64"
    LINUX_ARCH="arm64"
    MUSL_TRIPLE="aarch64-linux-musl"
    ;;
  *)
    echo "Error: Unsupported arch: $TARGET_ARCH (use amd64/x86_64 or arm64/aarch64)" >&2
    exit 1
    ;;
esac

HOST_ARCH="$(uname -m)"

if [ "$HOST_ARCH" = "$TARGET_ARCH" ]; then
  CC="${CC:-gcc}"
else
  CROSS_GCC="${TARGET_ARCH}-linux-gnu-gcc"
  if command -v "$CROSS_GCC" &>/dev/null; then
    CC="$CROSS_GCC"
  elif command -v clang &>/dev/null; then
    CC="clang --target=${MUSL_TRIPLE}"
  else
    echo "Error: No cross-compiler found for ${MUSL_TRIPLE}." >&2
    echo "Install one of:" >&2
    echo "  apt install gcc-${TARGET_ARCH}-linux-gnu" >&2
    echo "  apt install clang" >&2
    exit 1
  fi
fi

for cmd in wget tar make rsync; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd not found." >&2
    exit 1
  fi
done

SYSROOT_NAME="musl-${MUSL_VERSION}-linux-${LINUX_VERSION}-sysroot-${TARGET_ARCH}"

echo "============================================="
echo " musl sysroot builder"
echo "============================================="
echo " musl:            ${MUSL_VERSION}"
echo " Linux headers:   ${LINUX_VERSION}"
echo " Target:          ${MUSL_TRIPLE}"
echo " Host:            ${HOST_ARCH}"
echo " Compiler:        ${CC}"
echo " Output:          ${OUT_DIR}/${SYSROOT_NAME}.tar.xz"
echo "============================================="

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

SYSROOT_DIR="${WORK_DIR}/sysroot"
mkdir -p "$SYSROOT_DIR"

# ── Download sources ─────────────────────────────────────────────────

MUSL_URL="https://musl.libc.org/releases/musl-${MUSL_VERSION}.tar.gz"
echo ""
echo ">>> Downloading musl ${MUSL_VERSION}..."
wget -q --show-progress -O "${WORK_DIR}/musl.tar.gz" "$MUSL_URL"
tar xzf "${WORK_DIR}/musl.tar.gz" -C "$WORK_DIR"

LINUX_MAJOR="${LINUX_VERSION%%.*}"
LINUX_URL="https://cdn.kernel.org/pub/linux/kernel/v${LINUX_MAJOR}.x/linux-${LINUX_VERSION}.tar.xz"
echo ""
echo ">>> Downloading Linux ${LINUX_VERSION} (for kernel headers)..."
wget -q --show-progress -O "${WORK_DIR}/linux.tar.xz" "$LINUX_URL"
tar xJf "${WORK_DIR}/linux.tar.xz" -C "$WORK_DIR"

# ── Build and install musl ───────────────────────────────────────────

echo ""
echo ">>> Configuring musl for ${MUSL_TRIPLE}..."
cd "${WORK_DIR}/musl-${MUSL_VERSION}"
./configure \
    --target="${MUSL_TRIPLE}" \
    --prefix="/usr" \
    --syslibdir="/usr/lib" \
    CC="${CC}" \
    AR="$(command -v ar)" \
    RANLIB="$(command -v ranlib)"

echo ""
echo ">>> Building musl ($(nproc) jobs)..."
make -j"$(nproc)"

echo ""
echo ">>> Installing musl to sysroot..."
make DESTDIR="$SYSROOT_DIR" install

# ── Install Linux kernel headers ─────────────────────────────────────

echo ""
echo ">>> Installing Linux kernel headers..."
cd "${WORK_DIR}/linux-${LINUX_VERSION}"
make -s ARCH="$LINUX_ARCH" headers_install INSTALL_HDR_PATH="${SYSROOT_DIR}/usr"

find "${SYSROOT_DIR}" \( -name '.install' -o -name '..install.cmd' \) -delete 2>/dev/null || true

# ── Stub libraries ───────────────────────────────────────────────────
# toolchains_llvm's cc toolchain links -latomic and -l:libstdc++.a by default.
# musl doesn't provide these; create empty archives so the linker is satisfied.
# They contribute no code -- atomics are handled by compiler builtins, and
# libstdc++ is irrelevant for pure-C/Rust projects.

echo ""
echo ">>> Creating stub libraries (libatomic, libstdc++, libc++)..."
for lib in libatomic.a libstdc++.a libc++.a; do
    ar rcs "${SYSROOT_DIR}/usr/lib/${lib}"
done

# ── Package ──────────────────────────────────────────────────────────

mkdir -p "$OUT_DIR"
SYSROOT_TAR="${OUT_DIR}/${SYSROOT_NAME}.tar.xz"

echo ""
echo ">>> Packaging sysroot..."
tar -C "$SYSROOT_DIR" --xz -cpf "$SYSROOT_TAR" --numeric-owner .

echo ""
echo "============================================="
echo " Done"
echo "============================================="
echo " Sysroot: ${SYSROOT_TAR}"
du -sh "$SYSROOT_TAR"
HASH=$(sha256sum "$SYSROOT_TAR" | cut -d ' ' -f1)
echo " sha256:  ${HASH}"
echo ""
echo " Contents:"
echo "   usr/include/  — musl + Linux kernel headers"
echo "   usr/lib/      — libc.a, libm.a, libpthread.a, crt*.o, ..."
echo "============================================="
