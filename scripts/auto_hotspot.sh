#!/bin/bash
#
# Title:     Auto AP (Acess Point)
# Author:    Eric Davisson
#            hi@ericdavisson.com
# Project:   MudPi Setup
# Website:  https://Mudpi.app
# Copyright: Copyright (c) 2020 Eric Davisson <hi@ericdavisson.com>
# Description: A script to check wifi connection and auto start an access point in the event of no wifi or failed connections.
#
echo "-----------------------------"
echo "        MudPi Auto AP        "
date
echo "-----------------------------"


## Settings
#################################################
lockfile='/var/run/auto_hotspot.pid'
wpaConfig='/etc/wpa_supplicant/wpa_supplicant.conf'
# Parse wpa_supplicant.conf and return csv list of network ssids
wpassid=$(awk '/ssid="/{ print $0 }' $wpaConfig | awk -F'ssid=' '{ print $2 }' ORS=',' | sed 's/\"/''/g' | sed 's/,$//')
interface='wlan0'
staticip='192.168.2.1'
currentssid=$(iwgetid $interface)
ssids=($wpassid)
networkscanfile='/etc/mudpi/tmp/nearbynetworklist.txt'
apfile='/etc/mudpi/tmp/ap_mode'
#ssids=('mySSID1' 'mySSID2' 'mySSID3') # Uncomment to override with specific network ssids
macaddrs=() # Add Hidden Network Mac Addresses Here
networks=("${ssids[@]}" "${macaddrs[@]}")
# Colors for pretty logs
colorinfo='\033[1;34m'
colorerror='\033[1;31m'
colorsuccess='\033[1;32m'
colorwarn='\033[1;33m'
colorclear='\033[0m'
###################################################

## LOCKFILE CHECK
###################################################
# Check for a lock file to see if process already running
if [ -f $lockfile ]
then
	# Get the process id from lock file to check for process status
	PID=$(cat $lockfile)
	ps -p $PID >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		echo -e "${colorwarn}Duplicate process already running PID: $PID${colorclear}"
		exit 1
	else
		## Process not found assume not running
		echo $$ > $lockfile
	if [ $? -ne 0 ]
	then
		  echo -e "${colorerror}Could not create lock file${colorclear}"
		  exit 1
		fi
	fi
	else
		# Create the lock file with current PID
		echo $$ > $lockfile
	if [ $? -ne 0 ]
	then
		echo -e "{$colorerror}Could not create lock file${colorclear}"
		exit 1
	fi
fi
# Lockfile aquired proceed with operations


## FUNCTIONS
#####################################################################
function log_success() {
    echo -e "${colorsuccess}$* $colorclear"
}

function log_info() {
    echo -e "${colorinfo}Notice: $* $colorclear"
}

function log_error() {
    echo -e "${colorerror}Error: $* $colorclear"
}

function log_warning() {
    echo -e "${colorwarn}Warning: $* $colorclear"
}

ScanNearbyNetworks()
{
#Check to see what SSID's and MAC addresses are in range
networkssid=('#null')
i=0; j=0
until [ $i -eq 1 ] #wait for wifi if busy, usb wifi is slower.
do
	echo "Attempting to scan for nearby networks...." 
	scanresults=$((iw dev "$interface" scan ap-force | egrep "^BSS|SSID:") 2>&1) >/dev/null 2>&1 
	echo "---Network Scan---" >> $networkscanfile
	date >> $networkscanfile
	echo $scanresults >> $networkscanfile
	echo -e "\n" >> $networkscanfile
	echo "Scan Finished"
	log_info "Scan results saved to $networkscanfile"

	if (($j >= 10)); then
		log_error "To many scan attempts, falling back to AP Mode"
		scanresults=""
		i=1
	elif echo "$scanresults" | grep "No such device (-19)" >/dev/null 2>&1; then
		log_error "No Wifi Capable Device Found!"
		wpa_supplicant -B -i "$interface" -c $wpaConfig >/dev/null 2>&1
		exit 1
	elif echo "$scanresults" | grep "Network is down (-100)" >/dev/null 2>&1; then
		log_error "Network is down, attempt " $j
		j=$((j + 1))
		sleep 2
	elif echo "$scanresults" | grep "Read-only file system (-30)" >/dev/null 2>&1; then
		log_warning "Read-only file system, attempt " $j
		j=$((j + 1))
		sleep 2
	elif ! echo "$scanresults" | grep "resource busy (-16)" >/dev/null 2>&1; then
		echo "Nearby networks found"
		i=1
	elif echo "$scanresults" | grep "resource busy (-16)" >/dev/null 2>&1; then
		j=$((j + 1))
		log_error "Scan failed (resource busy), attempt " $j
		sleep 2
	else
		log_error "Problem During Scan."
		j=$((j + 1))
		sleep 2
	fi
done

echo "Parsing network scan results..."
for ssid in "${networks[@]}"
do
	if (echo "$scanresults" | egrep "SSID: ${ssid}") >/dev/null 2>&1;
	then
		#Valid SSid found, passing to script
		log_success "Nearby network with saved configs found!"
		networkssid=$ssid
		return 0
	else
		#No Network found, #null issued"
		networkssid='#null'
	fi
done
}

StartAP() 
{
	echo "Starting Access Point (SSID: \"Mudpi\")..."
	ip link set dev "$interface" down
	ip addr add $staticip/24 brd + dev "$interface"
	ip link set dev "$interface" up
	dhcpcd -k "$interface" >/dev/null 2>&1
	sleep 2
	systemctl start hostapd
	sleep 2
	systemctl start dnsmasq
	sudo route add default gw $staticip
	log_success "Access Point Succsfully Started"
	echo "ip_address=$(hostname -I)"
}

