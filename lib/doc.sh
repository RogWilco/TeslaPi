#!/usr/bin/env bash

doc() {
	local file="$1"
	local tag=""
	local result=""

	if [[ $# -gt 1 ]]; then
		tag=$(printf "%s" "$2" | sed -E -e 's/[\/&]/\\&/g')
	else
		tag="description"
	fi

	result=$(
		# Grab the file contents & extract target comment block.
		sed -n -E -e "/\#\?\/${tag}\h*/,/^(\#\?\/.*){0,1}$/p" "$file" |

		# Delete last line (since the above is inclusive on the end pattern).
		sed '$d' |

		# Remove the starting line if it only contains the tag.
		sed -E -e "/\#\?\/${tag}\w*$/d" |

		# Remove the tag syntax from the starting line if followed by text.
		sed -E -e "s/\#\?(\/${tag}[	 ]*|[ ])//" |

		# Remove the comment syntax if it is a continuation comment.
		sed -E -e "s/\#\?//" |

		# Remove leading space padding.
		sed 's/^[[:space:]]//'
	)

	if [[ ! -z "$result" ]]; then
		echo "${result//
/\\n}"
		return 0
	fi

	return 1
}
