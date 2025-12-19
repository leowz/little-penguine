#!/bin/bash
# LFS 12.4 (SysVinit) - Chapter 7:
# Gettext-0.26, Bison-3.8.2, Perl-5.42.0, Python-3.13.7, Texinfo-7.2, Util-linux-2.41.1
# Run this INSIDE the chroot, as root.

set -euo pipefail

### --- Basic sanity checks ---------------------------------------------------

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: This script must be run as root (inside chroot)." >&2
  exit 1
fi

SOURCES_DIR="/sources"

if [[ ! -d "$SOURCES_DIR" ]]; then
  echo "ERROR: Sources directory '$SOURCES_DIR' does not exist (are you in chroot?)." >&2
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

### --- 7.7 Gettext-0.26 ------------------------------------------------------

build_gettext() {
  section "7.7 Gettext-0.26"

  fail_if_missing "gettext-0.26.tar.xz"
  extract_pkg "gettext-0.26.tar.xz"

  # For the temporary tools, we only need a few binaries, no full install.
  ./configure --disable-shared

  make

  # Install only the three programs needed at this stage
  cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

  cleanup_pkg "gettext-0.26"
}

### --- 7.8 Bison-3.8.2 -------------------------------------------------------

build_bison() {
  section "7.8 Bison-3.8.2"

  fail_if_missing "bison-3.8.2.tar.xz"
  extract_pkg "bison-3.8.2.tar.xz"

  ./configure --prefix=/usr \
              --docdir=/usr/share/doc/bison-3.8.2

  make
  make install

  cleanup_pkg "bison-3.8.2"
}

### --- 7.9 Perl-5.42.0 -------------------------------------------------------

build_perl() {
  section "7.9 Perl-5.42.0"

  fail_if_missing "perl-5.42.0.tar.xz"
  extract_pkg "perl-5.42.0.tar.xz"

  # Configure exactly as in the book
  sh Configure -des                                         \
               -D prefix=/usr                               \
               -D vendorprefix=/usr                         \
               -D useshrplib                                \
               -D privlib=/usr/lib/perl5/5.42/core_perl     \
               -D archlib=/usr/lib/perl5/5.42/core_perl     \
               -D sitelib=/usr/lib/perl5/5.42/site_perl     \
               -D sitearch=/usr/lib/perl5/5.42/site_perl    \
               -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
               -D vendorarch=/usr/lib/perl5/5.42/vendor_perl

  make
  make install

  cleanup_pkg "perl-5.42.0"
}

### --- 7.10 Python-3.13.7 ----------------------------------------------------
# NOTE: use the *capital P* tarball: Python-3.13.7.tar.xz

build_python() {
  section "7.10 Python-3.13.7"

  fail_if_missing "Python-3.13.7.tar.xz"
  extract_pkg "Python-3.13.7.tar.xz"

  ./configure --prefix=/usr       \
              --enable-shared     \
              --without-ensurepip \
              --without-static-libpython

  make

  # Some modules fail due to missing deps (OpenSSL etc.) – that's OK here.
  make install

  cleanup_pkg "Python-3.13.7"
}

### --- 7.11 Texinfo-7.2 ------------------------------------------------------

build_texinfo() {
  section "7.11 Texinfo-7.2"

  fail_if_missing "texinfo-7.2.tar.xz"
  extract_pkg "texinfo-7.2.tar.xz"

  ./configure --prefix=/usr

  make
  make install

  cleanup_pkg "texinfo-7.2"
}

### --- 7.12 Util-linux-2.41.1 ------------------------------------------------

build_util_linux() {
  section "7.12 Util-linux-2.41.1"

  fail_if_missing "util-linux-2.41.1.tar.xz"
  extract_pkg "util-linux-2.41.1.tar.xz"

  # As per book: create /var/lib/hwclock
  mkdir -pv /var/lib/hwclock

  ./configure --libdir=/usr/lib     \
              --runstatedir=/run    \
              --disable-chfn-chsh   \
              --disable-login       \
              --disable-nologin     \
              --disable-su          \
              --disable-setpriv     \
              --disable-runuser     \
              --disable-pylibmount  \
              --disable-static      \
              --disable-liblastlog2 \
              --without-python      \
              ADJTIME_PATH=/var/lib/hwclock/adjtime \
              --docdir=/usr/share/doc/util-linux-2.41.1

  make
  make install

  cleanup_pkg "util-linux-2.41.1"
}

### --- Main ------------------------------------------------------------------

main() {
  section "Chapter 7 - Additional Temporary Tools (start)"

  cd "$SOURCES_DIR"

  build_gettext
  build_bison
  build_perl
  build_python
  build_texinfo
  build_util_linux

  section "Chapter 7 - DONE (temporary tools)"
}

main "$@"
