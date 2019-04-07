#!/usr/bin/env bash

# Set Hostname: TeslaPi

# Enable SSH
sudo touch /boot/ssh

# Enable Headless Wireless Networking
# copy wpa_supplicant.conf to /boot/wpa_supplicant.conf

# Install haveget (entropy generator that doesn't require a mouse)
# for VNC Server to start when headless.
sudo apt install -y haveged

sudo apt update
sudo apt install -y realvnc-vnc-server

# Enable VNC Server via `sudo raspi-config` => Interfacing Options > VNC > Yes

# Downgrade VNC Server's authentication scheme
# /root/.vnc/config.d/vncserver-x11
# 	- Replace Authentication=SystemAuth with
#		Authentication=VncAuth
#	- run `sudo vncpasswd -service`
#		- set password
#	- Restart VNC Server