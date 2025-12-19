#!/bin/bash
set -e

SRC_DIR=$LFS/sources

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
    echo ">>> Cleaning $1"
    cd $SRC_DIR
    rm -rf $1
}

fail_if_missing() {
    if [ ! -f "$SRC_DIR/$1" ]; then
        echo "ERROR: Missing tarball: $1"
        exit 1
    fi
}
