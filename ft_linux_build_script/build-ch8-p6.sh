#!/bin/bash
# LFS 12.4 — Chapter 8 (Block 5: last packages)
# NOTE: Due to no live access to the online book, Udev/systemd section is a placeholder:
#       copy the exact Meson/ninja commands from your local LFS 12.4 book into that part.

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
### 8.71 Tar-1.35
############################################
echo "===== 8.71 Tar-1.35 ====="

extract tar-1.35.tar.xz

FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr

make
# optional: make check
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35

cd /sources

############################################
### 8.72 Texinfo-7.2
############################################
echo "===== 8.72 Texinfo-7.2 ====="

extract texinfo-7.2.tar.xz

sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm

./configure --prefix=/usr

make
# optional: make check
make install
make TEXMF=/usr/share/texmf install-tex

cd /sources

############################################
### 8.73 Vim-9.1.1629
############################################
echo "===== 8.73 Vim-9.1.1629 ====="

extract vim-9.1.1629.tar.gz

# Set system-wide vimrc path
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h

./configure --prefix=/usr

make
# Optional tests (usually as a non-root user):
# chown -Rv tester .
# su tester -c "LANG=en_US.UTF-8 make test" </dev/null

make install

ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done

ln -sv ../vim/vim91/doc /usr/share/doc/vim-9.1.1629

cd /sources

############################################
### 8.74 MarkupSafe-3.0.2
############################################
echo "===== 8.74 MarkupSafe-3.0.2 ====="

extract markupsafe-3.0.2.tar.gz

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist Markupsafe

cd /sources

############################################
### 8.75 Jinja2-3.1.6
############################################
echo "===== 8.75 Jinja2-3.1.6 ====="

extract jinja2-3.1.6.tar.gz

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist Jinja2

cd /sources

############################################
### 8.xx Udev from systemd-257.8
############################################
echo "===== 8.xx Udev from systemd-257.8 ====="

extract systemd-257.8.tar.gz

sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //'               \
    -i rules.d/50-udev-default.rules.in

sed -i '/systemd-sysctl/s/^/#/' rules.d/99-systemd.rules.in

sed -e '/NETWORK_DIRS/s/systemd/udev/' \
    -i src/libsystemd/sd-network/network-util.h

mkdir -p build
cd       build

meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -D mode=release           \
      -D dev-kvm-mode=0660      \
      -D link-udev-shared=false \
      -D logind=false           \
      -D vconsole=false

export udev_helpers=$(grep "'name' :" ../src/udev/meson.build | \
                      awk '{print $3}' | tr -d ",'" | grep -v 'udevadm')


ninja udevadm systemd-hwdb                                           \
      $(ninja -n | grep -Eo '(src/(lib)?udev|rules.d|hwdb.d)/[^ ]*') \
      $(realpath libudev.so --relative-to .)                         \
      $udev_helpers

install -vm755 -d {/usr/lib,/etc}/udev/{hwdb.d,rules.d,network}
install -vm755 -d /usr/{lib,share}/pkgconfig
install -vm755 udevadm                             /usr/bin/
install -vm755 systemd-hwdb                        /usr/bin/udev-hwdb
ln      -svfn  ../bin/udevadm                      /usr/sbin/udevd
cp      -av    libudev.so{,*[0-9]}                 /usr/lib/
install -vm644 ../src/libudev/libudev.h            /usr/include/
install -vm644 src/libudev/*.pc                    /usr/lib/pkgconfig/
install -vm644 src/udev/*.pc                       /usr/share/pkgconfig/
install -vm644 ../src/udev/udev.conf               /etc/udev/
install -vm644 rules.d/* ../rules.d/README         /usr/lib/udev/rules.d/
install -vm644 $(find ../rules.d/*.rules \
                      -not -name '*power-switch*') /usr/lib/udev/rules.d/
install -vm644 hwdb.d/*  ../hwdb.d/{*.hwdb,README} /usr/lib/udev/hwdb.d/
install -vm755 $udev_helpers                       /usr/lib/udev
install -vm644 ../network/99-default.link          /usr/lib/udev/network

tar -xvf ../../udev-lfs-20230818.tar.xz
make -f udev-lfs-20230818/Makefile.lfs install

tar -xf ../../systemd-man-pages-257.8.tar.xz                            \
    --no-same-owner --strip-components=1                              \
    -C /usr/share/man --wildcards '*/udev*' '*/libudev*'              \
                                  '*/systemd.link.5'                  \
                                  '*/systemd-'{hwdb,udevd.service}.8

