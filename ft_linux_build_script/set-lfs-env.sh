#!/bin/bash
set -e

export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=$LFS/tools/bin:/usr/bin:/bin
export CONFIG_SITE=$LFS/usr/share/config.site

echo "Environment set:"
echo "LFS=$LFS"
echo "LFS_TGT=$LFS_TGT"
echo "PATH=$PATH"
echo "CONFIG_SITE=$CONFIG_SITE"
