#!/usr/bin/env bash

#?/synopsis     web [command]
#?/summary      manages the TeslaPi web interface

#?/description
#? Provides control for TeslaPi's web interface, which can be accessed from the
#? in-vehicle browser.
#?
#?   status     Displays the current state of the web service.
#?   start      Starts the web service.
#?   stop       Stops the web service.

# Imports
source "${DIR}/lib/utils.sh"
source "${DIR}/lib/fps.sh"

ROOT_MODULE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

web::index() {
	out			"@H2 Web Interface"

	if [[ $# -eq 0 ]]; then
		web::status
	else
		local subcat="$1"
		local type && type=$(type -t "web::${subcat}")

		shift 1			

		if [ -n "${type}" ] && [ "${type}" = "function" ]; then
			eval "web::${subcat}" "$@"
		else
			attempt	" - NPM Task: ${subcat}..."			"cd ${ROOT_MODULE}" \
														"npm run ${subcat}"
		fi
	fi
}

web::start() {
	if fps "${ROOT_PID}/web.pid"; then
		attempt	" - Stopping service..."				"fkill \"${ROOT_PID}/web.pid\""
	fi

	attempt     " - Building"							"cd ${ROOT_MODULE}" \
														"npm install"

	attempt     " - Starting service..."                "npm run debug < /dev/null &> ${ROOT_LOG}/${service}.log & echo \$! > ${ROOT_PID}/${service}.pid"
}

web::stop() {
	if fps "${ROOT_PID}/web.pid"; then
		attempt	" - Stopping service..."				"fkill \"${ROOT_PID}/web.pid\""
	else
		SKIP	" - Stopping service..."
	fi
}

web::status() {
	out			"status..."
}
