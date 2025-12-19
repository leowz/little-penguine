#!/bin/bash
# LFS 12.4 — Chapter 8 (Block 3: 8.50 → 8.60)
# EXACT commands from the book, only adjusted for your tarball names.

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

####################################################
### 8.50 Libffi-3.5.2
####################################################
echo "===== 8.50 Libffi-3.5.2 ====="

extract libffi-3.5.2.tar.gz

./configure --prefix=/usr    \
            --disable-static \
            --with-gcc-arch=native

make
# optional: make check
make install

cd /sources

####################################################
### 8.51 Python-3.13.7
####################################################
echo "===== 8.51 Python-3.13.7 ====="

extract Python-3.13.7.tar.xz

./configure --prefix=/usr          \
            --enable-shared        \
            --with-system-expat    \
            --enable-optimizations \
            --without-static-libpython

make
# optional (with timeout, as in book):
# make test TESTOPTS="--timeout 120"

make install

# Optional: install preformatted HTML docs (book commands)
cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

install -v -dm755 /usr/share/doc/python-3.13.7/html
tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.13.7/html \
    -xvf ../python-3.13.7-docs-html.tar.bz2

cd /sources

####################################################
### 8.52 Flit-Core-3.12.0
####################################################
echo "===== 8.52 Flit-Core-3.12.0 ====="

extract flit_core-3.12.0.tar.gz

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist flit_core

cd /sources

####################################################
### 8.53 Packaging-25.0
####################################################
echo "===== 8.53 Packaging-25.0 ====="

extract packaging-25.0.tar.gz

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist packaging

cd /sources

####################################################
### 8.54 Wheel-0.46.1
####################################################
echo "===== 8.54 Wheel-0.46.1 ====="

extract wheel-0.46.1.tar.gz

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist wheel

cd /sources

####################################################
### 8.55 Setuptools-80.9.0
####################################################
echo "===== 8.55 Setuptools-80.9.0 ====="

extract setuptools-80.9.0.tar.gz

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist setuptools

cd /sources

####################################################
### 8.56 Ninja-1.13.1
####################################################
echo "===== 8.56 Ninja-1.13.1 ====="

extract ninja-1.13.1.tar.gz

export NINJAJOBS=4
# Optional (from book): allow NINJAJOBS env var
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc

python3 configure.py --bootstrap --verbose

install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

cd /sources

####################################################
### 8.57 Meson-1.8.3
####################################################
echo "===== 8.57 Meson-1.8.3 ====="

extract meson-1.8.3.tar.gz

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist meson

install -vDm644 data/shell-completions/bash/meson \
       /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson \
       /usr/share/zsh/site-functions/_meson

cd /sources

####################################################
### 8.58 Kmod-34.2
####################################################
echo "===== 8.58 Kmod-34.2 ====="

extract kmod-34.2.tar.xz

mkdir -p build
cd       build

meson setup --prefix=/usr ..    \
            --buildtype=release \
            -D manpages=false

ninja
ninja install

cd /sources

####################################################
### 8.59 Coreutils-9.7
####################################################
echo "===== 8.59 Coreutils-9.7 ====="

extract coreutils-9.7.tar.xz

patch -Np1 -i ../coreutils-9.7-upstream_fix-1.patch
patch -Np1 -i ../coreutils-9.7-i18n-1.patch

autoreconf -fv
automake -af

FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime

make

# Full test sequence from the book (optional, requires user 'tester'):
# make NON_ROOT_USERNAME=tester check-root
# groupadd -g 102 dummy -U tester
# chown -R tester .
# su tester -c "PATH=$PATH make -k RUN_EXPENSIVE_TESTS=yes check" < /dev/null
# groupdel dummy

make install

mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8

cd /sources

####################################################
### 8.60 Diffutils-3.12
####################################################
echo "===== 8.60 Diffutils-3.12 ====="

extract diffutils-3.12.tar.xz

./configure --prefix=/usr
make
# optional: make check
make install

cd /sources

echo "===== Block 4 Finished (8.50 → 8.60) ====="
