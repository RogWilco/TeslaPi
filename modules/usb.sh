#!/usr/bin/env bash

#?/index        2
#?/synopsis     usb [subcommand]
#?/summary      manages the virtual USB mass storage functionality

#?/description`
#? Manages the virtual USB mass storage mode, allowing for control over
#? creation, state, etc.
#?
#? Available subcommands are:
#?
#?   status         Displays status information for the virtual device.
#?   build          Builds a new volume, replacing a preexisting one.
#?   destroy        Removes any preexisting volumes.
#?   mount          Mounts an existing container.
#?   unmount        Unmounts a mounted container.
#?   repair         Repairs a mounted volume that wasn't ejected properly.
#?   ls             Lists the contents of the volume's filesystem.
#?   sync           Synchronizes the volume's contents with the cloud.

source "${DIR}/lib/utils.sh"
source "${DIR}/lib/arg.sh"

usb::status() {
	out "status..."
}

usb::build() {
	local volume_size && volume_size=$(arg::default "65536" "$1")
	local volume_label && volume_label=$(arg::default "TESLA_PI" "$2")

	out	" - Building Volume"

	attempt		"   - Creating container (${volume_size} MB)..." \
												"sudo dd bs=1M if=/dev/zero of=/piusb.bin count=${volume_size}"
	attempt		"   - Formatting container..."	"sudo mkdosfs /piusb.bin -F 32 -I -n \"${volume_label}\""
	attempt		"   - Creating mount point..."	"sudo mkdir \"/mnt/${volume_label}\""
	attempt		"   - Mounting volume (${volume_label})" \
												"utils::setline \"/piusb.bin /mnt/${volume_label} vfat users,umask=000 0 2\" \"/etc/fstab\"" \
												"sudo mount -a"
	attempt		"   - Creating TeslaCam directory..." \
												"mkdir -p \"/mnt/${volume_label}/TeslaCam\""
	attempt		"   - Enabling mass storage device mode..." \
												"sudo modprobe g_mass_storage file=/piusb.bin stall=0 ro=0 removable=1"
}

usb::destroy() {
	local volume_label && volume_label=$(grep "\/piusb.bin" /etc/fstab | grep -Po '\/mnt\/\K[^\s]*')

	out	" - Destroying Volume"

	attempt		"   - Disabling mass storage device mode..." \
												"sudo modprobe -r g_mass_storage"
	attempt		"   - Unmounting volume (${volume_label})" \
												"sudo umount \"/mnt/${volume_label}\"" \
												"utils::rmline \"\\/mnt\\/${volume_label}\" \"/etc/fstab\"" \
												"sudo rm -rf \"/mnt/${volume_label}\""
	attempt		"   - Deleting container..."	"sudo rm /piusb.bin"
}

usb::mount() {
	out "mount..."
}

usb::unmount() {
	out "unmount..."
}

usb::repair() {
	out "repair..."
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
