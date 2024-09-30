#!/usr/bin/env bash

## A script for creating Ubuntu bootstraps for Wine compilation.
##
## debootstrap and perl are required
## root rights are required
##
## About 5.5 GB of free space is required
## And additional 2.5 GB is required for Wine compilation

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root rights!"
    exit 1
fi

# Check for required tools
if ! command -v debootstrap >/dev/null || ! command -v perl >/dev/null; then
    echo "Please install debootstrap and perl and run the script again."
    exit 1
fi

# Define variables
CHROOT_DISTRO="bionic"
CHROOT_MIRROR="https://ftp.uni-stuttgart.de/ubuntu/"
MAINDIR="/opt/chroot/"
CHROOT_X32="${MAINDIR}/${CHROOT_DISTRO}32_chroot"
CHROOT_X64="${MAINDIR}/${CHROOT_DISTRO}64_chroot"

# Function to prepare chroot
prepare_chroot () {
    local arch=$1
    local chroot_path="${MAINDIR}/${CHROOT_DISTRO}${arch}_chroot"

    echo "Unmounting any chroot directories (if mounted)..."
    umount -Rl "${chroot_path}" 2>/dev/null

    echo "Mounting necessary directories for chroot..."
    mount --bind "${chroot_path}" "${chroot_path}"
    mount -t proc /proc "${chroot_path}/proc"
    mount --bind /sys "${chroot_path}/sys"
    mount --make-rslave "${chroot_path}/sys"
    mount --bind /dev "${chroot_path}/dev"
    mount --bind /dev/pts "${chroot_path}/dev/pts"
    mount --bind /dev/shm "${chroot_path}/dev/shm"
    mount --make-rslave "${chroot_path}/dev"

    echo "Setting up DNS resolution for chroot..."
    rm -f "${chroot_path}/etc/resolv.conf"
    cp /etc/resolv.conf "${chroot_path}/etc/resolv.conf"

    echo "Entering the chroot environment..."
    chroot "${chroot_path}" /usr/bin/env LANG=en_US.UTF-8 TERM=xterm \
        PATH="/bin:/sbin:/usr/bin:/usr/sbin" /opt/prepare_chroot.sh

    echo "Unmounting chroot directories..."
    umount -l "${chroot_path}"
    umount "${chroot_path}/proc"
    umount "${chroot_path}/sys"
    umount "${chroot_path}/dev/pts"
    umount "${chroot_path}/dev/shm"
    umount "${chroot_path}/dev"
}

# Function to create the build scripts inside chroot
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
apt-get -y install nano locales
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO} main universe" > /etc/apt/sources.list
echo "deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-updates main universe" >> /etc/apt/sources.list
echo "deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-security main universe" >> /etc/apt/sources.list
echo "deb-src '${CHROOT_MIRROR}' ${CHROOT_DISTRO} main universe" >> /etc/apt/sources.list
echo "deb-src '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-updates main universe" >> /etc/apt/sources.list
echo "deb-src '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-security main universe" >> /etc/apt/sources.list
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install software-properties-common ccache cmake perl bison gcc-9 g++-9 wget git gcc-mingw-w64 g++-mingw-w64

add-apt-repository -y ppa:ubuntu-toolchain-r/test
add-apt-repository -y ppa:cybermax-dexter/mingw-w64-backport

apt-get update
apt-get -y build-dep wine-development libsdl2 libvulkan1
apt-get -y install libxpresent-dev libusb-1.0-0-dev libgcrypt20-dev libpulse-dev \
libudev-dev libsane-dev libv4l-dev libkrb5-dev libgphoto2-dev liblcms2-dev \
libcapi20-dev libjpeg62-dev samba-dev libpcsclite-dev libcups2-dev python3-pip \
libxcb-xkb-dev

pip3 install --upgrade meson ninja

# Compile SDL2, FAudio, Vulkan, etc.
mkdir -p /opt/build_libs && cd /opt/build_libs
wget -O sdl.tar.gz https://www.libsdl.org/release/SDL2-${sdl2_version}.tar.gz
wget -O faudio.tar.gz https://github.com/FNA-XNA/FAudio/archive/${faudio_version}.tar.gz
wget -O vulkan-loader.tar.gz https://github.com/KhronosGroup/Vulkan-Loader/archive/v${vulkan_loader_version}.tar.gz
wget -O vulkan-headers.tar.gz https://github.com/KhronosGroup/Vulkan-Headers/archive/v${vulkan_headers_version}.tar.gz
wget -O spirv-headers.tar.gz https://github.com/KhronosGroup/SPIRV-Headers/archive/${spirv_headers_version}.tar.gz
wget -O libpcap.tar.gz https://www.tcpdump.org/release/libpcap-${libpcap_version}.tar.gz
wget -O libxkbcommon.tar.xz https://xkbcommon.org/download/libxkbcommon-${libxkbcommon_version}.tar.xz

# Build and install libraries
tar xf sdl.tar.gz && cd SDL2-${sdl2_version} && mkdir build && cd build && cmake .. && make -j\$(nproc) && make install
cd /opt/build_libs && rm -rf SDL2-${sdl2_version}

# Repeat similar steps for other libraries...
EOF

    chmod +x "${MAINDIR}/prepare_chroot.sh"
    cp "${MAINDIR}/prepare_chroot.sh" "${CHROOT_X32}/opt"
    cp "${MAINDIR}/prepare_chroot.sh" "${CHROOT_X64}/opt"
}

# Main process
mkdir -p "${MAINDIR}"

# Create debootstrap environments
debootstrap --arch amd64 "$CHROOT_DISTRO" "${CHROOT_X64}" "$CHROOT_MIRROR"
debootstrap --arch i386 "$CHROOT_DISTRO" "${CHROOT_X32}" "$CHROOT_MIRROR"

# Prepare chroots
create_build_scripts
prepare_chroot 32
prepare_chroot 64

# Cleanup
rm "${CHROOT_X64}/opt/prepare_chroot.sh"
rm "${CHROOT_X32}/opt/prepare_chroot.sh"

echo "All done!"
