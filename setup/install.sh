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
config_volname="TESLA_PI"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

user=$(id -un)
home=$(realpath ~)
files="$DIR/files"

utils::linkup() {
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

utils::setconf() {
    local file="$1"
    local key=$(sed -e 's/[\/&]/\\&/g' <<< "$2")
    local value=$(sed -e 's/[\/&]/\\&/g' <<< "$3")

    sudo sed -i "/^$key=/s/=.*$/=$value/" $file
}

utils::setline() {
	local text="$1"
	local file="$2"

	sudo sh -c "grep -qxF \"$text\" \"$file\" || echo \"$text\" >> \"$file\""
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
    utils::setconf /root/.vnc/config.d/vncserver-x11 Authentication VncAuth
    sudo vncpasswd -service
    sudo systemctl restart vncserver-x11-serviced.service

    sudo chsh -s "$(which zsh)"                    # Default system shell
	sudo chsh -s "$(which zsh)" "$user"            # Default user shell

	# Enable USB
	install::system::usb "$config_volname"

	# Enable Samba
	install::system::samba "/mnt/$config_volname"

	# Install Watchdog
	install::system::watchdog
}

# ============================================================================
# System Customization: Enable USB Mass Storage
# ============================================================================
install::system::usb() {
	local usb_label="$1"

	if [[ -z "${usb_label// }" ]]; then
		echo "Please specify a USB label"
		return 1;
	fi

	# Enable USB Driver
	sudo raspi-config nonint set_config_var dtoverlay dwc2 /boot/config.txt
	utils::setline "dwc2" "/etc/modules"

	# Create binary container file.
	sudo dd bs=1M if=/dev/zero of=/piusb.bin count=65536

	# Format container file to FAT32
	sudo mkdosfs /piusb.bin -F 32 -I -n "$usb_label"

	# Mount container file.
	sudo mkdir "/mnt/$usb_label"

	# Add to fstab
	utils::setline "/piusb.bin /mnt/$usb_label vfat users,umask=000 0 2" "/etc/fstab"
	sudo mount -a

	# Create TeslaCam directory
	mkdir -p "/mnt/$usb_label/TeslaCam"

	# Enable mass storage device mode
	sudo modprobe g_mass_storage file=/piusb.bin stall=0 ro=0 removable=1
}

# ============================================================================
# System Customization: Enable Samba & Share Path
# ============================================================================
install::system::samba() {
	local share_path="$1"

	sudo apt update
	sudo apt install -y samba winbind

	if [[ ! -z "${share_path// }" ]]; then
		sudo sh -c "echo \"[usb]
browseable = yes
path = $share_path
guest ok = yes
read only = no
create mask = 777\" >> \"/etc/smb/usb.conf\""

		utils::setline "include = /etc/smb/usb.conf"
	fi

	sudo systemctl restart smbd.service
}

# ============================================================================
# System Customization: Watchdog and USB Share Script
# ============================================================================
install::system::watchdog() {
	sudo pip3 install watchdog
	sudo cp "$files/usr/local/share/usb_share.py" "/usr/local/share/usb_share.py"

	sudo sh -c "echo \"[Unit]
Description=USB Share Watchdog

[Service]
Type=simple
ExecStart=/usr/local/share/usb_share.py
Restart=always

[Install]
WantedBy=multi-user.target\" >> \"/etc/systemd/system/usbshare.service\""

	sudo systemctl daemon-reload
	sudo systemctl enable usbshare.service
	sudo systemctl start usbshare.service
}

# ============================================================================
# User Customization
# ============================================================================
install::user() {
    # Copy Dotfiles
    cp -R "$files/user/." "$home/"

    # Set Wallpaper
    sudo cp "$files/usr/share/rpd-wallpaper/tesla_model_3.jpg" "/usr/share/rpd-wallpaper/tesla_model_3.jpg"
    utils::setconf "$home/.config/pcmanfm/LXDE-pi/desktop-items-0.conf" wallpaper "/usr/share/rpd-wallpaper/tesla_model_3.jpg"

    # Create empty auth file.
    touch "$home/.authn"
}

# ============================================================================
# Docker
# ============================================================================
install::docker() {
    local docker_install=$(mktemp /tmp/docker-install.XXXXXX)

    curl -fsSL https://get.docker.com > "$docker_install"
    
    sudo sh "$docker_install"

    rm "$docker_install"

	sudo apt update -y
	sudo apt install -y --allow-downgrade \
        docker-ce=18.06.1~ce~3-0~raspbian \
        docker-compose

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