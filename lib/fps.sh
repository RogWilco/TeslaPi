#!/usr/bin/env bash

fkill() {
	local pid_file="$1"

	if [ -e "${pid_file}" ]; then
		pid=$(cat "$pid_file")

		kill -9 "$pid" >> /dev/null && return 0 || return 1

		rm "${pid_file}" &>/dev/null && return 0 || return 1
	fi
}

fps() {
	local pid_file="$1"

	if [ -e "${pid_file}" ]; then
		pid=$(cat "$pid_file")

		if ps -p "${pid}" &>/dev/null; then
			return 0
		else
			rm "${pid_file}"
			return 1
		fi
	else
		return 1
	fi
}
