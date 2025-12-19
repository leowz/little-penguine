#!/bin/bash
# build-chap8-part1.sh
# LFS 12.4 (SysVinit) – Chapter 8 automation
# Packages: 8.3 Man-pages → 8.28 Shadow
#
# Run this *inside chroot* as root:
#   (lfs chroot) root:/# bash /sources/build-chap8-part1.sh 2>&1 | tee /var/log/lfs-ch8-part1.log

set -euo pipefail

SOURCES_DIR=/sources

log() {
  printf '\n========== %s ==========\n' "$*" >&2
}

run_in() {
  local dir="$1"; shift
  ( cd "$dir" && "$@" )
}

extract_cd() {
  local tarball="$1"
  local srcdir="$2"

  cd "$SOURCES_DIR"
  rm -rf "$srcdir"
  tar xf "$tarball"
  cd "$srcdir"
}

cleanup_src() {
  local srcdir="$1"
  cd "$SOURCES_DIR"
  rm -rf "$srcdir"
}

# ---------------------------------------------------------------------------
# 8.3 Man-pages-6.15
# ---------------------------------------------------------------------------
build_man_pages() {
  log "8.3 Man-pages-6.15"

  extract_cd "man-pages-6.15.tar.xz" "man-pages-6.15"

  # Remove crypt* manpages – provided by libxcrypt instead  [oai_citation:1‡Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/stable/chapter08/man-pages.html)
  rm -v man3/crypt*

  # Note: book uses: make -R GIT=false prefix=/usr install  [oai_citation:2‡Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/stable/chapter08/man-pages.html)
  make -R GIT=false prefix=/usr install

  cleanup_src "man-pages-6.15"
}

# ---------------------------------------------------------------------------
# 8.4 Iana-Etc-20250807
# ---------------------------------------------------------------------------
build_iana_etc() {
  log "8.4 Iana-Etc-20250807"

  extract_cd "iana-etc-20250807.tar.gz" "iana-etc-20250807"

  cp services protocols /etc

  cleanup_src "iana-etc-20250807"
}

# ---------------------------------------------------------------------------
# 8.5 Glibc-2.42
# ---------------------------------------------------------------------------
build_glibc() {
  log "8.5 Glibc-2.42"

  extract_cd "glibc-2.42.tar.xz" "glibc-2.42"

  # FHS patch 
  patch -Np1 -i ../glibc-2.42-fhs-1.patch

  # Valgrind-related fix in abort.c 
  sed -e '/unistd.h/i #include <string.h>' \
      -e '/libc_rwlock_init/c\
      __libc_rwlock_define_initialized (, reset_lock);\
      memcpy (&lock, &reset_lock, sizeof (lock));' \
      -i stdlib/abort.c

  mkdir -v build
  cd build

  echo "rootsbindir=/usr/sbin" > configparms

  ../configure --prefix=/usr                   \
               --disable-werror                \
               --disable-nscd                  \
               libc_cv_slibdir=/usr/lib        \
               --enable-stack-protector=strong \
               --enable-kernel=5.4

  make

  # Glibc tests are important – leave here but commented so you can decide. 
  # make check

  touch /etc/ld.so.conf

  sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

  make install
  sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

  # Locale setup (from LFS book, abbreviated)
  # You can uncomment/add locale generation commands from the book here if you want full locale coverage.

  cd "$SOURCES_DIR"
  rm -rf glibc-2.42
}

# ---------------------------------------------------------------------------
# 8.6 Zlib-1.3.1
# ---------------------------------------------------------------------------
build_zlib() {
  log "8.6 Zlib-1.3.1"

  extract_cd "zlib-1.3.1.tar.gz" "zlib-1.3.1"

  ./configure --prefix=/usr
  make
  # make check
  make install

  rm -fv /usr/lib/libz.a

  cleanup_src "zlib-1.3.1"
}

