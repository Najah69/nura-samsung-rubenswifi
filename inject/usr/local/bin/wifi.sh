#!/bin/sh
# Aide Wi-Fi manuelle. wlan0 est tenu par le service wpa-wlan0 (wpa_supplicant)
# et wifi-dhcp : on passe donc par wpa_cli, pas par nmcli.
IF=wlan0
CTRL=/run/wpa_supplicant
DHCP=/usr/share/udhcpc/default.script

case "${1:-status}" in
status)
	echo "--- services ---"
	echo "wpa-wlan0   : $(systemctl is-active wpa-wlan0 2>/dev/null)"
	echo "wifi-dhcp   : $(systemctl is-active wifi-dhcp 2>/dev/null)"
	echo "--- association ---"
	wpa_cli -p "$CTRL" -i "$IF" status 2>/dev/null | sed -n '1,10p'
	echo "--- adresse ---"
	ip -4 -o addr show "$IF" 2>/dev/null | awk '{print $2 " " $4}'
	echo "--- journal ---"
	tail -8 /run/wifi-direct.log 2>/dev/null
	;;
debug)
	echo "--- trace wpa_supplicant (journal, 30 dernieres lignes) ---"
	journalctl -u wpa-wlan0 -n 30 -o cat 2>/dev/null | cut -c1-78
	;;
scan)
	wpa_cli -p "$CTRL" -i "$IF" scan >/dev/null 2>&1
	sleep 4
	wpa_cli -p "$CTRL" -i "$IF" scan_results 2>/dev/null | awk -F'\t' \
		'NR>1 {printf "%-30s %4s dBm  %s\n", $5, $3, $4}' | cut -c1-78
	;;
connect)
	ssid=$2
	psk=${3:-}
	[ -n "$ssid" ] || { echo "usage : wifi.sh connect SSID [MOTDEPASSE]"; exit 1; }
	id=$(wpa_cli -p "$CTRL" -i "$IF" add_network 2>/dev/null | tail -1)
	[ -n "$id" ] || { echo "wpa_supplicant ne repond pas (voir wifi.sh debug)"; exit 1; }
	wpa_cli -p "$CTRL" -i "$IF" set_network "$id" ssid "\"$ssid\"" >/dev/null
	if [ -n "$psk" ]; then
		wpa_cli -p "$CTRL" -i "$IF" set_network "$id" psk "\"$psk\"" >/dev/null
	else
		wpa_cli -p "$CTRL" -i "$IF" set_network "$id" key_mgmt NONE >/dev/null
	fi
	wpa_cli -p "$CTRL" -i "$IF" select_network "$id" >/dev/null
	echo "reseau $id ($ssid) selectionne"
	udhcpc -i "$IF" -b -s "$DHCP" -p "/run/udhcpc-$IF.pid" >/dev/null 2>&1
	sleep 6
	ip -4 -o addr show "$IF" 2>/dev/null | awk '{print $4}'
	;;
on)
	rfkill unblock wlan 2>/dev/null
	ip link set "$IF" up
	echo "$IF : $(cat /sys/class/net/$IF/operstate 2>/dev/null)"
	;;
off)
	ip link set "$IF" down
	echo "$IF : $(cat /sys/class/net/$IF/operstate 2>/dev/null)"
	;;
*)
	echo "usage : wifi.sh [status|debug|scan|connect SSID [MOTDEPASSE]|on|off]"
	exit 1
	;;
esac
