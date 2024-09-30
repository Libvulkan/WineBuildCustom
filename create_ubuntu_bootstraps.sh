#!/usr/bin/env bash

## A script for creating Ubuntu bootstraps for Wine compilation.
##
## debootstrap and perl are required
## root rights are required
##
## About 5.5 GB of free space is required
## And additional 2.5 GB is required for Wine compilation

if [ "$EUID" != 0 ]; then
    echo "This script requires root rights!"
    exit 1
fi

if ! command -v debootstrap 1>/dev/null || ! command -v perl 1>/dev/null; then
    echo "Please install debootstrap and perl and run the script again"
    exit 1
fi

export CHROOT_DISTRO="bionic"
export CHROOT_MIRROR="https://ftp.uni-stuttgart.de/ubuntu/"
export MAINDIR=/opt/chroot/
export CHROOT_X32="${MAINDIR}/${CHROOT_DISTRO}32_chroot"
export CHROOT_X64="${MAINDIR}/${CHROOT_DISTRO}64_chroot"

prepare_chroot () {
    CHROOT_PATH="${1}"

    echo "Unmount chroot directories. Just in case."
    umount -Rl "${CHROOT_PATH}"

    echo "Mount directories for chroot"
    mount --bind "${CHROOT_PATH}" "${CHROOT_PATH}"
    mount -t proc /proc "${CHROOT_PATH}/proc"
    mount --bind /sys "${CHROOT_PATH}/sys"
    mount --make-rslave "${CHROOT_PATH}/sys"
    mount --bind /dev "${CHROOT_PATH}/dev"
    mount --bind /dev/pts "${CHROOT_PATH}/dev/pts"
    mount --bind /dev/shm "${CHROOT_PATH}/dev/shm"
    mount --make-rslave "${CHROOT_PATH}/dev"

    rm -f "${CHROOT_PATH}/etc/resolv.conf"
    cp /etc/resolv.conf "${CHROOT_PATH}/etc/resolv.conf"

    echo "Chrooting into ${CHROOT_PATH}"
    chroot "${CHROOT_PATH}" /usr/bin/env LANG=en_US.UTF-8 TERM=xterm PATH="/bin:/sbin:/usr/bin:/usr/sbin" /opt/prepare_chroot.sh

    echo "Unmount chroot directories"
    umount -l "${CHROOT_PATH}"
    umount "${CHROOT_PATH}/proc"
    umount "${CHROOT_PATH}/sys"
    umount "${CHROOT_PATH}/dev/pts"
    umount "${CHROOT_PATH}/dev/shm"
    umount "${CHROOT_PATH}/dev"
}

create_build_scripts () {
    sdl2_version="2.26.4"
    faudio_version="23.03"
    vulkan_headers_version="1.3.239"
    vulkan_loader_version="1.3.239"
    spirv_headers_version="sdk-1.3.239.0"
    libpcap_version="1.10.4"
    libxkbcommon_version="1.6.0"

    cat <<EOF > "${MAINDIR}/prepare_chroot.sh"
#!/bin/bash

apt-get update
apt-get -y install nano
apt-get -y install locales
echo ru_RU.UTF_8 UTF-8 >> /etc/locale.gen
echo en_US.UTF_8 UTF-8 >> /etc/locale.gen
locale-gen
echo deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO} main universe > /etc/apt/sources.list
echo deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-updates main universe >> /etc/apt/sources.list
echo deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-security main universe >> /etc/apt/sources.list
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install software-properties-common
add-apt-repository -y ppa:ubuntu-toolchain-r/test
add-apt-repository -y ppa:cybermax-dexter/mingw-w64-backport
apt-get update
apt-get -y build-dep wine-development libsdl2 libvulkan1
apt-get -y install ccache cmake perl bison gcc-9 g++-9 wget git gcc-mingw-w64 g++-mingw-w64
apt-get -y install libxpresent-dev libjxr-dev libusb-1.0-0-dev libgcrypt20-dev libpulse-dev libudev-dev libsane-dev libv4l-dev libkrb5-dev libgphoto2-dev liblcms2-dev libcapi20-dev
apt-get -y install libjpeg62-dev samba-dev
apt-get -y install libpcsclite-dev libcups2-dev
apt-get -y install python3.7 python3-pip libxcb-xkb-dev
apt-get -y clean
apt-get -y autoclean
pip3 install --upgrade meson ninja
export PATH="/usr/local/bin:${PATH}"
mkdir /opt/build_libs
cd /opt/build_libs
wget -O sdl.tar.gz https://www.libsdl.org/release/SDL2-${sdl2_version}.tar.gz
wget -O faudio.tar.gz https://github.com/FNA-XNA/FAudio/archive/${faudio_version}.tar.gz
wget -O vulkan-loader.tar.gz https://github.com/KhronosGroup/Vulkan-Loader/archive/v${vulkan_loader_version}.tar.gz
wget -O vulkan-headers.tar.gz https://github.com/KhronosGroup/Vulkan-Headers/archive/v${vulkan_headers_version}.tar.gz
wget -O spirv-headers.tar.gz https://github.com/KhronosGroup/SPIRV-Headers/archive/${spirv_headers_version}.tar.gz
wget -O libpcap.tar.gz https://www.tcpdump.org/release/libpcap-${libpcap_version}.tar.gz
wget -O libxkbcommon.tar.xz https://xkbcommon.org/download/libxkbcommon-${libxkbcommon_version}.tar.xz
git clone https://gitlab.winehq.org/wine/vkd3d.git
# Build libraries
#...
EOF

    chmod +x "${MAINDIR}/prepare_chroot.sh"
    cp "${MAINDIR}/prepare_chroot.sh" "${CHROOT_X32}/opt"
    mv "${MAINDIR}/prepare_chroot.sh" "${CHROOT_X64}/opt"
}

mkdir -p "${MAINDIR}"

debootstrap --arch amd64 $CHROOT_DISTRO "${CHROOT_X64}" $CHROOT_MIRROR || { echo "debootstrap failed for amd64"; exit 1; }
debootstrap --arch i386 $CHROOT_DISTRO "${CHROOT_X32}" $CHROOT_MIRROR || { echo "debootstrap failed for i386"; exit 1; }

create_build_scripts
prepare_chroot 32
prepare_chroot 64

rm "${CHROOT_X64}/opt/prepare_chroot.sh"
rm "${CHROOT_X32}/opt/prepare_chroot.sh"

clear
echo "Done"