# ---------------------------------------------------------------------------
# 8.7 Bzip2-1.0.8
# ---------------------------------------------------------------------------
build_bzip2() {
  log "8.7 Bzip2-1.0.8"

  extract_cd "bzip2-1.0.8.tar.gz" "bzip2-1.0.8"

  # Install docs, fix symlinks & man dir 
  patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
  sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
  sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

  make -f Makefile-libbz2_so
  make clean
  make

  make PREFIX=/usr install

  # Shared library and binary moves (pattern from older LFS, still valid) 
  cp -av libbz2.so.* /usr/lib
  ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so

  cp -v bzip2-shared /usr/bin/bzip2
  for i in /usr/bin/{bzcat,bunzip2}; do
    ln -sfv bzip2 $i
  done

  rm -fv /usr/lib/libbz2.a

  cleanup_src "bzip2-1.0.8"
}

# ---------------------------------------------------------------------------
# 8.8 Xz-5.8.1
# ---------------------------------------------------------------------------
build_xz() {
  log "8.8 Xz-5.8.1"

  extract_cd "xz-5.8.1.tar.xz" "xz-5.8.1"

  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/xz-5.8.1

  make
  # make check
  make install

  cleanup_src "xz-5.8.1"
}

# ---------------------------------------------------------------------------
# 8.9 Lz4-1.10.0
# ---------------------------------------------------------------------------
build_lz4() {
  log "8.9 Lz4-1.10.0"

  extract_cd "lz4-1.10.0.tar.gz" "lz4-1.10.0"

  make BUILD_STATIC=no PREFIX=/usr
  # make -j1 check
  make BUILD_STATIC=no PREFIX=/usr install

  cleanup_src "lz4-1.10.0"
}

# ---------------------------------------------------------------------------
# 8.10 Zstd-1.5.7
# ---------------------------------------------------------------------------
build_zstd() {
  log "8.10 Zstd-1.5.7"

  extract_cd "zstd-1.5.7.tar.gz" "zstd-1.5.7"

  make prefix=/usr
  # make check
  make prefix=/usr install

  rm -fv /usr/lib/libzstd.a

  cleanup_src "zstd-1.5.7"
}

# ---------------------------------------------------------------------------
# 8.11 File-5.46
# ---------------------------------------------------------------------------
build_file() {
  log "8.11 File-5.46"

  extract_cd "file-5.46.tar.gz" "file-5.46"

  ./configure --prefix=/usr
  make
  # make check
  make install

  cleanup_src "file-5.46"
}

# ---------------------------------------------------------------------------
# 8.12 Readline-8.3
# ---------------------------------------------------------------------------
build_readline() {
  log "8.12 Readline-8.3"

  extract_cd "readline-8.3.tar.gz" "readline-8.3"

  sed -i '/MV.*old/d' Makefile.in
  sed -i '/{OLDSUFF}/c:' support/shlib-install
  sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf

  ./configure --prefix=/usr    \
              --disable-static \
              --with-curses    \
              --docdir=/usr/share/doc/readline-8.3

  make SHLIB_LIBS="-lncursesw"
  # make SHLIB_LIBS="-lncursesw" check
  make install

  install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3

  cleanup_src "readline-8.3"
}

# ---------------------------------------------------------------------------
# 8.13 M4-1.4.20
# ---------------------------------------------------------------------------
build_m4() {
  log "8.13 M4-1.4.20"

  extract_cd "m4-1.4.20.tar.xz" "m4-1.4.20"

  ./configure --prefix=/usr
  make
  # make check
  make install

  cleanup_src "m4-1.4.20"
}

# ---------------------------------------------------------------------------
# 8.14 Bc-7.0.3
# ---------------------------------------------------------------------------
build_bc() {
  log "8.14 Bc-7.0.3"

  extract_cd "bc-7.0.3.tar.xz" "bc-7.0.3"

  CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
  make
  # make test
  make install

  cleanup_src "bc-7.0.3"
}

# ---------------------------------------------------------------------------
# 8.15 Flex-2.6.4
# ---------------------------------------------------------------------------
build_flex() {
  log "8.15 Flex-2.6.4"

  extract_cd "flex-2.6.4.tar.gz" "flex-2.6.4"

  ./configure --prefix=/usr \
              --docdir=/usr/share/doc/flex-2.6.4 \
              --disable-static

  make
  # make check
  make install

  ln -sv flex   /usr/bin/lex
  ln -sv flex.1 /usr/share/man/man1/lex.1

  cleanup_src "flex-2.6.4"
}

