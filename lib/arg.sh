#!/usr/bin/env bash

arg::default() {
	local arg_default="$1"
	local arg_value="$2"

	if [[ $# -eq 0 ]]; then
		return 1
	fi

	# Test all conditions under which we fall back & return the default:
	#	- value argument is missing
	#   - value argument is an empty string
	#   - value argument is whitespace
	if [[ $# -lt 2 || -z "$2" ]]; then
		echo "$arg_default"
	fi

	# Otherwise, output the value.
	echo "$arg_value"
}
