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
#?   dev        Starts the web service in dev mode.

web::index() {
	out			"@H2 Web Interface"

	if [[ $# -eq 0 ]]; then
		web::status
	else
		for arg in "$@"; do
			type=$(type -t "web::${arg}")

			if [ -n "${type}" ] && [ "${type}" = "function" ]; then
				eval "web::${arg}"
			fi
		done
	fi
}

web::start() {
	out			"start..."
}

web::stop() {
	out			"stop..."
}

web::dev() {
	out			"dev..."
}

web::status() {
	out			"status..."
}