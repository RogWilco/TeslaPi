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

	attempt     " - Starting service..."                "npm run debug < /dev/null &> ${ROOT_LOG}/web.log & echo \$! > ${ROOT_PID}/web.pid"
}

web::stop() {
	if fps "${ROOT_PID}/web.pid"; then
		attempt	" - Stopping service..."				"fkill \"${ROOT_PID}/web.pid\""
	else
		SKIP	" - Stopping service..."
	fi
}

web::status() {
	local status;
	local protocol;
	local host;
	local ip_lan;
	local ip_wan;
	local port;
	local url;

	cd "$ROOT_MODULE" || return 1

	protocol=$(node -e "console.log(require('./config').web.protocol)")
	host=$(node -e "console.log(require('./config').web.host)")
	ip_lan=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | head -n 1)
	ip_wan=$(dig @resolver1.opendns.com ANY myip.opendns.com +short)
	port=$(node -e "console.log(require('./config').web.port)")
	url="${protocol}://${host}"

	if fps "${ROOT_PID}/web.pid"; then
		status="[ @GREEN(UP) ]"
	else
		status="[ @RED(DOWN) ]"
	fi

	out		" - Service Status:         ${status}"
	out 	" - Host:                   ${host}"
	out		" - IP Address (LAN):       ${ip_lan}"
	out		" - IP Address (WAN):       ${ip_wan}"
	out		" - Port:                   ${port}"
	out		" - URL:                    ${url}"
}
