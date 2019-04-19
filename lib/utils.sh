#!/usr/bin/env bash

attempt() {
	local failed=0
	local stdinFile
	local stderrFile
	local stdoutFile

	stdinFile=$(mktemp -t ".attempt.stdin.XXX")
	stderrFile=$(mktemp -t ".attempt.stderr.XXX")
	stdoutFile=$(mktemp -t ".attempt.stdout.XXX")

	[ -z "$DEBUG_MASK" ] && DEBUG_MASK="000"

	out -n "$1"
	shift

	if [[ $# -eq 1 ]]
		then
			echo "$1" > "$stdinFile"
			eval "$1" 1>>"$stdoutFile" 2>>"$stderrFile" || ((failed++))
		else
			for cmd in "$@"
			do
				echo "$cmd" > "$stdinFile"
				(eval "$cmd" 1>>"$stdoutFile" 2>>"$stderrFile" && out -in ".") || ((failed++))
			done
	fi

	([[ $failed -eq 0 ]] && out -j "@success") || out -j "@failure"

	if [[ -s "$stdinFile" && ( (! $failed -eq 0 && "${DEBUG_MASK:0:1}" == "1" ) || "${DEBUG_MASK:0:1}" == "2") ]]; then
		input=$(sed -E -e "s/^(.*)$/@gray( | )@white(\1)/" "$stdinFile")

		out -i "\n @white(STDIN:)\n$input\n"
	fi

	if [[ -s "$stdoutFile" && ( (! $failed -eq 0 && "${DEBUG_MASK:1:1}" == "1" ) || "${DEBUG_MASK:1:1}" == "2") ]]; then
		output=$(sed -E -e "s/^(.*)$/@gray( | \1)/" "$stdoutFile")

		out -i "\n @gray(STDOUT:)\n$output\n"
	fi

	if [[ -s "$stderrFile" && ( (! $failed -eq 0 && "${DEBUG_MASK:2:1}" == "1" ) || "${DEBUG_MASK:2:1}" == "2") ]]; then
		errors=$(sed -E -e "s/^(.*)$/@gray( | )@red(\1)/" "$stderrFile")

		out -i "\n @red(STDERR:)\n$errors\n"
	fi

	if [[ $failed -gt 0 ]]
		then
			return 1
		else
			return 0
	fi
}

skip() {
	out -n "$1"
	out -j "@skip"
}

utils::precond() {
	local text="$1"
	local precondition="$2"
	local pass=0

	shift
	shift

	eval "$precondition" &> /dev/null && pass=1

	if [[ pass -eq 1 ]]
		then
			attempt "$text" "$@"
		else
			skip "$text"
	fi
}

quit() {
	local exitCode=0;

	if [ $# -gt 0 ]; then
		exitCode=$1
	fi

	out "@EXIT"

	exit "$exitCode";
}

utils::linkup() {
	if [ $# -lt 2 ]
	then
		return 1
	fi

	local target="$1"
	local symlink="$2"
	local directory

	directory=$(dirname "$symlink")

	# If linking a directory, delete an existing directory at that location.
	rm -rf "$symlink"

	# Backfill nonexistent directories in symlink's path.
	mkdir -p "$directory"

	# Create new symlink.
	ln -Fs "$target" "$symlink"
}

utils::setconf() {
    local file="$1"
    local key && key=$(sed -e 's/[\/&]/\\&/g' <<< "$2")
    local value && value=$(sed -e 's/[\/&]/\\&/g' <<< "$3")

    sudo sed -i "/^$key=/s/=.*$/=$value/" "$file"
}

utils::setline() {
	local text="$1"
	local file="$2"

	sudo sh -c "grep -qxF \"$text\" \"$file\" || echo \"$text\" >> \"$file\""
}

utils::platform() {
	local platform="unknown"

	case "$(uname)" in
		'Darwin' | 'FreeBSD')
			platform="bsd"
			;;

		'Linux')
			platform="linux"
			;;
	esac

	echo "$platform"
}
