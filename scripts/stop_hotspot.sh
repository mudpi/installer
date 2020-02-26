adaptor='wlan0'

if [ "$1" != "" ]; then
    adaptor=$1
fi
echo "Shutting Down Access Point..."
ip link set dev "$adaptor" down
systemctl stop hostapd
systemctl stop dnsmasq
ip addr flush dev "$adaptor"
ip link set dev "$adaptor" up
dhcpcd  -n "$adaptor" >/dev/null 2>&1
echo "Access Point Stopped Succsfully"