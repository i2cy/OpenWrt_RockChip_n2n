#!/bin/bash

REPO_URL=https://github.com/DHDAXCW/lede-rockchip
REPO_BRANCH=stable
CONFIG_FILE=configs/lede/full.config
CUSTOM_CONF=configs/lede/i2cy.config
DIY_SH=scripts/lede.sh
export KMODS_IN_FIRMWARE=true
export UPLOAD_RELEASE=true
export TZ=Asia/Shanghai

export nproc=64

echo "[build.sh]: updating environments..."
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \
git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev \
libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev libreadline-dev \
libssl-dev libtool lrzsz mkisofs msmtp ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 \
python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion swig texinfo \
uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev


echo "[build.sh]: clone sources..."
df -hT $PWD
export GITHUB_WORKSPACE=$PWD
git clone $REPO_URL -b $REPO_BRANCH openwrt

echo "[build.sh]: updating feeds..."
cd openwrt
export OPENWRTROOT=$PWD
mkdir customfeeds
git clone --depth=1 https://github.com/DHDAXCW/packages customfeeds/packages
git clone --depth=1 https://github.com/DHDAXCW/luci customfeeds/luci
chmod +x ../scripts/*.sh
../scripts/hook-feeds.sh

echo "[build.sh]: installing feeds..."
cd $GITHUB_WORKSPACE
cd $OPENWRTROOT
./scripts/feeds install -a

echo "[build.sh]: loading custom configurations..."
cd $GITHUB_WORKSPACE
[ -e files ] && mv files $OPENWRTROOT/files
[ -e $CONFIG_FILE ] && mv $CONFIG_FILE $OPENWRTROOT/.config
cat $CUSTOM_CONF >> $OPENWRTROOT/.config
chmod +x scripts/*.sh
cd $OPENWRTROOT
../$DIY_SH
../scripts/preset-clash-core.sh arm64
../scripts/preset-terminal-tools.sh
make defconfig
make menuconfig

echo "[build.sh]: downloading packages..."
cd $GITHUB_WORKSPACE
cd $OPENWRTROOT
cat .config
make download -j50
make download -j1
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;

echo "[build.sh]: compile packages..."
cd $OPENWRTROOT
echo -e "$(nproc) thread compile"
make tools/compile -j$(nproc) || make tools/compile -j$(nproc)
make toolchain/compile -j$(nproc) || make toolchain/compile -j$(nproc)
make target/compile -j$(nproc) || make target/compile -j$(nproc) IGNORE_ERRORS=1
make diffconfig
make package/compile -j$(nproc) IGNORE_ERRORS=1 || make package/compile -j$(nproc) IGNORE_ERRORS=1
make package/index
cd $OPENWRTROOT/bin/packages/*
PLATFORM=$(basename `pwd`)
cd $OPENWRTROOT/bin/targets/*
TARGET=$(basename `pwd`)
cd *
SUBTARGET=$(basename `pwd`)

echo "[build.sh]: generating firmware..."
cd $GITHUB_WORKSPACE
cd configs/opkg
sed -i "s/subtarget/$SUBTARGET/g" distfeeds*.conf
sed -i "s/target\//$TARGET\//g" distfeeds*.conf
sed -i "s/platform/$PLATFORM/g" distfeeds*.conf
cd $OPENWRTROOT
mkdir -p files/etc/uci-defaults/
cp ../scripts/init-settings.sh files/etc/uci-defaults/99-init-settings
mkdir -p files/etc/opkg
cp ../configs/opkg/distfeeds-packages-server.conf files/etc/opkg/distfeeds.conf.server
mkdir -p files/etc/opkg/keys
cp ../configs/opkg/1035ac73cc4e59e3 files/etc/opkg/keys/1035ac73cc4e59e3
if "$KMODS_IN_FIRMWARE" = 'true'
then
    mkdir -p files/www/snapshots
    cp -r bin/targets files/www/snapshots
    cp ../configs/opkg/distfeeds-18.06-local.conf files/etc/opkg/distfeeds.conf
else
    cp ../configs/opkg/distfeeds-18.06-remote.conf files/etc/opkg/distfeeds.conf
fi
cp files/etc/opkg/distfeeds.conf.server files/etc/opkg/distfeeds.conf.mirror
sed -i "s/http:\/\/192.168.123.100:2345\/snapshots/https:\/\/openwrt.cc\/snapshots\/$(date +"%Y-%m-%d")\/lean/g" files/etc/opkg/distfeeds.conf.mirror
make package/install -j$(nproc) || make package/install -j1 V=sc
make target/install -j$(nproc) || make target/install -j1 V=sc
pushd bin/targets/rockchip/armv8
rm -rf *ext4* *.manifest packages *.json *.buildinfo
mv openwrt-rockchip-armv8-embedfire_doornet1-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-embedfire_doornet1-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-embedfire_doornet2-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-embedfire_doornet2-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-embedfire_lubancat-1n-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-embedfire_lubancat-1n-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-embedfire_lubancat-1-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-embedfire_lubancat-1-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-embedfire_lubancat-2n-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-embedfire_lubancat-2n-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-embedfire_lubancat-2-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-embedfire_lubancat-2-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-embedfire_lubancat-4-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-embedfire_lubancat-4-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-embedfire_lubancat-5-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-embedfire_lubancat-5-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopc-t6-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopc-t6-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopi-r2c-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopi-r2c-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopi-r2s-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopi-r4se-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopi-r4se-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopi-r5c-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopi-r5c-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopi-r5s-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopi-r5s-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopi-r6c-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopi-r6c-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-friendlyarm_nanopi-r6s-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-friendlyarm_nanopi-r6s-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-hinlink_h88k-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-hinlink_h88k-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-hinlink_opc-h66k-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-hinlink_opc-h66k-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-hinlink_opc-h68k-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-hinlink_opc-h68k-squashfs-sysupgrade.img.gz
mv openwrt-rockchip-armv8-hinlink_opc-h69k-squashfs-sysupgrade.img.gz $(date +"%Y.%m.%d")-docker-openwrt-hinlink_opc-h69k-squashfs-sysupgrade.img.gz
popd
make checksum
mv bin/targets/rockchip/armv8/sha256sums bin/targets/rockchip/armv8/docker-sha256sums

echo "[build.sh] build complete"
