#!/bin/bash

echo "Running Cryptosmite_host"
# Thanks Mattias Nissler for the vuln https://chromium-review.googlesource.com/c/chromiumos/platform2/+/922063 :)
# Avoids adding new partitions and expanding disk image space, so we don't require larger usbs to flash ()This is no longer accurate
FILE_PATH=$(dirname "${0}")
source ./lib/common_minimal.sh
if [ $(id -u) -ne 0 ]
then
    echo "You need to run this script as root"
    exit
fi
if [ "$#" -ne 3 ]
then
    echo "Usage: <rma shim path> <cryptsetup.tar.xz path> <stateful.tar.xz>"
    echo "If you need the last two files, please read the readme"
    exit 0;
fi
bb() {
    local font_blue_bold="\033[94;1m"
    local font_end="\033[0m"

    echo -e "\n${font_blue_bold}${1}${font_end}"
}
echo "Please make sure you have backed up your original RMA Shim. Any changes made here will modify the original rma shim, and there is a high chance it will break. (I recommend using tmpfs in your linux environment to modify the shim. If you have windows, WSL is an option)"
echo "If you would like to back up your shim, please press ctrl-c within 3 seconds, backup your shim, and run this again, otherwise you are on your own."

sleep 3

echo "Modifying shim now this script will take a while..."
SHIMPATH=$1
STATEFULPATH=$3
CRYPTSETUP_PATH=$2
MAKEUSRLOCAL=1

if grep "usrlocal" ${SHIMPATH}; then
    MAKEUSRLOCAL=0
    echo "usrlocal partition exists, skipping"
else
    bb "[Extending shim]"
    if [[ ${SHIMPATH} == /dev* ]]
    then
        echo "Not extending attached device"
    else
        dd if=/dev/zero bs=100M status=progress count=1 >> "$SHIMPATH"
    
    # Fix corrupt gpt
        (echo "w") | fdisk "$SHIMPATH"
    fi
    bb "[Create usrlocal partition]"
    (echo -e "size=100M") | sfdisk "$SHIMPATH" -N 13
fi


bb "[Setting up loopfs to shim]"
mount -t tmpfs tmpfs /tmp/
shimmnt=$(mktemp -d)
lastlooppart=$(losetup -f)
losetup -fP "$SHIMPATH"
echo "Made loopfs on ${lastlooppart}"
enable_rw_mount /dev/loop0p3
if [ "$MAKEUSRLOCAL" == 0 ];
then
    echo "usrlocal partiton exists, skipping format"
else
    mkfs.ext4 "${lastlooppart}p13" -L usrlocal
fi

bb "[Loading SHIM stateful]"
mkfs.ext4 "${lastlooppart}p1" -F -L shimstate # Need to erase stateful, there isn't much space on there but is just enough to contain 65MB worth of packages (including apk)
mount -o loop,rw "${lastlooppart}p1" "$shimmnt"
mount | grep "stateful"
echo "Copying stateful.tar.xz to shim"
dd if="${STATEFULPATH}" of="${shimmnt}/stateful.tar.xz" status=progress
echo "Extracting cryptsetup.tar.xz to shim"
mkdir "${shimmnt}/cryptsetup_root" -p
mkdir "${shimmnt}/dev_image/" -p
mkdir "${shimmnt}/dev_image/etc" -p
touch "${shimmnt}/dev_image/etc/lsb-factory"
tar -C "${shimmnt}/cryptsetup_root" -xf "${CRYPTSETUP_PATH}"
echo "Cleaning up stateful mounts"
umount "${shimmnt}"

bb "[Loading shim root]"
echo "Making rootfs writable if not already"
source ./lib/common_minimal.sh
enable_rw_mount "${lastlooppart}p3"
sync
sync
sync
mount -o loop,rw "${lastlooppart}p3" "${shimmnt}"
mv "${shimmnt}/usr/sbin/factory_install.sh" "${shimmnt}/usr/sbin/factory_install.sh.old"
cp factory_install.sh "${shimmnt}/usr/sbin/factory_install.sh"
chmod +x "${shimmnt}/usr/sbin/factory_install.sh"

bb "[Loading usrlocal partition]"
partx -a ${lastlooppart}
mount "${lastlooppart}p13" "${shimmnt}/usr/local/"
mkdir -p "${shimmnt}/usr/local/bin"
cp -v cryptosmite.sh "${shimmnt}/usr/local/bin/"
cp -v sh1mmer.sh "${shimmnt}/usr/local/bin/sh1mmer"
echo "Cleaning up shim root"
cp cryptsetup* "${shimmnt}/usr/local/bin/"
umount "${shimmnt}/usr/local"
umount "${shimmnt}"
bb "Finished, please boot into shim to see effects"
losetup -D
