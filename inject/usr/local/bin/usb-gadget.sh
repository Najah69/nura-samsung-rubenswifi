#!/bin/sh
# Gadget USB de la Galaxy Tab Active 8.0 : reseau (RNDIS + NCM) et port serie ACM.
# Objectif : joindre la tablette en SSH par le cable USB, sans Wi-Fi ni carte SD.
# La tablette prend 172.16.42.1/24 sur usb0 ; le PC se met en 172.16.42.2/24.

CONFIGFS=/sys/kernel/config
GADGET=$CONFIGFS/usb_gadget/g1
IP=172.16.42.1
LOG=/tmp/usb-gadget.log
exec >>"$LOG" 2>&1
echo "=== $(date -Is) demarrage du gadget USB ==="

for m in libcomposite usb_configfs usb_f_rndis usb_f_ecm usb_f_ncm usb_f_acm; do
	modprobe "$m" 2>/dev/null
done

mount -t configfs none "$CONFIGFS" 2>/dev/null
if [ ! -d "$CONFIGFS/usb_gadget" ]; then
	echo "configfs indisponible"
	exit 1
fi

# Deja lie lors d'un demarrage precedent : on ne recree pas.
if [ -s "$GADGET/UDC" ]; then
	echo "gadget deja lie a $(cat "$GADGET/UDC")"
else
	rm -rf "$GADGET" 2>/dev/null
	mkdir -p "$GADGET" || { echo "creation du gadget impossible"; exit 1; }
	echo 0x1d6b >"$GADGET/idVendor"
	echo 0x0104 >"$GADGET/idProduct"
	echo 0x0200 >"$GADGET/bcdUSB"
	echo 0x0100 >"$GADGET/bcdDevice"
	echo 0xef >"$GADGET/bDeviceClass"
	echo 0x02 >"$GADGET/bDeviceSubClass"
	echo 0x01 >"$GADGET/bDeviceProtocol"
	mkdir -p "$GADGET/strings/0x409"
	echo "postmarketOS" >"$GADGET/strings/0x409/manufacturer"
	echo "Galaxy Tab Active 8.0" >"$GADGET/strings/0x409/product"
	echo "rubenswifi" >"$GADGET/strings/0x409/serialnumber"
	mkdir -p "$GADGET/configs/c.1/strings/0x409"
	echo "reseau et serie" >"$GADGET/configs/c.1/strings/0x409/configuration"
	echo 500 >"$GADGET/configs/c.1/MaxPower"

	mkdir -p "$GADGET/functions/rndis.usb0"
	echo 02:11:22:33:44:55 >"$GADGET/functions/rndis.usb0/dev_addr" 2>/dev/null
	echo 02:11:22:33:44:56 >"$GADGET/functions/rndis.usb0/host_addr" 2>/dev/null
	mkdir -p "$GADGET/functions/ncm.usb0"
	mkdir -p "$GADGET/functions/acm.GS0"

	ln -sf "$GADGET/functions/rndis.usb0" "$GADGET/configs/c.1/" 2>/dev/null
	ln -sf "$GADGET/functions/ncm.usb0" "$GADGET/configs/c.1/" 2>/dev/null
	ln -sf "$GADGET/functions/acm.GS0" "$GADGET/configs/c.1/" 2>/dev/null

	i=0
	UDC=""
	while [ "$i" -lt 90 ]; do
		UDC=$(ls /sys/class/udc 2>/dev/null | head -1)
		[ -n "$UDC" ] && break
		i=$((i + 1))
		sleep 1
	done
	if [ -z "$UDC" ]; then
		echo "aucun controleur UDC apres 90 s (le PHY USB n'a pas demarre)"
		exit 1
	fi
	echo "UDC trouve : $UDC"
	echo "$UDC" >"$GADGET/UDC" || { echo "liaison UDC refusee"; exit 1; }
fi

# Adresse IP sur les interfaces reseau creees par le gadget.
n=0
while [ "$n" -lt 30 ]; do
	found=0
	for dev in /sys/class/net/usb*; do
		[ -e "$dev" ] || continue
		name=$(basename "$dev")
		found=1
		if ! ip -4 addr show "$name" 2>/dev/null | grep -q "$IP"; then
			ip addr add "$IP/24" dev "$name" 2>/dev/null ||
				ifconfig "$name" "$IP" netmask 255.255.255.0 2>/dev/null
		fi
		ip link set "$name" up 2>/dev/null || ifconfig "$name" up 2>/dev/null
	done
	if [ "$found" = 1 ]; then break; fi
	n=$((n + 1))
	sleep 1
done

echo "--- etat final ---"
for dev in /sys/class/net/usb*; do
	[ -e "$dev" ] || continue
	name=$(basename "$dev")
	echo "$name : $(ip -4 addr show "$name" 2>/dev/null | grep inet | tr -s ' ')"
done
echo "udc : $(cat "$GADGET/UDC" 2>/dev/null)"
echo "=== $(date -Is) fin ==="