sed 's|systemd/network|udev/network|'                                 \
    /usr/share/man/man5/systemd.link.5                                \
  > /usr/share/man/man5/udev.link.5

sed 's/systemd\(\\\?-\)/udev\1/' /usr/share/man/man8/systemd-hwdb.8   \
                               > /usr/share/man/man8/udev-hwdb.8

sed 's|lib.*udevd|sbin/udevd|'                                        \
    /usr/share/man/man8/systemd-udevd.service.8                       \
  > /usr/share/man/man8/udevd.8

rm /usr/share/man/man*/systemd*

unset udev_helpers

cd /sources

############################################
### 8.76 Man-DB-2.13.1
############################################
echo "===== 8.76 Man-DB-2.13.1 ====="

extract man-db-2.13.1.tar.xz

./configure --prefix=/usr                         \
            --docdir=/usr/share/doc/man-db-2.13.1 \
            --sysconfdir=/etc                     \
            --disable-setuid                      \
            --enable-cache-owner=bin              \
            --with-browser=/usr/bin/lynx          \
            --with-vgrind=/usr/bin/vgrind         \
            --with-grap=/usr/bin/grap             \
            --with-systemdtmpfilesdir=            \
            --with-systemdsystemunitdir=
make
# optional: make check
make install

cd /sources

############################################
### 8.77 Procps-ng-4.0.5
############################################
echo "===== 8.77 Procps-ng-4.0.5 ====="

extract procps-ng-4.0.5.tar.xz

./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.5 \
            --disable-static                        \
            --disable-kill                          \
            --enable-watch8bit
make
# optional: make check
make install

cd /sources

############################################
### 8.78 Util-linux-2.41.1
############################################
echo "===== 8.78 Util-linux-2.41.1 ====="

extract util-linux-2.41.1.tar.xz

# Ensure hwclock directory exists
mkdir -pv /var/lib/hwclock

./configure --bindir=/usr/bin     \
            --libdir=/usr/lib     \
            --runstatedir=/run    \
            --sbindir=/usr/sbin   \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-liblastlog2 \
            --disable-static      \
            --without-python      \
            --without-systemd     \
            --without-systemdsystemunitdir        \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.41.1
make
# optional: make check
make install

cd /sources

############################################
### 8.79 E2fsprogs-1.47.3
############################################
echo "===== 8.79 E2fsprogs-1.47.3 ====="

extract e2fsprogs-1.47.3.tar.gz

mkdir -v build
cd build

../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-elf-shlibs \
             --disable-libblkid  \
             --disable-libuuid   \
             --disable-uuidd     \
             --disable-fsck
make
# optional: make check
make install

rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info

sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf

cd /sources

############################################
### 8.80 Sysklogd-2.7.2
############################################
echo "===== 8.80 Sysklogd-2.7.2 ====="

extract sysklogd-2.7.2.tar.gz

./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --runstatedir=/run \
            --without-logger   \
            --disable-static   \
            --docdir=/usr/share/doc/sysklogd-2.7.2

make
make install

cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# Do not open any internet ports.
secure_mode 2

# End /etc/syslog.conf
EOF

cd /sources

############################################
### 8.81 SysVinit-3.14
############################################
echo "===== 8.81 SysVinit-3.14 ====="

extract sysvinit-3.14.tar.xz

patch -Np1 -i ../sysvinit-3.14-consolidated-1.patch

make
make install

cd /sources

echo "===== Block 6 Finished (Tar → SysVinit) ====="
echo "Reminder: Udev from systemd-257.8 must be built manually following your LFS 12.4 book. need to config Udev"
