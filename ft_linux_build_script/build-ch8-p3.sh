#!/bin/bash
# LFS 12.4 — Chapter 8 (Block 2: 8.39 → 8.48)
# EXACT commands from the book, adjusted only for your tarball names.

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
### 8.39 Gperf-3.3
####################################################
echo "===== 8.39 Gperf-3.3 ====="

extract gperf-3.3.tar.gz

./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
make
# optional: make check
make install

cd /sources

####################################################
### 8.39 Expat-2.7.1
####################################################
echo "===== 8.39 Expat-2.7.1 ====="

extract expat-2.7.1.tar.xz

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.7.1

make
# optional: make check
make install
install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.1

cd /sources

####################################################
### 8.40 Inetutils-2.6
####################################################
echo "===== 8.40 Inetutils-2.6 ====="

extract inetutils-2.6.tar.xz

sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c

./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers
make
# optional: make check
make install
mv -v /usr/{,s}bin/ifconfig

cd /sources

####################################################
### 8.41 Less-679
####################################################
echo "===== 8.41 Less-679 ====="

extract less-679.tar.gz

./configure --prefix=/usr --sysconfdir=/etc
make
make install

cd /sources

####################################################
### 8.42 Perl-5.42.0
####################################################
echo "===== 8.42 Perl-5.42.0 ====="

extract perl-5.42.0.tar.xz

export BUILD_ZLIB=False
export BUILD_BZIP2=0

sh Configure -des                                          \
             -D prefix=/usr                                \
             -D vendorprefix=/usr                          \
             -D privlib=/usr/lib/perl5/5.42/core_perl      \
             -D archlib=/usr/lib/perl5/5.42/core_perl      \
             -D sitelib=/usr/lib/perl5/5.42/site_perl      \
             -D sitearch=/usr/lib/perl5/5.42/site_perl     \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl  \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl \
             -D man1dir=/usr/share/man/man1                \
             -D man3dir=/usr/share/man/man3                \
             -D pager="/usr/bin/less -isR"                 \
             -D useshrplib                                 \
             -D usethreads
make
# optional: make test
make install
unset BUILD_ZLIB BUILD_BZIP2

cd /sources

####################################################
### 8.43 XML::Parser-2.47
####################################################
echo "===== 8.43 XML::Parser-2.47 ====="

extract XML-Parser-2.47.tar.gz

perl Makefile.PL
make
# optional: make test
make install

cd /sources

####################################################
### 8.44 Intltool-0.51.0
####################################################
echo "===== 8.44 Intltool-0.51.0 ====="

extract intltool-0.51.0.tar.gz

sed -i 's:\\\${:\\\$\\{:' intltool-update.in

./configure --prefix=/usr
make
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO

cd /sources

####################################################
### 8.45 Autoconf-2.72
####################################################
echo "===== 8.45 Autoconf-2.72 ====="

extract autoconf-2.72.tar.xz

./configure --prefix=/usr
make
# optional: make check
make install

cd /sources

####################################################
### 8.46 Automake-1.18.1
####################################################
echo "===== 8.46 Automake-1.18.1 ====="

extract automake-1.18.1.tar.xz


./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1
make
# optional: make check
make install

cd /sources

####################################################
### 8.47 OpenSSL-3.5.2
####################################################
echo "===== 8.47 OpenSSL-3.5.2 ====="

extract openssl-3.5.2.tar.gz

./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make
# optional: make test
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install

mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.5.2
cp -vfr doc/* /usr/share/doc/openssl-3.5.2

cd /sources

####################################################
### 8.48 Libelf from elfutils-0.193
####################################################
echo "===== 8.48 Elfutils-0.193 (libelf only) ====="

extract elfutils-0.193.tar.bz2

./configure --prefix=/usr \
            --disable-debuginfod \
			--enable-libdebuginfod=dummy

make
# optional: make check
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a

cd /sources

echo "===== Block 3 Finished (8.39 → 8.48) ====="