# ---------------------------------------------------------------------------
# 8.16 Tcl-8.6.16
# ---------------------------------------------------------------------------
build_tcl() {
  log "8.16 Tcl-8.6.16"

  # src tarball name in your list: tcl8.6.16-src.tar.gz
  extract_cd "tcl8.6.16-src.tar.gz" "tcl8.6.16"

  SRCDIR=$(pwd)
  cd unix

  ./configure --prefix=/usr           \
              --mandir=/usr/share/man \
              --disable-rpath

  make

sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.10|/usr/lib/tdbc1.1.10|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10/generic|/usr/include|"     \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10/library|/usr/lib/tcl8.6|"  \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10|/usr/include|"             \
    -i pkgs/tdbc1.1.10/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.2|/usr/lib/itcl4.3.2|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.2/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.3.2|/usr/include|"            \
    -i pkgs/itcl4.3.2/itclConfig.sh

unset SRCDIR

  make install
  chmod 644 /usr/lib/libtclstub8.6.a

  # Move shared library where LFS expects it
  chmod -v u+w /usr/lib/libtcl8.6.so

  make install-private-headers

  ln -sfv tclsh8.6 /usr/bin/tclsh

  mv /usr/share/man/man3/{Thread,Tcl_Thread}.3

  # HTML docs (optional but nice)
  cd ..
  tar -xf ../tcl8.6.16-html.tar.gz --strip-components=1
  mkdir -v -p /usr/share/doc/tcl-8.6.16
  cp -v -r  ./html/* /usr/share/doc/tcl-8.6.16

  cleanup_src "tcl8.6.16"
}

# ---------------------------------------------------------------------------
# 8.17 Expect-5.45.4
# ---------------------------------------------------------------------------
build_expect() {
  log "8.17 Expect-5.45.4"

  extract_cd "expect5.45.4.tar.gz" "expect5.45.4"

  # Patch for GCC 15 in your source list
  patch -Np1 -i ../expect-5.45.4-gcc15-1.patch

  ./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include
  make
  # make test
  make install
  ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

  cleanup_src "expect5.45.4"
}

# ---------------------------------------------------------------------------
# 8.18 DejaGNU-1.6.3
# ---------------------------------------------------------------------------
build_dejagnu() {
  log "8.18 DejaGNU-1.6.3"

  extract_cd "dejagnu-1.6.3.tar.gz" "dejagnu-1.6.3"

  mkdir -v build
  cd build

  ../configure --prefix=/usr
  makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
  makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi

  make install
  install -v -dm755  /usr/share/doc/dejagnu-1.6.3
  install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3

  # make check  # optional

  cleanup_src "dejagnu-1.6.3"
}

# ---------------------------------------------------------------------------
# 8.19 Pkgconf-2.5.1
# ---------------------------------------------------------------------------
build_pkgconf() {
  log "8.19 Pkgconf-2.5.1"

  extract_cd "pkgconf-2.5.1.tar.xz" "pkgconf-2.5.1"

  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/pkgconf-2.5.1
  make
  # make check
  make install

  ln -sv pkgconf   /usr/bin/pkg-config
  ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1

  cleanup_src "pkgconf-2.5.1"
}

# ---------------------------------------------------------------------------
# 8.20 Binutils-2.45
# ---------------------------------------------------------------------------
build_binutils() {
  log "8.20 Binutils-2.45"

  extract_cd "binutils-2.45.tar.xz" "binutils-2.45"

  mkdir -v build
  cd build

  ../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --enable-new-dtags  \
             --with-system-zlib  \
             --enable-default-hash-style=gnu

  make tooldir=/usr
  # make -k check
  make tooldir=/usr install

  rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
        /usr/share/doc/gprofng/

  cleanup_src "binutils-2.45"
}

# ---------------------------------------------------------------------------
# 8.21 GMP-6.3.0
# ---------------------------------------------------------------------------
build_gmp() {
  log "8.21 GMP-6.3.0"

  extract_cd "gmp-6.3.0.tar.xz" "gmp-6.3.0"

  sed -i '/long long t1;/,+1s/()/(...)/' configure

  ./configure --prefix=/usr    \
              --enable-cxx     \
              --disable-static \
              --docdir=/usr/share/doc/gmp-6.3.0

  make
  make html
  # make check  # long

  make install
  make install-html

  cleanup_src "gmp-6.3.0"
}

# ---------------------------------------------------------------------------
# 8.22 MPFR-4.2.2
# ---------------------------------------------------------------------------
build_mpfr() {
  log "8.22 MPFR-4.2.2"

  extract_cd "mpfr-4.2.2.tar.xz" "mpfr-4.2.2"

  ./configure --prefix=/usr        \
              --disable-static     \
              --enable-thread-safe \
              --docdir=/usr/share/doc/mpfr-4.2.2

  make
  make html

  # make check
  make install
  make install-html

  cleanup_src "mpfr-4.2.2"
}

# ---------------------------------------------------------------------------
# 8.23 MPC-1.3.1
# ---------------------------------------------------------------------------
build_mpc() {
  log "8.23 MPC-1.3.1"

  extract_cd "mpc-1.3.1.tar.gz" "mpc-1.3.1"

  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/mpc-1.3.1

  make
  make html
  # make check
  make install
  make install-html

  cleanup_src "mpc-1.3.1"
}

# ---------------------------------------------------------------------------
# 8.24 Attr-2.5.2
# ---------------------------------------------------------------------------
build_attr() {
  log "8.24 Attr-2.5.2"

  extract_cd "attr-2.5.2.tar.gz" "attr-2.5.2"

  ./configure --prefix=/usr    \
              --disable-static \
              --sysconfdir=/etc \
              --docdir=/usr/share/doc/attr-2.5.2

  make
  # make check
  make install

  cleanup_src "attr-2.5.2"
}

# ---------------------------------------------------------------------------
# 8.25 Acl-2.3.2
# ---------------------------------------------------------------------------
build_acl() {
  log "8.25 Acl-2.3.2"

  extract_cd "acl-2.3.2.tar.xz" "acl-2.3.2"

  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/acl-2.3.2

  make
  # make check
  make install

  cleanup_src "acl-2.3.2"
}

# ---------------------------------------------------------------------------
# 8.26 Libcap-2.76
# ---------------------------------------------------------------------------
build_libcap() {
  log "8.26 Libcap-2.76"

  extract_cd "libcap-2.76.tar.xz" "libcap-2.76"

  sed -i '/install -m.*STA/d' libcap/Makefile

  make prefix=/usr lib=lib
  # make test
  make prefix=/usr lib=lib install

  cleanup_src "libcap-2.76"
}

# ---------------------------------------------------------------------------
# 8.27 Libxcrypt-4.4.38
# ---------------------------------------------------------------------------
build_libxcrypt() {
  log "8.27 Libxcrypt-4.4.38"

  extract_cd "libxcrypt-4.4.38.tar.xz" "libxcrypt-4.4.38"

  ./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no     \
            --disable-static             \
            --disable-failure-tokens
  make
  # make check
  make install

  cleanup_src "libxcrypt-4.4.38"
}

# ---------------------------------------------------------------------------
# 8.28 Shadow-4.18.0
# ---------------------------------------------------------------------------
build_shadow() {
  log "8.28 Shadow-4.18.0"

  extract_cd "shadow-4.18.0.tar.xz" "shadow-4.18.0"

  # As per LFS: disable groups tools in favor of coreutils / other defaults
  sed -i 's/groups$(EXEEXT) //' src/Makefile.in
  find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
  find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
  find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

  sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs

  touch /usr/bin/passwd

  ./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-{b,yes}crypt \
            --without-libbsd    \
            --with-group-name-max-length=32
  make
  # make -k check
  make exec_prefix=/usr install
  make -C man install-man

  # Setup default /etc/login.defs tweaks can be done manually per book.

  cleanup_src "shadow-4.18.0"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root inside the LFS chroot." >&2
    exit 1
  fi

  cd "$SOURCES_DIR"

  build_man_pages
  build_iana_etc
  build_glibc
  build_zlib
  build_bzip2
  build_xz
  build_lz4
  build_zstd
  build_file
  build_readline
  build_m4
  build_bc
  build_flex
  build_tcl
  build_expect
  build_dejagnu
  build_pkgconf
  build_binutils
  build_gmp
  build_mpfr
  build_mpc
  build_attr
  build_acl
  build_libcap
  build_libxcrypt
  build_shadow

  log "Chapter 8 part 1 done (up to Shadow-4.18.0 config shadow manually)."
}

main "$@"
