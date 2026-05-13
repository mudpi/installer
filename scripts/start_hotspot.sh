#!/bin/bash
#
# Start the MudPi Wi-Fi hotspot (Access Point)
# Uses NetworkManager (nmcli) on Raspberry Pi OS Bookworm+
#

connection_name="mudpi-hotspot"

echo "Starting Access Point..."

if ! command -v nmcli &>/dev/null; then
	echo "Error: nmcli not found. NetworkManager is required."
	exit 1
fi

if ! nmcli -t -f NAME connection show | grep -q "^${connection_name}$"; then
	echo "Error: Hotspot profile '${connection_name}' not found."
	echo "Run the MudPi installer to create it, or create manually with:"
	echo "  sudo nmcli connection add type wifi ifname wlan0 con-name ${connection_name} \\"
	echo "    autoconnect no ssid MudPi wifi.mode ap wifi.band bg wifi.channel 7 \\"
	echo "    ipv4.addresses 192.168.4.1/24 ipv4.method shared \\"
	echo "    wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"your-password\""
	exit 1
fi

if nmcli -t -f NAME connection show --active | grep -q "^${connection_name}$"; then
	echo "Access Point is already running"
else
	nmcli connection up "$connection_name" || {
		echo "Error: Failed to start hotspot"
		exit 1
	}
	echo "Access Point started successfully"
fi

ip_address=$(nmcli -t -f IP4.ADDRESS connection show "$connection_name" 2>/dev/null | head -1 | cut -d: -f2)
echo "ip_address=${ip_address:-192.168.4.1}"
