#!/bin/bash
# LFS 12.4 — Chapter 8 (Block 4: 8.61 → 8.70)
# EXACT LFS commands. Uses your tarball filenames.

set -euo pipefail
cd /sources

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
### 8.61 Gawk-5.3.2
############################################
echo "===== 8.61 Gawk-5.3.2 ====="

extract gawk-5.3.2.tar.xz

sed -i 's/extras//' Makefile.in

./configure --prefix=/usr
make
# optional: make check
rm -f /usr/bin/gawk-5.3.2
make install

cd /sources

############################################
### 8.62 Findutils-4.10.0
############################################
echo "===== 8.62 Findutils-4.10.0 ====="

extract findutils-4.10.0.tar.xz

./configure --prefix=/usr --localstatedir=/var/lib/locate
make
# optional: make check
make install

cd /sources

############################################
### 8.63 Groff-1.23.0
############################################
echo "===== 8.63 Groff-1.23.0 ====="

extract groff-1.23.0.tar.gz

PAGE=letter ./configure --prefix=/usr
make
make install

cd /sources

############################################
### 8.64 GRUB-2.12
############################################
echo "===== 8.64 GRUB-2.12 ====="

extract grub-2.12.tar.xz

# Disable NLS warnings from GCC 15+
echo depends bli part_gpt > grub-core/extra_deps.lst

./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror

make
# optional: make check
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions

cd /sources

############################################
### 8.65 Gzip-1.14
############################################
echo "===== 8.65 Gzip-1.14 ====="

extract gzip-1.14.tar.xz

./configure --prefix=/usr
make
# optional: make check
make install

cd /sources

############################################
### 8.66 IPRoute2-6.16.0
############################################
echo "===== 8.66 IPRoute2-6.16.0 ====="

extract iproute2-6.16.0.tar.xz

sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8

make NETNS_RUN_DIR=/run/netns
make SBINDIR=/usr/sbin install
install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.16.0

cd /sources

############################################
### 8.67 Kbd-2.8.0
############################################
echo "===== 8.67 Kbd-2.8.0 ====="

extract kbd-2.8.0.tar.xz

patch -Np1 -i ../kbd-2.8.0-backspace-1.patch

sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

./configure --prefix=/usr --disable-vlock
make
# optional: make check
make install
cp -R -v docs/doc -T /usr/share/doc/kbd-2.8.0

cd /sources

############################################
### 8.68 Libpipeline-1.5.8
############################################
echo "===== 8.68 Libpipeline-1.5.8 ====="

extract libpipeline-1.5.8.tar.gz

./configure --prefix=/usr
make
# optional: make check
make install

cd /sources

############################################
### 8.69 Make-4.4.1
############################################
echo "===== 8.69 Make-4.4.1 ====="

extract make-4.4.1.tar.gz

./configure --prefix=/usr
make
# optional: make check
make install

cd /sources

############################################
### 8.70 Patch-2.8
############################################
echo "===== 8.70 Patch-2.8 ====="

extract patch-2.8.tar.xz

./configure --prefix=/usr
make
# optional: make check
make install

cd /sources

echo "===== Block 5 Finished (8.61 → 8.70) ====="
