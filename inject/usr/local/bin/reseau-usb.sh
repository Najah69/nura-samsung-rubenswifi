#!/bin/sh
# reseau-usb.sh - reseau par cable USB (gadget NCM cote tablette)
# usage : reseau-usb.sh up | down | etat
#
# La tablette est en 172.16.42.1/24. Le PC recoit son adresse du serveur DHCP
# de postmarketOS (unudhcpd@usb0 : serveur 172.16.42.1, client 172.16.42.2).
# dnsmasq n'est lance qu'en secours si ce service n'existe pas, pour ne jamais
# avoir deux serveurs DHCP sur la meme interface.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
IP=172.16.42.1
MASQUE=24
LOG=/var/log/nura-usbnet.log

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG" 2>/dev/null; }

interface_usb() {
	for i in usb0 usb1 usb2; do
		ip link show "$i" >/dev/null 2>&1 && { echo "$i"; return 0; }
	done
	return 1
}

udc_present() { [ -n "$(ls /sys/class/udc 2>/dev/null)" ]; }

cable() { # 1 = un ordinateur est branche, 0 sinon
	[ "$(cat "/sys/class/net/$1/carrier" 2>/dev/null)" = "1" ] && echo 1 || echo 0
}

service_dhcp() {
	systemctl is-active --quiet "unudhcpd@$1" 2>/dev/null && { echo unudhcpd; return 0; }
	[ -f "/run/nura-dnsmasq-$1.pid" ] && { echo dnsmasq; return 0; }
	echo aucun
}

demarrer_dnsmasq() {
	iface=$1
	pidfile=/run/nura-dnsmasq-$iface.pid
	[ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null && sleep 1
	dnsmasq --conf-file=/dev/null --bind-dynamic --interface="$iface" \
		--dhcp-range=172.16.42.10,172.16.42.50,255.255.255.0,12h \
		--dhcp-option=3 --dhcp-option=6 --domain-needed --bogus-priv \
		--pid-file="$pidfile" --log-facility=/var/log/nura-dnsmasq.log \
		>/dev/null 2>&1 && log "dnsmasq demarre sur $iface (secours)"
}

cas_up() {
	if ! udc_present; then
		systemctl start usb-gadget 2>/dev/null
		i=0
		while [ $i -lt 15 ] && ! udc_present; do sleep 1; i=$((i + 1)); done
	fi
	if ! udc_present; then
		echo "indisponible: aucun controleur USB (UDC)"
		log "up : pas d'UDC"
		return 3
	fi

	iface=$(interface_usb) || true
	if [ -z "${iface:-}" ]; then
		i=0
		while [ $i -lt 20 ]; do
			iface=$(interface_usb) || true
			[ -n "${iface:-}" ] && break
			sleep 1; i=$((i + 1))
		done
	fi
	if [ -z "${iface:-}" ]; then
		echo "indisponible: UDC present ($(ls /sys/class/udc 2>/dev/null | head -1)) mais aucune interface reseau USB"
		log "up : UDC sans interface"
		return 3
	fi

	ip -4 addr show "$iface" 2>/dev/null | grep -q "inet $IP/" ||
		ip addr add "$IP/$MASQUE" dev "$iface" || {
			echo "indisponible: adresse $IP impossible sur $iface"
			log "up : adresse refusee sur $iface"
			return 3
		}
	ip link set "$iface" up

	if systemctl is-active --quiet "unudhcpd@$iface" 2>/dev/null; then
		log "up : $IP sur $iface, dhcp par unudhcpd@$iface"
	else
		demarrer_dnsmasq "$iface"
	fi

	echo "actif $IP sur $iface (dhcp $(service_dhcp "$iface"), cable $(cable "$iface"))"
	log "up : $IP sur $iface (cable $(cable "$iface"))"
	return 0
}

cas_down() {
	iface=$(interface_usb) || true
	if [ -n "${iface:-}" ]; then
		pidfile=/run/nura-dnsmasq-$iface.pid
		[ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null
		rm -f "$pidfile"
		ip addr flush dev "$iface" 2>/dev/null
		ip link set "$iface" down 2>/dev/null
		echo "arrete ($iface)"
	else
		echo "arrete (aucune interface USB)"
	fi
	log "down"
}

cas_etat() {
	if ! udc_present; then
		echo "controleur : absent -> reseau USB impossible"
	else
		echo "controleur : $(ls /sys/class/udc 2>/dev/null | head -1)"
	fi
	iface=$(interface_usb) || true
	if [ -n "${iface:-}" ]; then
		echo "interface  : $iface"
		ip -4 -o addr show "$iface" 2>/dev/null | awk '{print "adresse    : " $4}'
		if [ "$(cable "$iface")" = "1" ]; then
			echo "cable      : branche (ordinateur detecte)"
		else
			echo "cable      : debranche"
		fi
		echo "dhcp       : $(service_dhcp "$iface")"
		awk -v i="$iface" '$1 == i || $1 ~ ("^" i) { print "trafic     : " $0 }' /proc/net/dev 2>/dev/null | head -1
	else
		echo "interface  : aucune (usb0/usb1 absents)"
	fi
}

case "${1:-etat}" in
up)   cas_up ;;
down) cas_down ;;
etat) cas_etat ;;
*)
	echo "usage: reseau-usb.sh up | down | etat" >&2
	exit 1
	;;
esac