StartAPMode() 
{
	echo "Checking AP Mode Status..."
	if systemctl status hostapd | grep "(running)" >/dev/null 2>&1 ;
	then
		log_success "AP Mode already Active!"
	elif { wpa_cli status | grep "$interface"; } >/dev/null 2>&1 ;
	then
		log_info "Flushing wifi configs and activating AP Mode"
		wpa_cli terminate >/dev/null 2>&1
		sleep 2
		ip addr flush "$interface"
		ip link set dev "$interface" down
		rm -r /var/run/wpa_supplicant >/dev/null 2>&1
		StartAP
	else #wifi off, start AP Mode
		echo "Attempting to start AP Mode..."
		StartAP
	fi
}

VerifyWifiConnectionSuccess()
{
	echo "Verifying Wifi Connected Successfully..."
	k=0; n=0
	connected=0
	maxattempts=3
	# Loop and attempt a few wifi connection fixes
	# 1st try ->	releases dhcpcd
	# 2nd try ->	reconfigures wpa_supplicant
	# 3rd try ->	restarts dhcpcd service
	until [ $k -eq 1 ]
	do
		sleep 15
		echo "Checking Wifi connection status..."
		if (($n >= $maxattempts)); then
			if wpa_cli -i "$interface" status | grep 'ip_address' >/dev/null 2>&1; then
				log_success "Network is Successfully Connected"
				wpa_cli -i "$interface" status | grep 'ip_address'
			else
				log_error "Wifi failed (max retries), reverting to AP Mode..."
				StartAPMode || log_error "Problem starting AP Mode!"
				# touch "$apfile" || log_warning "Unable to create override file $apfile"
			fi
			k=1
		elif ! wpa_cli -i "$interface" status | grep 'ip_address' >/dev/null 2>&1; then
			n=$((n + 1))
			log_warning "Wifi failed to connect. Attempt" $n
			echo "Reseting $interface..."
			ip link set dev "$interface" down
			echo "Flushing old configs $interface..."
			ip addr flush dev "$interface"
			ip link set dev "$interface" up
			if [[ $n -eq 2 ]]; then # attempt a wpa_cli reconfigure on the second failed attempt
				echo "Reconfiguring $interface..."
				wpa_cli -i "$interface" reconfigure >/dev/null 2>&1
				echo "Retrying Wifi connection..."
				sleep 5
			elif [[ $n -eq 3 ]]; then # final attempt restart the dhcpcd service
				echo "Restarting dhcpcd..."
				systemctl restart dhcpcd >/dev/null 2>&1
				echo "Retrying Wifi connection..."
				sleep 2
			else
				echo "Retrying Wifi connection..."
				dhcpcd -n "$interface" >/dev/null 2>&1
				sleep 2
			fi
		else
			log_success "Network is Successfully Connected"
			wpa_cli -i "$interface" status | grep 'ip_address'
			k=1
			connected=1
		fi
	done
}


## MAIN
############################################################
if [[ -f "$apfile" ]]; then
	log_info "Detected AP Mode Override File $apfile"
	StartAPMode || log_error "Problem starting AP Mode!"
	rm "$apfile"
elif [ "$ssids" != "" ]; then
	log_info "Configurations detected in $wpaConfig"
	echo "Networks parsed from config: ${ssids[@]}"
	ScanNearbyNetworks
	if [ "$networkssid" != "#null" ]; 
	then
		echo "Checking AP Mode status before connecting Wifi..."
		if systemctl status hostapd | grep "(running)" >/dev/null 2>&1
		then #AP running and configured network in range
			log_info "AP Mode active while configured network nearby..."
			echo "Shutting Down Access Point..."
			ip link set dev "$interface" down
			systemctl stop hostapd
			systemctl stop dnsmasq
			ip addr flush dev "$interface"
			ip link set dev "$interface" up
			dhcpcd  -n "$interface" >/dev/null 2>&1
			echo -e "Access Point Stopped Successfully"
			log_warning "AP Mode stopped for Wifi"
			echo "Attempting Wifi connection..."
			wpa_supplicant -B -i "$interface" -c $wpaConfig >/dev/null 2>&1
			# dhcpcd -n "$interface" >/dev/null 2>&1
			VerifyWifiConnectionSuccess
		elif { wpa_cli -i "$interface" status | grep 'ip_address'; } >/dev/null 2>&1
		then #Already connected
			echo "Verified AP Mode is Disabled"
			log_success "Wifi connection already established!"
		else #networks found and no hotspot running
			echo "Verified AP Mode is Disabled"
			echo "Attempting Wifi connection..."
			wpa_supplicant -B -i "$interface" -c $wpaConfig >/dev/null 2>&1
			# dhcpcd -n "$interface" >/dev/null 2>&1
			VerifyWifiConnectionSuccess
		fi
	else #no configured networks found in range
		log_warning "No Configured Network Found Nearby"
		StartAPMode || log_error "Problem starting AP Mode!"
	fi
else # no networks configured in wpa_supplicant
	log_info "No saved networks detected in $wpaConfig"
	StartAPMode || log_error "Problem starting AP Mode!"
fi

#echo "process is complete, removing lockfile"
echo "-----------------------------"
rm $lockfile
exit 0
##################################################################
