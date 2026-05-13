#!/bin/bash
#
# Stop the MudPi Wi-Fi hotspot (Access Point)
# Uses NetworkManager (nmcli) on Raspberry Pi OS Bookworm+
#

connection_name="mudpi-hotspot"

echo "Shutting down Access Point..."

if ! command -v nmcli &>/dev/null; then
	echo "Error: nmcli not found. NetworkManager is required."
	exit 1
fi

if nmcli -t -f NAME connection show --active | grep -q "^${connection_name}$"; then
	nmcli connection down "$connection_name" || {
		echo "Error: Failed to stop hotspot"
		exit 1
	}
	echo "Access Point stopped successfully"
else
	echo "Access Point is not currently active"
fi
