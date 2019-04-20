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
#?   build          Builds a new virtual device, replacing a preexisting one.
#?   destroy        Removes any preexisting virtual drives.
#?   mount          Mounts an existing container.
#?   unmount        Unmounts a mounted container.
#?   repair         Repairs a mounted container that wasn't ejected properly.
#?   ls             Lists the contents of the container's filesystem.
#?   sync           Synchronizes the container's contents with the cloud.

usb::status() {
	out "status..."
}

usb::build() {
	out "build..."
}

usb::destroy() {
	out "destroy..."
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
	out "index..."
}
