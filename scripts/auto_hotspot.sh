#!/bin/bash
#
# Title:     Auto AP (Access Point)
# Author:    Eric Davisson
#            hi@ericdavisson.com
# Project:   MudPi Setup
# Website:   https://mudpi.app
# Copyright: Copyright (c) 2020-2026 Eric Davisson <hi@ericdavisson.com>
# Description: Checks Wi-Fi connectivity via NetworkManager and automatically
#              starts the MudPi hotspot when no known network is available.
#              Designed for Raspberry Pi OS Bookworm+ (NetworkManager).
#

echo "-----------------------------"
echo "        MudPi Auto AP        "
date
echo "-----------------------------"

## Settings
#################################################
lockfile='/var/run/auto_hotspot.pid'
hotspot_name='mudpi-hotspot'
interface='wlan0'
apfile='/home/mudpi/tmp/ap_mode'
networkscanfile='/home/mudpi/tmp/nearbynetworklist.txt'
max_scan_attempts=10

colorinfo='\033[1;34m'
colorerror='\033[1;31m'
colorsuccess='\033[1;32m'
colorwarn='\033[1;33m'
colorclear='\033[0m'
###################################################

## Preflight
#################################################
if ! command -v nmcli &>/dev/null; then
	echo -e "${colorerror}Error: nmcli not found. NetworkManager is required.${colorclear}"
	exit 1
fi

if ! nmcli -t -f NAME connection show | grep -q "^${hotspot_name}$"; then
	echo -e "${colorerror}Error: Hotspot profile '${hotspot_name}' not found. Run the MudPi installer first.${colorclear}"
	exit 1
fi

## Lockfile
#################################################
if [ -f "$lockfile" ]; then
	PID=$(cat "$lockfile")
	if ps -p "$PID" >/dev/null 2>&1; then
		echo -e "${colorwarn}Duplicate process already running PID: ${PID}${colorclear}"
		exit 1
	fi
fi
echo $$ > "$lockfile" || {
	echo -e "${colorerror}Could not create lock file${colorclear}"
	exit 1
}
trap 'rm -f "$lockfile"' EXIT

## Functions
#####################################################################
function log_success() {
	echo -e "${colorsuccess}$*${colorclear}"
}

function log_info() {
	echo -e "${colorinfo}Notice: $*${colorclear}"
}

function log_error() {
	echo -e "${colorerror}Error: $*${colorclear}"
}

function log_warning() {
	echo -e "${colorwarn}Warning: $*${colorclear}"
}

function is_hotspot_active() {
	nmcli -t -f NAME connection show --active | grep -q "^${hotspot_name}$"
}

function is_wifi_connected() {
	nmcli -t -f TYPE,STATE connection show --active | grep -q "^802-11-wireless:activated"
}

function get_known_ssids() {
	nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | grep -v "^${hotspot_name}:" | cut -d: -f1
}

function scan_nearby_networks() {
	local attempt=0
	local scan_output=""

	until [ $attempt -ge $max_scan_attempts ]; do
		echo "Scanning for nearby networks (attempt $((attempt + 1)))..."
		scan_output=$(nmcli -t -f SSID device wifi list --rescan yes ifname "$interface" 2>&1)

		if echo "$scan_output" | grep -q "Error"; then
			attempt=$((attempt + 1))
			log_warning "Scan failed, retrying in 2s..."
			sleep 2
		else
			echo "Scan complete"
			break
		fi
	done

	if [ -d "$(dirname "$networkscanfile")" ]; then
		{
			echo "---Network Scan---"
			date
			echo "$scan_output"
			echo ""
		} >> "$networkscanfile"
		log_info "Scan results saved to $networkscanfile"
	fi

	local known_ssids
	known_ssids=$(get_known_ssids)

	if [ -z "$known_ssids" ]; then
		log_warning "No saved Wi-Fi networks configured"
		return 1
	fi

	while IFS= read -r ssid; do
		if echo "$scan_output" | grep -q "^${ssid}$"; then
			log_success "Known network '${ssid}' found nearby!"
			return 0
		fi
	done <<< "$known_ssids"

	log_warning "No known networks found nearby"
	return 1
}

function start_hotspot() {
	echo "Starting Access Point..."
	if is_hotspot_active; then
		log_success "AP Mode already active!"
		return 0
	fi

	nmcli connection up "$hotspot_name" 2>/dev/null || {
		log_error "Failed to start hotspot"
		return 1
	}
	log_success "Access Point started successfully"
	echo "ip_address=$(hostname -I)"
}

function stop_hotspot() {
	echo "Stopping Access Point..."
	if ! is_hotspot_active; then
		echo "AP Mode is not active"
		return 0
	fi

	nmcli connection down "$hotspot_name" 2>/dev/null || {
		log_error "Failed to stop hotspot"
		return 1
	}
	log_success "Access Point stopped"
}

function connect_wifi() {
	echo "Attempting Wi-Fi connection..."
	local known_ssids
	known_ssids=$(get_known_ssids)

	while IFS= read -r ssid; do
		log_info "Trying to connect to '${ssid}'..."
		if nmcli connection up "$ssid" ifname "$interface" 2>/dev/null; then
			log_success "Connected to '${ssid}'"
			return 0
		fi
	done <<< "$known_ssids"

	log_error "Failed to connect to any known network"
	return 1
}

function verify_wifi_connection() {
	local max_attempts=3
	local attempt=0

	echo "Verifying Wi-Fi connection..."
	while [ $attempt -lt $max_attempts ]; do
		sleep 10
		if is_wifi_connected; then
			local ip
			ip=$(hostname -I | awk '{print $1}')
			log_success "Network connected successfully (IP: ${ip})"
			return 0
		fi

		attempt=$((attempt + 1))
		log_warning "Wi-Fi not connected, attempt ${attempt}/${max_attempts}"

		if [ $attempt -lt $max_attempts ]; then
			log_info "Restarting NetworkManager and retrying..."
			systemctl restart NetworkManager 2>/dev/null
			sleep 5
			connect_wifi 2>/dev/null
		fi
	done

	log_error "Wi-Fi connection failed after ${max_attempts} attempts"
	return 1
}

## Main
############################################################
if [[ -f "$apfile" ]]; then
	log_info "Detected AP Mode override file: $apfile"
	start_hotspot || log_error "Problem starting AP Mode!"
	rm -f "$apfile"
elif is_wifi_connected && ! is_hotspot_active; then
	log_success "Wi-Fi is already connected"
elif is_hotspot_active; then
	log_info "AP Mode is active, checking for known networks..."
	if scan_nearby_networks; then
		log_info "Known network found, switching from AP to Wi-Fi..."
		stop_hotspot
		sleep 2
		if ! connect_wifi; then
			log_warning "Wi-Fi connection failed, restarting AP Mode"
			start_hotspot
		else
			verify_wifi_connection || {
				log_warning "Wi-Fi verification failed, reverting to AP Mode"
				start_hotspot
			}
		fi
	else
		log_info "No known networks nearby, keeping AP Mode active"
	fi
else
	log_info "No active connection, scanning for networks..."
	if scan_nearby_networks; then
		if connect_wifi; then
			verify_wifi_connection || {
				log_warning "Wi-Fi verification failed, falling back to AP Mode"
				start_hotspot
			}
		else
			log_warning "Could not connect to any known network, starting AP Mode"
			start_hotspot
		fi
	else
		log_info "No known networks found, starting AP Mode"
		start_hotspot
	fi
fi

echo "-----------------------------"
exit 0
