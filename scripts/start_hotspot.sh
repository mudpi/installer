adaptor='wlan0'
staticip='192.168.2.1'
if [ "$1" != "" ]; then
    adaptor=$1
fi
if [ "$2" != "" ]; then
    staticip=$2
fi

echo "Starting Access Point (SSID: \"Mudpi\")..."
ip link set dev "$adaptor" down
ip addr add $staticip/24 brd + dev "$adaptor"
ip link set dev "$adaptor" up
dhcpcd -k "$adaptor" >/dev/null 2>&1
sleep 2
systemctl start hostapd
sleep 2
systemctl start dnsmasq
echo "Access Point Succsfully Started"
echo "ip_address=${staticip}"