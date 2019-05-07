#!/usr/bin/env bash

#?/index        2
#?/synopsis     usb [subcommand]
#?/summary      manages the virtual USB mass storage functionality

#?/description
#? Manages the virtual USB mass storage mode, allowing for control over
#? creation, state, etc.
#?
#? Available subcommands are:
#?
#?   status         Displays status information for the virtual device.
#?
#?   build          Builds a new volume, replacing a preexisting one. Then
#?                  mounts it and enables mass storage mode.
#?
#?   destroy        Removes any preexisting volumes, disables mass storage mode,
#?                  and unmounts.
#?
#?   enable         Enables USB mass storage mode.
#?
#?   disable        Disables USB mass storage mode.
#?
#?   mount          Mounts an existing container.
#?
#?   unmount        Unmounts a mounted container.
#?
#?   repair         Repairs a mounted volume that wasn't ejected properly.
#?
#?   ls             Lists the contents of the volume's filesystem.
#?
#?   sync           Synchronizes the volume's contents with the cloud.

source "${DIR}/lib/utils.sh"
source "${DIR}/lib/arg.sh"

usb::status() {
	local volume_label && volume_label=$(grep "\/piusb.bin" /etc/fstab | grep -Po '\/mnt\/\K[^\s]*')
	local container_path="/piusb.bin"
	local mount_point="/mnt/${volume_label}"
	local mass_storage_status

	if lsmod | grep -q ^g_mass_storage; then
		mass_storage_status="@GREEN(ENABLED)"
	else
		mass_storage_status="@RED(DISABLED)"
	fi

	if [ -z "$volume_label" ]; then
		mount_point="@RED(UNMOUNTED)"
	fi

	out	" Volume Label:           $volume_label"
	out	" Container:              $container_path"
	out	" Mounted:                $mount_point"
	out	" USB Mass Storage:       $mass_storage_status"

	out	"@DIV"

	local storage && storage=$(df -H | grep "${mount_point}")
	local storage_total && storage_total=$(arg::default "--" "$(echo "$storage" | sed -E 's/^[^ ]*\s*([^ ]*) *([^ ]*) *([^ ]*) *([^ ]*) *(.*)$/\1/')")
	local storage_used && storage_used=$(arg::default "--" "$(echo "$storage" | sed -E 's/^[^ ]*\s*([^ ]*) *([^ ]*) *([^ ]*) *([^ ]*) *(.*)$/\2/')")
	local storage_free && storage_free=$(arg::default "--" "$(echo "$storage" | sed -E 's/^[^ ]*\s*([^ ]*) *([^ ]*) *([^ ]*) *([^ ]*) *(.*)$/\3/')")
	local storage_teslacam

	out	" Size:                   $storage_total"
	out	" Available:              $storage_free"
	out	" Used:                   $storage_used"
	
	if [ -d "$mount_point/TeslaCam" ]; then
		storage_teslacam=$(du -hs "${mount_point}/TeslaCam" | cut -f 1)

		out	"   TeslaCam:             $storage_teslacam"
	fi
}

usb::enable() {
	attempt		" - Enabling mass storage device mode..." \
												"sudo modprobe g_mass_storage file=/piusb.bin stall=0 ro=0 removable=1"
}

usb::disable() {
	attempt		" - Disabling mass storage device mode..." \
												"sudo modprobe -r g_mass_storage"
}

usb::mount() {
	local volume_label && volume_label=$(arg::default "TESLA_PI" "$1")

	if ! mount | grep "/mnt/${volume_label}" > /dev/null; then
		attempt	" - Mounting volume (${volume_label})" \
												"sudo mkdir -p \"/mnt/${volume_label}\"" \
												"utils::setline \"/piusb.bin /mnt/${volume_label} vfat users,umask=000 0 2\" \"/etc/fstab\"" \
												"sudo mount -a"
	else
		out		" - Already mounted: ${volume_label}"
	fi
}

usb::unmount() {
	local volume_label && volume_label=$(arg::default "TESLA_PI" "$1")

	if mount | grep "/mnt/${volume_label}" > /dev/null; then
		attempt	" - Unmounting volume (${volume_label})" \
												"sudo umount \"/mnt/${volume_label}\"" \
												"utils::rmline \"\\/mnt\\/${volume_label}\" \"/etc/fstab\"" \
												"sudo rm -rf \"/mnt/${volume_label}\""
	else
		out		" - Not mounted: ${volume_label}"
	fi
}

usb::build() {
	local volume_size && volume_size=$(arg::default "65536" "$1")
	local volume_label && volume_label=$(arg::default "TESLA_PI" "$2")

	out	" - Building Volume"

	attempt		"   - Creating container (${volume_size} MB)..." \
												"sudo dd bs=1M if=/dev/zero of=/piusb.bin count=${volume_size}"
	attempt		"   - Formatting container..."	"sudo mkdosfs /piusb.bin -F 32 -I -n \"${volume_label}\""
	attempt		"   - Mounting volume (${volume_label})" \
												"usb::mount ${volume_label}"
	attempt		"   - Creating TeslaCam directory..." \
												"mkdir -p \"/mnt/${volume_label}/TeslaCam\""
	attempt		"   - Enabling mass storage device mode..." \
												"usb::enable"
}

usb::destroy() {
	local volume_label && volume_label=$(grep "\/piusb.bin" /etc/fstab | grep -Po '\/mnt\/\K[^\s]*')

	out	" - Destroying Volume"

	attempt		"   - Disabling mass storage device mode..." \
												"usb::disable"
	attempt		"   - Unmounting volume (${volume_label})" \
												"usb::unmount ${volume_label}"
	attempt		"   - Deleting container..."	"sudo rm /piusb.bin"
}

usb::repair() {
	local volume_label && volume_label=$(grep "\/piusb.bin" /etc/fstab | grep -Po '\/mnt\/\K[^\s]*')

	out " - Repairing Volume"

	attempt		"   - Disabling mass storage device mode..." \
												"usb::disable"
	attempt		"   - Repairing filesystem..."	"sudo fsck -fa /mnt/${volume_label}"
	attempt		"   - Enabling mass storage device mode..." \
												"usb::enable"
}

usb::ls() {
	out "ls..."
}

usb::sync() {
	out "sync..."
}

usb::index() {
	out "@H2 USB Mass Storage"

	if [[ $# -eq 0 ]]; then
		usb::status
	else
		local subcommand="$1"
		local type && type=$(type -t "usb::${subcommand}")

		shift 1			

		if [ -n "${type}" ] && [ "${type}" = "function" ]; then
			eval "usb::${subcommand}" "$@"
		else
			return 1
		fi
	fi
}
