#!/usr/bin/env bash

out() {
	platform() {
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

	# Parse Arguments
	local echoVal="$1"

	[[ $# -gt 1 ]] && echoVal="$2" || echoVal="$1"

	local args=""
	local echoArgs=""
	local done=0
	local i=0

	local flag_i=0
	local flag_j=0
	local flag_n=0

	args=$(getopt ijnpr "$@")

	for i in $args
	do
		case "$i" in
			# Disable Auto-Indent
			'-i')
				flag_i=1
				shift;;

			# Right-Justify Text
			'-j')
				flag_j=1
				shift;;

			# Disable Trailing Newline
			'-n')
				flag_n=1
				echoArgs="${echoArgs}n"
				shift;;

			'--')
				shift; break;;
		esac
	done

	local platform="$(platform)"

	# Establish Entry Flag
	if [[ -z "$entryQueued" ]]; then entryQueued=0; fi;

	# Load Previous Output
	local lastFile="$HOME/.out.last"
	touch "$lastFile"
	local last
	last=$(cat "$lastFile")

	# Load Current Line
	local line
	local lineFile="$HOME/.out.line"

	touch "$lineFile"
	line=$(cat "$lineFile")

	# Templates
	local templatePad="\n\n"
	local templatePrefix=""
	local templatePadding=" "
	local templateIndent="$templatePrefix$templatePadding"
	local templateH1="$templatePrefix@gray(================================================================================)"
	local templateH2="$templatePrefix@gray(--------------------------------------------------------------------------------)"
	local templateDiv="$templateH2"
	local templateEnd="$templateH2"
	local templateSuccess="[  @green(OK)  ]"	# "@green(✓)", "@green(✔)"︎
	local templateFailure="[ @red(FAIL) ]"		# "@red(✗)", "@red(✘)"
	local templateSkip="[ @blue(SKIP) ]"		# "@blue(~)", "@blue(⋯)"

	local margin=80

	local formatted="$echoVal"
	local unformatted="$echoVal"

	if [[ flag_i -eq 1 ]]
		then
			templateIndent=""
	fi

	# Fix Newlines
	if [[ "$platform" == "linux" ]]; then
		formatted="${formatted//\\n/\\\\\n}"
	fi

	# Apply Indentation
	formatted="${formatted//\\\n/\n$templateIndent}"

	# Apply Markup Formatting
	case "$formatted" in
		@[Hh]1*)
			formatted="$templateH1\n$templateIndent@green(${formatted:4})\n$templateH1"

			# Handle Queued Entry
			if [[ "$entryQueued" == "1" ]]
				then
					formatted="$templatePad$formatted"
					entryQueued=0
			fi
			;;

		@[Hh]2*)
			if [[ $last =~ ^@[Hh][12]* ]]
				then
					formatted="$templateIndent@yellow(${formatted:4})\n$templateH2"
				else
					formatted="$templateH2\n$templateIndent@yellow(${formatted:4})\n$templateH2"
			fi

			# Handle Queued Entry
			if [[ "$entryQueued" == "1" ]]
				then
					formatted="$templatePad$formatted"
					entryQueued=0
			fi
			;;

		@[Dd][Ii][Vv]*)
			if [[ ${#formatted} -gt 4 ]]
				then
					formatted="$templateDiv\n${formatted:5}"
				else
					formatted="$templateDiv"
			fi
			;;

		@[Ss][Uu][Cc][Cc][Ee][Ss][Ss]*)
			formatted="$templateSuccess$templatePadding"
			;;

		@[Ff][Aa][Ii][Ll][Uu][Rr][Ee]*)
			formatted="$templateFailure$templatePadding"
			;;

		@[Ss][Kk][Ii][Pp]*)
			formatted="$templateSkip$templatePadding"
			;;

		@[Ee][Nn][Tt][Rr][Yy]*)
			entryQueued=1
			return 0
			;;

		@[Ee][Xx][Ii][Tt]*)
			# Handle Queued Entry
			if [[ "$entryQueued" == "1" ]]
				then
					entryQueued=0
					return 0
				else
					# Handle Exit w/ Heading
					if [[ $last =~ ^@[Hh][12]* ]]
						then
							# Handle Double Newline (After Heading)
							if [[ "${templatePad:0:2}" == "\n" ]]
								then
									templatePad="${templatePad:2}"
							fi

							formatted="$templatePad"
						else
							# Handle Exit w/ Text
							if [[ ${#formatted} -gt 5 ]]
								then
									formatted="$templateIndent${formatted:6}\n$templateEnd$templatePad"
								else
									formatted="$templateEnd$templatePad"
							fi
					fi

					entryQueued=0
			fi

			done=1
			;;

		*)
			if [[ $flag_j -eq 1 ]]
				then
					formatted="${formatted/\\@/@}$templatePadding"
				else
					formatted="$templateIndent${formatted/\\@/@}"

					# Handle Queued Entry
					if [[ "$entryQueued" == "1" ]]
						then
							formatted="$templatePad$templateDiv\n$formatted"
							entryQueued=0
					fi
			fi
			;;
	esac

	local stripped="$formatted"

	# Format Colors
	if [[ "$formatted" == *"@"* ]]
		then
			stripped=$(echo "$formatted" | sed -E -e "s/@[A-Za-z0-9_-]*\(([^\)]*)\)/\1/g")

			formatted=$(echo "$formatted" | sed -E -e "s/@[Nn][Oo][Nn][Ee]\(([^\)]*)\)/\\\033[0m\1\\\033[0m/g" \
				-e "s/@[Bb][Ll][Aa][Cc][Kk]\(([^\)]*)\)/\\\033[0;30m\1\\\033[0m/g" \
				-e "s/@[Ww][Hh][Ii][Tt][Ee]\(([^\)]*)\)/\\\033[1;37m\1\\\033[0m/g" \
				-e "s/@[Bb][Ll][Uu][Ee]\(([^\)]*)\)/\\\033[0;34m\1\\\033[0m/g" \
				-e "s/@[Bb][Ll][Uu][Ee]_[Ll][Tt]\(([^\)]*)\)/\\\033[1;34m\1\\\033[0m/g" \
				-e "s/@[Gg][Rr][Ee][Ee][Nn]\(([^\)]*)\)/\\\033[0;32m\1\\\033[0m/g" \
				-e "s/@[Gg][Rr][Ee][Ee][Nn]_[Ll][Tt]\(([^\)]*)\)/\\\033[1;32m\1\\\033[0m/g" \
				-e "s/@[Cc][Yy][Aa][Nn]\(([^\)]*)\)/\\\033[0;36m\1\\\033[0m/g" \
				-e "s/@[Cc][Yy][Aa][Nn]_[Ll][Tt]\(([^\)]*)\)/\\\033[1;36m\1\\\033[0m/g" \
				-e "s/@[Rr][Ee][Dd]\(([^\)]*)\)/\\\033[0;31m\1\\\033[0m/g" \
				-e "s/@[Rr][Ee][Dd]_[Ll][Tt]\(([^\)]*)\)/\\\033[1;31m\1\\\033[0m/g" \
				-e "s/@[Pp][Uu][Rr][Pp][Ll][Ee]\(([^\)]*)\)/\\\033[0;35m\1\\\033[0m/g" \
				-e "s/@[Pp][Uu][Rr][Pp][Ll][Ee]_[Ll][Tt]\(([^\)]*)\)/\\\033[1;35m\1\\\033[0m/g" \
				-e "s/@[Yy][Ee][Ll][Ll][Oo][Ww]\(([^\)]*)\)/\\\033[0;33m\1\\\033[0m/g" \
				-e "s/@[Yy][Ee][Ll][Ll][Oo][Ww]_[Ll][Tt]\(([^\)]*)\)/\\\033[1;33m\1\\\033[0m/g" \
				-e "s/@[Gg][Rr][Aa][Yy]\(([^\)]*)\)/\\\033[1;30m\1\\\033[0m/g" \
				-e "s/@[Gg][Rr][Aa][Yy]_[Ll][Tt]\(([^\)]*)\)/\\\033[0;37m\1\\\033[0m/g")
	fi

	if [[ $flag_j -eq 1 ]]
		then
			let "padding = ($margin - ${#line}) - ${#stripped} + 1"

			padding=$(printf "%${padding}s")
			formatted="$padding$formatted"
	fi

	# Output Formatted String
	echo -e${echoArgs} "$formatted"

	# Cache Unformatted Version
	echo "$unformatted" > "$lastFile"

	# Cache Current Line
	if [[ flag_n -eq 1 ]]
		then
			echo -n "$stripped" >> "$lineFile"
		else
			echo "" > "$lineFile"
	fi

	if [[ $done -eq 1 ]]
		then
		rm "$lastFile"
		rm "$lineFile"
	fi

	return 0
}

get() {
	# Setup
	local OPTIND

	local name
	local label
	local default
	local value

	local verbose=0
	local password=0
	local prompt

	# Get Variable Name
	if [ $# -gt 1 ]
		then
			name="$1"
			shift "$args"
		else
			return 1
	fi

	# Get Options
	while getopts ":d:l:vp" o; do
		case "${o}" in
			"d")
				default="${OPTARG}"
				;;

			"l")
				label="${OPTARG}"
				;;

			"v")
				verbose=1
				;;

			"p")
				password=1
				;;

			*)
				;;
		esac
	done
	shift $((OPTIND-1))

	# If prompt is not verbose, return if variable is already set.
	if [ $verbose -eq 0 ]
		then
			return 0
	fi

	# Set label to variable name if not set.
	if [ -z "$label" ]
		then
			label="$name"
	fi

	# Set default value to existing variable value if not set.
	if [ -z "$default" ]
		then
			if [ -n "${!name}" ]
				then
					default="${!name}"
			fi
	fi

	# Prompt
	if [ -z "$default" ]
		then
			prompt="$label: "
		else
			prompt="$label ($default): "
	fi

	out -p "$prompt"

	if [ $password -eq 0 ]
		then
			read -r value
		else
			read -rs value
			echo
	fi

	if [ -z "$value" ]
		then value="$default"
	fi

	eval "$name=\$value"

	return 0
}

charfill() {
	local err_bad_args=1
	local err_width=2
	local char
	local width
	local text
	local side="right"

	while getopts ":rl" opt; do
		case "${opt}" in
			r)
				side="right"
				shift
				;;

			l)
				side="left"
				shift
				;;
		esac
	done

	# Fail if not all arguments are provided.
	if [ $# -lt 2 ]; then
		return $err_bad_args
	fi

	# Defautl char is space if not specified.
	if [ $# -lt 3 ]; then
		char=" "
	else
		char="$1"
		shift
	fi

	width="$1"
	text="$2"

	# Fail if width is shorter than the specified string.
	if [ ${#text} -gt "$width" ]; then
		return $err_width
	fi

	local padding=$((width - ${#text}))
	local pad

	pad=$(printf "%${padding}s")

	if [ "$side" == "right" ]; then
		echo "$text${pad// /$char}"
	else
		echo "${pad// /$char}$text"
	fi
}
