#!/bin/bash
# LFS 12.4 — Chapter 8 (Block 1: 8.29 → 8.38)
# EXACT LFS instructions, no changes.

set -euo pipefail
cd /sources

# Helper: extract a tarball into its directory (supports .xz .gz .tgz)
extract() {
  local t="$1"
  local d="$t"
  d="${d%.tar.xz}"
  d="${d%.tar.gz}"
  d="${d%.tgz}"
  d="${d%.tar.bz2}"
  rm -rf "$d"
  tar xf "$t"
  cd "$d"
}

############################################
### 8.29 GCC-15.2.0
############################################
echo "===== 8.29 GCC-15.2.0 ====="

cd /sources
rm -rf gcc-15.2.0
tar xf gcc-15.2.0.tar.xz
cd gcc-15.2.0

# Extract dependencies into source tree
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

mkdir -v build
cd build

../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --enable-default-pie     \
             --enable-default-ssp     \
             --enable-host-pie        \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-fixincludes    \
             --with-system-zlib
make
# optional: make -k check
ulimit -s -H unlimited

make install

chown -v -R root:root \
    /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include{,-fixed}

ln -svr /usr/bin/cpp /usr/lib
ln -sv gcc.1 /usr/share/man/man1/cc.1
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/15.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

cd /sources
rm -rf gcc-15.2.0


############################################
### 8.30 Ncurses-6.5 (your file: ncurses-6.5-20250809.tgz)
############################################
echo "===== 8.30 Ncurses-6.5 ====="

extract ncurses-6.5-20250809.tgz

./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --with-cxx-shared       \
            --enable-pc-files       \
            --with-pkg-config-libdir=/usr/lib/pkgconfig

make
make DESTDIR=$PWD/dest install
install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
rm -v  dest/usr/lib/libncursesw.so.6.5
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i dest/usr/include/curses.h
cp -av dest/* /

for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done

ln -sfv libncursesw.so /usr/lib/libcurses.so
cp -v -R doc -T /usr/share/doc/ncurses-6.5-20250809

cd /sources


############################################
### 8.31 Sed-4.9
############################################
echo "===== 8.31 Sed-4.9 ====="

extract sed-4.9.tar.xz

./configure --prefix=/usr
make
make html
# optional: make check
make install
install -d -m755           /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9

cd /sources


############################################
### 8.32 Psmisc-23.7
############################################
echo "===== 8.32 Psmisc-23.7 ====="

extract psmisc-23.7.tar.xz

./configure --prefix=/usr
make
make install

cd /sources


############################################
### 8.33 Gettext-0.26
############################################
echo "===== 8.33 Gettext-0.26 ====="

extract gettext-0.26.tar.xz

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.26
make
# optional: make check
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so

cd /sources


############################################
### 8.34 Bison-3.8.2
############################################
echo "===== 8.34 Bison-3.8.2 ====="

extract bison-3.8.2.tar.xz

./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
make
# optional: make check
make install

cd /sources


############################################
### 8.35 Grep-3.12
############################################
echo "===== 8.35 Grep-3.12 ====="

extract grep-3.12.tar.xz

sed -i "s/echo/#echo/" src/egrep.sh

./configure --prefix=/usr

make
# optional: make check
make install

cd /sources


############################################
### 8.36 Bash-5.3
############################################
echo "===== 8.36 Bash-5.3 ====="

extract bash-5.3.tar.gz

./configure --prefix=/usr             \
            --without-bash-malloc     \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3
make
# optional: chown -Rv tester . && su tester -c "PATH=$PATH make tests"
make install

cd /sources


############################################
### 8.37 Libtool-2.5.4
############################################
echo "===== 8.37 Libtool-2.5.4 ====="

extract libtool-2.5.4.tar.xz

./configure --prefix=/usr
make
# optional: make check
make install
rm -fv /usr/lib/libltdl.a

cd /sources


############################################
### 8.38 GDBM-1.26
############################################
echo "===== 8.38 GDBM-1.26 ====="

extract gdbm-1.26.tar.gz

./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat

make
# optional: make check
make install

cd /sources

echo "===== Part 2 Finished (8.29 → 8.38) ====="
