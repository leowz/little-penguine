#!/bin/bash
# LFS 12.4 (SysVinit) - Chapter 6: Cross Compiling Temporary Tools
# Run as user 'lfs' with LFS env already configured.

set -euo pipefail

### --- Basic sanity checks ---------------------------------------------------

if [[ "$(id -un)" != "lfs" ]]; then
  echo "ERROR: This script must be run as user 'lfs'." >&2
  exit 1
fi

: "${LFS:?LFS is not set}"
: "${LFS_TGT:?LFS_TGT is not set}"

SOURCES_DIR="$LFS/sources"

if [[ ! -d "$SOURCES_DIR" ]]; then
  echo "ERROR: Sources directory '$SOURCES_DIR' does not exist." >&2
  exit 1
fi

### --- Helper functions ------------------------------------------------------

fail_if_missing() {
  for f in "$@"; do
    if [[ ! -f "$SOURCES_DIR/$f" ]]; then
      echo "ERROR: Missing source tarball: $f" >&2
      exit 1
    fi
  done
}

extract_pkg() {
  local tarball="$1"
  cd "$SOURCES_DIR"

  # Normalize directory name:
  # 1. strip .tar.xz, .tar.gz, .tar.bz2, .tar.zst
  # 2. OR strip .tgz
  local dir="$tarball"
  dir="${dir%.tar.xz}"
  dir="${dir%.tar.gz}"
  dir="${dir%.tar.bz2}"
  dir="${dir%.tar.zst}"
  dir="${dir%.tgz}"

  rm -rf "$dir"

  echo "==> Extracting $tarball"
  tar -xf "$tarball"

  cd "$dir"
}

cleanup_pkg() {
  local dir="$1"
  cd "$SOURCES_DIR"
  echo "==> Cleaning $dir"
  rm -rf "$dir"
}

section() {
  echo
  echo "############################################################"
  echo "### $1"
  echo "############################################################"
  echo
}

### --- 6.2 M4-1.4.20 ---------------------------------------------------------

build_m4() {
  section "6.2 M4-1.4.20"

  fail_if_missing "m4-1.4.20.tar.xz"
  extract_pkg "m4-1.4.20.tar.xz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "m4-1.4.20"
}

### --- 6.3 Ncurses-6.5-20250809 ---------------------------------------------
# NOTE: your file is ncurses-6.5-20250809.tgz

build_ncurses() {
  section "6.3 Ncurses-6.5-20250809"

  fail_if_missing "ncurses-6.5-20250809.tgz"
  extract_pkg "ncurses-6.5-20250809.tgz"

  # Build tic for the host and put it into $LFS/tools
  mkdir build
  pushd build
    ../configure --prefix="$LFS/tools" AWK=gawk
    make -C include
    make -C progs tic
    install progs/tic "$LFS/tools/bin"
  popd

  # Cross-compile ncurses
  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(./config.guess)" \
              --mandir=/usr/share/man \
              --with-manpage-format=normal \
              --with-shared \
              --without-normal \
              --with-cxx-shared \
              --without-debug \
              --without-ada \
              --disable-stripping \
              AWK=gawk

  make
  make DESTDIR="$LFS" install

  ln -sv libncursesw.so "$LFS/usr/lib/libncurses.so"

  sed -e 's/^#if.*XOPEN.*$/#if 1/' \
      -i "$LFS/usr/include/curses.h"

  cleanup_pkg "ncurses-6.5-20250809"
}

### --- 6.4 Bash-5.3 ----------------------------------------------------------

build_bash() {
  section "6.4 Bash-5.3"

  fail_if_missing "bash-5.3.tar.gz"
  extract_pkg "bash-5.3.tar.gz"

  ./configure --prefix=/usr \
              --build="$(sh support/config.guess)" \
              --host="$LFS_TGT" \
              --without-bash-malloc

  make
  make DESTDIR="$LFS" install

  ln -sv bash "$LFS/bin/sh"

  cleanup_pkg "bash-5.3"
}

### --- 6.5 Coreutils-9.7 -----------------------------------------------------

