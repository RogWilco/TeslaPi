#!/usr/bin/env bash

#?/synopsis     install [subcategory]
#?/summary      executes post-install tasks for a fresh Raspbian system

#?/description
#? Executes all post-install steps by default, unless one or more categories
#? are specified. Available categories are:
#?
#?   packages       Installs all non-default packages, adding additional
#?                  PPA sources as necessary.
#?   system         Performs all system customization tasks.
#?   user           Performs all user customization tasks.
#?   docker         Installs Docker and Docker Compose.
#?   reload         Reloads all services and resources affected by this
#?                  post-install script.

sudo -v

# ============================================================================
# Setup
# ============================================================================
config_hostname="TeslaPi"
config_timezone="America/Los_Angeles"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

user=$(id -un)
home=$(realpath ~)
files="$DIR/files"

linkup() {
	if [ $# -lt 2 ]
	then
		return 1
	fi

	local target="$1"
	local symlink="$2"
	local directory=''

	directory=$(dirname "$symlink")

	# If linking a directory, delete an existing directory at that location.
	rm -rf "$symlink"

	# Backfill nonexistent directories in symlink's path.
	mkdir -p "$directory"

	# Create new symlink.
	ln -Fs "$target" "$symlink"
}

apt::repository::add() {
	for i in "$@"; do
		grep -h "^deb.*$i" /etc/apt/sources.list.d/* > /dev/null 2>&1

		if [ "$?" -ne 0 ]; then
			echo "Adding Repository: $i"
			sudo apt-add-repository -y "$i"
		else
			echo "Repository Exists: $i"
		fi
	done
}

# ============================================================================
# Packages
# ============================================================================
install::packages() {
    # Apt Update
	sudo apt update -y
	sudo apt upgrade -y

    # Install Packages
    local packages=(
        direnv                      # Direnv
        haveged                     # Entropy Generator (for headless VNC)
        jq                          # Command-line JSON Processor
        zsh                         # Zshell
    )

    sudo apt install -y "${packages[@]}"

    # Install OhMyZsh
	if [ ! -d "$home/.oh-my-zsh" ]; then env git clone --depth=1 https://github.com/robbyrussell/oh-my-zsh.git "$home/.oh-my-zsh"; cp "$files/customization/ubertheme.zsh-theme" "$home/.oh-my-zsh/themes/"; fi

    # Install Docker
    install::docker
}

# ============================================================================
# System Customization
# ============================================================================
install::system() {
    sudo raspi-config nonint do_change_timezone "${config_timezone}"
    sudo raspi-config nonint do_hostname "${config_hostname}"      # Set hostname
    sudo raspi-config nonint do_ssh 0                       # Enable SSH
    sudo raspi-config nonint do_vnc 0                       # Enable VNC Server

    # Downgrade VNC Server's auth scheme, set password, and restart service.
    sudo sed -i '/^Authentication/s/=.*$/=VncAuth/' /root/.vnc/config.d/vncserver-x11
    sudo vncpasswd -service
    sudo systemctl restart vncserver-x11-serviced.service

    sudo chsh -s "$(which zsh)"                    # Default system shell
	sudo chsh -s "$(which zsh)" "$user"            # Default user shell
}

# ============================================================================
# User Customization
# ============================================================================
install::user() {
    cp -R "$files/user/." "$home/"

    touch "$home/.authn"
}

# ============================================================================
# Docker
# ============================================================================
install::docker() {
    sudo bash <(curl -fsSL https://get.docker.com -o get-docker.sh)

	sudo apt update -y
	sudo apt install -y docker-compose

    sudo groupadd docker
	sudo usermod -aG docker "$USER"
}

# ============================================================================
# Reload Affected Services
# ============================================================================
install::reload() {
	source ~/.bash_profile
}

# ============================================================================
# Execute Tasks
# ============================================================================
if [[ $# -eq 0 ]]; then
	install::packages
	install::system
	install::user
	install::reload
else
	for arg in "$@"; do
		type=$(type -t "install::${arg}")

		if [ -n "${type}" ] && [ "${type}" = "function" ]; then
			eval "install::${arg}"
		fi
	done
fi