#!/usr/bin/env bash

#?/index        0
#?/synopsis     help [subcommand]
#?/summary      displays this command summary

source "${DIR}/lib/doc.sh"

help::index() {
	if [[ "$#" -gt 0 && "$1" != "help" ]]; then
		if [[ -f "$DIR_MODULES/$1.sh" ]]; then
			help::single "${DIR_MODULES}/$1.sh"
		elif [[ -f "$DIR_MODULES/$1/index.sh" ]]; then
			help::single "${DIR_MODULES}/$1/index.sh"
		else
			help::all
		fi
	else
		help::all
	fi
}

help::all() {
	out "@H2 Synopsis"

	out "teslapi [command [args...]]"
	out "teslapi help [command]"

	out "@H2 Command Reference"

	# Sort subcommand listing by index tags.
	declare -a subsWithIndex
	declare -a subsWithoutIndex

	for sub in "${DIR_MODULES}/"*; do        
        if [[ -d "$sub" ]]; then
            sub="${sub}/index.sh"
        fi

		index=$(doc "$sub" index)

		if [ "$index" != "" ]; then
			subsWithIndex[index]="$sub"
		else
			subsWithoutIndex+=("$sub")
		fi
	done

	subcommands=("${subsWithIndex[@]}")
	subcommands+=("${subsWithoutIndex[@]}")

	# Output subcommand summaries
	for sub in "${subcommands[@]}"; do
        subcommand=${sub/\/index\.sh/}
        subcommand=${subcommand%.*}
		subcommand=$(basename "$subcommand")
		subcommand=$(charfill 10 "$subcommand")
		summary=$(doc "$sub" summary)

		out "@BLUE(${subcommand})${summary}"
	done
}

help::single() {
	sub="$1"
	subcommand=$(basename "$sub")
	synopsis=$(doc "$sub" synopsis)
	description=$(doc "$sub" description)

	out "@H2 Synopsis"
	out "$synopsis"

	out "@H2 Descrption"
	out "$description"
}