build_coreutils() {
  section "6.5 Coreutils-9.7"

  fail_if_missing "coreutils-9.7.tar.xz"
  extract_pkg "coreutils-9.7.tar.xz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(build-aux/config.guess)" \
              --enable-install-program=hostname \
              --enable-no-install-program=kill,uptime

  make
  make DESTDIR="$LFS" install

  mv -v "$LFS/usr/bin/chroot" "$LFS/usr/sbin"
  mkdir -pv "$LFS/usr/share/man/man8"
  mv -v "$LFS/usr/share/man/man1/chroot.1" \
        "$LFS/usr/share/man/man8/chroot.8"
  sed -i 's/"1"/"8"/' "$LFS/usr/share/man/man8/chroot.8"

  cleanup_pkg "coreutils-9.7"
}

### --- 6.6 Diffutils-3.12 ----------------------------------------------------

build_diffutils() {
  section "6.6 Diffutils-3.12"

  fail_if_missing "diffutils-3.12.tar.xz"
  extract_pkg "diffutils-3.12.tar.xz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              gl_cv_func_strcasecmp_works=y \
              --build="$(./build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "diffutils-3.12"
}

### --- 6.7 File-5.46 ---------------------------------------------------------
# NOTE: your file is file-5.46.tar.gz

build_file() {
  section "6.7 File-5.46"

  fail_if_missing "file-5.46.tar.gz"
  extract_pkg "file-5.46.tar.gz"

  # temporary native build of 'file' for cross-build
  mkdir build
  pushd build
    ../configure --disable-bzlib \
                 --disable-libseccomp \
                 --disable-xzlib \
                 --disable-zlib
    make
  popd

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(./config.guess)"

  make FILE_COMPILE="$(pwd)/build/src/file"
  make DESTDIR="$LFS" install

  rm -fv "$LFS/usr/lib/libmagic.la"

  cleanup_pkg "file-5.46"
}

### --- 6.8 Findutils-4.10.0 --------------------------------------------------

build_findutils() {
  section "6.8 Findutils-4.10.0"

  fail_if_missing "findutils-4.10.0.tar.xz"
  extract_pkg "findutils-4.10.0.tar.xz"

  ./configure --prefix=/usr \
              --localstatedir=/var/lib/locate \
              --host="$LFS_TGT" \
              --build="$(build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "findutils-4.10.0"
}

### --- 6.9 Gawk-5.3.2 --------------------------------------------------------

build_gawk() {
  section "6.9 Gawk-5.3.2"

  fail_if_missing "gawk-5.3.2.tar.xz"
  extract_pkg "gawk-5.3.2.tar.xz"

  sed -i 's/extras//' Makefile.in

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "gawk-5.3.2"
}

### --- 6.10 Grep-3.12 --------------------------------------------------------

build_grep() {
  section "6.10 Grep-3.12"

  fail_if_missing "grep-3.12.tar.xz"
  extract_pkg "grep-3.12.tar.xz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(./build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "grep-3.12"
}

### --- 6.11 Gzip-1.14 --------------------------------------------------------

build_gzip() {
  section "6.11 Gzip-1.14"

  fail_if_missing "gzip-1.14.tar.xz"
  extract_pkg "gzip-1.14.tar.xz"

  ./configure --prefix=/usr --host="$LFS_TGT"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "gzip-1.14"
}

### --- 6.12 Make-4.4.1 -------------------------------------------------------

build_make() {
  section "6.12 Make-4.4.1"

  fail_if_missing "make-4.4.1.tar.gz"
  extract_pkg "make-4.4.1.tar.gz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "make-4.4.1"
}

### --- 6.13 Patch-2.8 --------------------------------------------------------

build_patch() {
  section "6.13 Patch-2.8"

  fail_if_missing "patch-2.8.tar.xz"
  extract_pkg "patch-2.8.tar.xz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "patch-2.8"
}

### --- 6.14 Sed-4.9 ----------------------------------------------------------

build_sed() {
  section "6.14 Sed-4.9"

  fail_if_missing "sed-4.9.tar.xz"
  extract_pkg "sed-4.9.tar.xz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(./build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "sed-4.9"
}

### --- 6.15 Tar-1.35 ---------------------------------------------------------

build_tar() {
  section "6.15 Tar-1.35"

  fail_if_missing "tar-1.35.tar.xz"
  extract_pkg "tar-1.35.tar.xz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(build-aux/config.guess)"

  make
  make DESTDIR="$LFS" install

  cleanup_pkg "tar-1.35"
}

### --- 6.16 Xz-5.8.1 ---------------------------------------------------------

build_xz() {
  section "6.16 Xz-5.8.1"

  fail_if_missing "xz-5.8.1.tar.xz"
  extract_pkg "xz-5.8.1.tar.xz"

  ./configure --prefix=/usr \
              --host="$LFS_TGT" \
              --build="$(build-aux/config.guess)" \
              --disable-static \
              --docdir=/usr/share/doc/xz-5.8.1

  make
  make DESTDIR="$LFS" install

  rm -fv "$LFS/usr/lib/liblzma.la"

  cleanup_pkg "xz-5.8.1"
}

### --- 6.17 Binutils-2.45 - Pass 2 -------------------------------------------

build_binutils_pass2() {
  section "6.17 Binutils-2.45 - Pass 2"

  fail_if_missing "binutils-2.45.tar.xz"
  extract_pkg "binutils-2.45.tar.xz"

  sed '6031s/$add_dir//' -i ltmain.sh

  mkdir -v build
  cd build

  ../configure \
    --prefix=/usr \
    --build="$(../config.guess)" \
    --host="$LFS_TGT" \
    --disable-nls \
    --enable-shared \
    --enable-gprofng=no \
    --disable-werror \
    --enable-64-bit-bfd \
    --enable-new-dtags \
    --enable-default-hash-style=gnu

  make
  make DESTDIR="$LFS" install

  rm -fv "$LFS/usr/lib/lib"{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

  cd "$SOURCES_DIR"
  cleanup_pkg "binutils-2.45"
}

### --- 6.18 GCC-15.2.0 - Pass 2 ----------------------------------------------

build_gcc_pass2() {
  section "6.18 GCC-15.2.0 - Pass 2"

  fail_if_missing \
    "gcc-15.2.0.tar.xz" \
    "mpfr-4.2.2.tar.xz" \
    "gmp-6.3.0.tar.xz" \
    "mpc-1.3.1.tar.gz"

  extract_pkg "gcc-15.2.0.tar.xz"

  tar -xf ../mpfr-4.2.2.tar.xz
  mv -v mpfr-4.2.2 mpfr

  tar -xf ../gmp-6.3.0.tar.xz
  mv -v gmp-6.3.0 gmp

  tar -xf ../mpc-1.3.1.tar.gz
  mv -v mpc-1.3.1 mpc

  case "$(uname -m)" in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
      ;;
  esac

  sed '/thread_header =/s/@.*@/gthr-posix.h/' \
      -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

  mkdir -v build
  cd build

  ../configure \
    --build="$(../config.guess)" \
    --host="$LFS_TGT" \
    --target="$LFS_TGT" \
    --prefix=/usr \
    --with-build-sysroot="$LFS" \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-nls \
    --disable-multilib \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libsanitizer \
    --disable-libssp \
    --disable-libvtv \
    --enable-languages=c,c++ \
    LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc"

  make
  make DESTDIR="$LFS" install

  ln -sv gcc "$LFS/usr/bin/cc"

  cd "$SOURCES_DIR"
  cleanup_pkg "gcc-15.2.0"
}

### --- Main ------------------------------------------------------------------

main() {
  section "Chapter 6 - Cross Compiling Temporary Tools (start)"
  cd "$SOURCES_DIR"

  build_m4
  build_ncurses
  build_bash
  build_coreutils
  build_diffutils
  build_file
  build_findutils
  build_gawk
  build_grep
  build_gzip
  build_make
  build_patch
  build_sed
  build_tar
  build_xz
  build_binutils_pass2
  build_gcc_pass2

  section "Chapter 6 - DONE"
}

main "$@"
