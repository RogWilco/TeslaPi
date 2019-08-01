#!/usr/bin/env bash

#?/index        1
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

# Imports
source "${DIR}/lib/utils.sh"
source "${DIR}/lib/file.sh"

sudo -v

# ============================================================================
# Setup
# ============================================================================
config_hostname="TeslaPi"
config_timezone="America/Los_Angeles"
config_volname="TESLA_PI"
config_volsize=65536

DIR_BIN="${DIR}/bin"

user=$(id -un)
# shellcheck disable=SC2116
home=$(echo ~)
files="$DIR/files"

apt::repository::add() {
	for i in "$@"; do
		if grep -h "^deb.*$i" /etc/apt/sources.list.d/* > /dev/null 2>&1; then
			echo "Repository Exists: $i"
		else
			echo "Adding Repository: $i"
			sudo apt-add-repository -y "$i"
		fi
	done
}

# ============================================================================
# Packages
# ============================================================================
install::packages() {
	out				" - Installing Packages:"

    # Apt Update
	attempt			"   - Update..."		"sudo apt update -y"
	attempt			"   - Upgrade..."		"sudo apt upgrade -y"

    # Install Packages
    local packages=(
        direnv                      # Direnv
        haveged                     # Entropy Generator (for headless VNC)
        jq                          # Command-line JSON Processor
        zsh                         # Zshell
    )

	for i in "${packages[@]}"; do
		attempt		"   - ${i}..."			"sudo apt install -y $i"
	done
}

# ============================================================================
# Docker
# ============================================================================
install::docker() {
	local docker_install && docker_install=$(mktemp /tmp/docker-install.XXXXXX)

	out				" - Installing Docker:"

	attempt			"   - docker"			"curl -fsSL https://get.docker.com > \"$docker_install\"" \
											"sudo sh \"$docker_install\"" \
											"rm \"$docker_install\"" \
											"sudo apt update -y" \
											"sudo apt install -y --allow-downgrade docker-ce=18.06.1~ce~3-0~raspbian"

	attempt			"   - docker-compose"	"sudo apt install -y docker-compose"
	attempt			"   - create \"docker\" group" \
											"sudo groupadd docker" \
											"sudo usermod -aG docker \"$USER\""
}

# ============================================================================
# System Customization
# ============================================================================
install::system() {
	out				" - Customizing System:"

	attempt			"   - Set timezone..."	"sudo raspi-config nonint do_change_timezone \"${config_timezone}\""
	attempt			"   - Set hostname..."	"sudo raspi-config nonint do_hostname \"${config_hostname}\""
	attempt			"   - Enable SSH..."	"sudo raspi-config nonint do_ssh 0"

	attempt			"   - Set ZSH as default shell" \
											"sudo chsh -s \"$(command -v zsh)\"" \
											"sudo chsh -s \"$(command -v zsh)\" \"$user\""
}

# ============================================================================
# System Customization: Enable USB Mass Storage
# ============================================================================
install::usb() {
	local usb_label="$1"

	out				" - Enabling USB Mass Storage:"

	if [[ -z "${usb_label// }" ]]; then
		echo "Please specify a USB label"
		return 1;
	fi

	attempt			"   - Enabling USB driver" \
											"sudo raspi-config nonint set_config_var dtoverlay dwc2 /boot/config.txt" \
											"utils::setline \"dwc2\" \"/etc/modules\""
	attempt			"   - Creating container (${config_volsize} MB)..." \
											"sudo dd bs=1M if=/dev/zero of=/piusb.bin count=${config_volsize}"
	attempt			"   - Formatting container..." \
											"sudo mkdosfs /piusb.bin -F 32 -I -n \"${usb_label}\""
	attempt			"   - Creating mount point..." \
											"sudo mkdir \"/mnt/${usb_label}\""
	attempt			"   - Mounting"			"utils::setline \"/piusb.bin /mnt/${usb_label} vfat users,umask=000 0 2\" \"/etc/fstab\"" \
											"sudo mount -a"
	attempt			"   - Creating TeslaCam directory..." \
											"mkdir -p \"/mnt/${usb_label}/TeslaCam\""
	attempt			"   - Enabling mass storage device mode..." \
											"sudo modprobe g_mass_storage file=/piusb.bin stall=0 ro=0 removable=1"
}

# ============================================================================
# System Customization: Enable Samba & Share Path
# ============================================================================
install::samba() {
	local share_path="$1"

	out				" - Enabling Samba:"

	attempt			"   - Installing..."		"sudo apt install -y samba winbind"

	if [[ -n "${share_path// }" ]]; then
		cat <<-CONFIG > sudo tee /etc/samba/usb.conf
			[usb]
			browseable = yes
			path = $share_path
			guest ok = yes
			read only = no
			create mask = 777
		CONFIG

		attempt		"   - Adding USB mount share..." \
												"utils::setline \"include = /etc/samba/usb.conf\" \"/etc/samba/smb.conf\""
	else
		skip		"   - Adding USB mount share..."
	fi

	attempt			"   - Restarting smbd.service..." \
												"sudo systemctl restart smbd.service"
}

# ============================================================================
# System Customization: Watchdog and USB Share Script
# ============================================================================
install::watchdog() {
	out				" - Installing Watchdog:"

	attempt			"   - Installing..."		"sudo pip3 install watchdog"
	attempt			"   - Adding USB script..."	"sudo cp \"$files/usr/local/share/usb_share.py\" \"/usr/local/share/usb_share.py\""

	cat <<-CONFIG > sudo tee /etc/systemd/system/usbshare.service
			[Unit]
			Description=USB Share Watchdog

			[Service]
			Type=simple
			ExecStart=/usr/local/share/usb_share.py
			Restart=always

			[Install]
			WantedBy=multi-user.target
		CONFIG

	attempt			"   - Enable usbshare.service" \
												"sudo systemctl daemon-reload" \
												"sudo systemctl enable usbshare.service" \
												"sudo systemctl start usbshare.service"
}

# ============================================================================
# VNC Server
# ============================================================================
install::vnc() {
	out				" - Enable VNC Server"
	attempt			"   - Enabling..."		"sudo raspi-config nonint do_vnc 0"

    # Downgrade VNC Server's auth scheme, set password, and restart service.
	attempt			"   - Configuring..."	"utils::setconf /root/.vnc/config.d/vncserver-x11 Authentication VncAuth" \
											"sudo vncpasswd -service" \
											"sudo systemctl restart vncserver-x11-serviced.service"
}

# ============================================================================
# User Customization
# ============================================================================
install::user() {
	local pw='raspberry'

	out				" - User Customization"
	get pw -l		"     - Password" -pv
	attempt			"     - Applying password..." \
											"echo \"$pw\" | passwd --stdin pi"

	attempt			"   - Adding dotfiles..." \
											"cp -R \"$files/user/.\" \"$home/\""
	attempt			"   - Creating empty .authn config..." \
											"touch \"$home/.authn\""

	if [ ! -d "$home/.oh-my-zsh" ]; then
		attempt		"   - OhMyZsh"			"env git clone --depth=1 https://github.com/robbyrussell/oh-my-zsh.git \"$home/.oh-my-zsh\"" \
											"cp \"$files/customization/ubertheme.zsh-theme\" \"$home/.oh-my-zsh/themes/\""\
	else
		skip		"   - OhMyZsh"
	fi

	attempt			"   - Setting wallpaper" \
											"sudo cp \"$files/usr/share/rpd-wallpaper/tesla_model_3.jpg\" \"/usr/share/rpd-wallpaper/tesla_model_3.jpg\"" \
											"utils::setconf \"$home/.config/pcmanfm/LXDE-pi/desktop-items-0.conf\" wallpaper \"/usr/share/rpd-wallpaper/tesla_model_3.jpg\""
}

# ============================================================================
# Add TeslaPi/bin/teslapi to $PATH
# ============================================================================
install::path() {
	local target="${1}"

	if [[ ":$PATH:" == *":${DIR_BIN}:"* ]]; then
		out -n " - TeslaPi/bin is already in your \$PATH."
			out -j "@SKIP"
	else
		if [ -z "$target" ]; then
		target="${HOME}/.bashrc"
		fi

		attempt     " - Adding TeslaPi/bin to your PATH: @GRAY(${target})" \
											"file::append_once \"${target}\" \"export PATH=\\\"${DIR_BIN}:\\\$PATH\\\"\""
	fi
}

# ============================================================================
# Reload Affected Services
# ============================================================================
install::reload() {
	attempt			" - Reloading affected services..." \
											"source $home/.bash_profile"
}

# ============================================================================
# Execute Tasks
# ============================================================================
install::index() {
	out "@H2 Install"

	if [[ $# -eq 0 ]]; then
		install::packages
		install::docker
		install::system
		install::usb "$config_volname"
		install::samba "/mnt/$config_volname"
		install::watchdog
		install::vnc
		install::user
		install::reload
	else
		local subcat="$1"
		local type && type=$(type -t "install::${subcat}")

		shift 1

		if [ -n "${type}" ] && [ "${type}" = "function" ]; then
			eval "install::${subcat}" "$@"
		else
			return 1
		fi
	fi
}
