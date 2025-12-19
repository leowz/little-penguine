#!/bin/bash
set -e

# Load env + helpers
source /home/lfs/set-lfs-env.sh
source /home/lfs/helpers.sh

cd "$LFS/sources"

###############################################################################
# 5.2 Binutils-2.45 - Pass 1
###############################################################################
fail_if_missing binutils-2.45.tar.xz
extract_pkg binutils-2.45.tar.xz

mkdir -v build
cd build

../configure \
  --prefix=$LFS/tools \
  --with-sysroot=$LFS \
  --target=$LFS_TGT \
  --disable-nls \
  --enable-gprofng=no \
  --disable-werror \
  --enable-new-dtags \
  --enable-default-hash-style=gnu

make -j"$(nproc)"
make install

cleanup_pkg binutils-2.45

###############################################################################
# 5.3 GCC-15.2.0 - Pass 1
###############################################################################
cd "$LFS/sources"
fail_if_missing gcc-15.2.0.tar.xz
extract_pkg gcc-15.2.0.tar.xz

# Unpack and move dependencies as the book says
tar -xf ../mpfr-4.2.2.tar.xz
mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz
mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz
mv -v mpc-1.3.1 mpc

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac

# (You should also apply the sed fixes from the book manually if needed.)

mkdir -v build
cd build

../configure                  \
  --target=$LFS_TGT           \
  --prefix=$LFS/tools         \
  --with-glibc-version=2.42   \
  --with-sysroot=$LFS         \
  --with-newlib               \
  --without-headers           \
  --enable-default-pie        \
  --enable-default-ssp        \
  --disable-nls               \
  --disable-shared            \
  --disable-multilib          \
  --disable-threads           \
  --disable-libatomic         \
  --disable-libgomp           \
  --disable-libquadmath       \
  --disable-libssp            \
  --disable-libvtv            \
  --disable-libstdcxx         \
  --enable-languages=c,c++

make -j"$(nproc)"
make install

# Create the full limits.h as in the book (sanity step)
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h

cleanup_pkg gcc-15.2.0

###############################################################################
# 5.4 Linux-6.16.1 API Headers
###############################################################################
cd "$LFS/sources"
fail_if_missing linux-6.16.1.tar.xz
extract_pkg linux-6.16.1.tar.xz

make mrproper

make headers

# Remove non-header files as per the book
find usr/include -type f ! -name '*.h' -delete
# Make sure /usr exists in $LFS
mkdir -pv "$LFS/usr"
# THIS is the critical step that creates /mnt/lfs/usr/include
cp -rv usr/include "$LFS/usr"

cleanup_pkg linux-6.16.1

###############################################################################
# 5.5 Glibc-2.42 (cross)
###############################################################################
cd "$LFS/sources"
fail_if_missing glibc-2.42.tar.xz
extract_pkg glibc-2.42.tar.xz

case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac

patch -Np1 -i ../glibc-2.42-fhs-1.patch

mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

../configure                             \
  --prefix=/usr                          \
  --host=$LFS_TGT                        \
  --build=$(../scripts/config.guess)     \
  --disable-nscd                         \
  libc_cv_slibdir=/usr/lib               \
  --enable-kernel=5.4

make -j"$(nproc)"
make DESTDIR=$LFS install

# Fix ldd hard-coded path as in the book
sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"

# (Optional but recommended: run the dummy.c sanity checks manually)

cleanup_pkg glibc-2.42

###############################################################################
# 5.6 Libstdc++ from GCC-15.2.0
###############################################################################
cd "$LFS/sources"
fail_if_missing gcc-15.2.0.tar.xz
extract_pkg gcc-15.2.0.tar.xz

mkdir -v build
cd build

../libstdc++-v3/configure                    \
  --host=$LFS_TGT                            \
  --build=$(../config.guess)                 \
  --prefix=/usr                              \
  --disable-multilib                         \
  --disable-nls                              \
  --disable-libstdcxx-pch                    \
  --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0

make -j"$(nproc)"
make DESTDIR=$LFS install

# Remove libtool .la files (harmful for cross compilation)
rm -fv $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la

cleanup_pkg gcc-15.2.0

echo "=== Chapter 5 cross-toolchain build finished successfully ==="
