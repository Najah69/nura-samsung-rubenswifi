#!/bin/sh
# Rapport de diagnostic affiche au demarrage dans un xterm : une photo suffit.
# Wi-Fi d'abord (c'est ce qui bloque), le reste ensuite. ASCII seulement : la
# police du xterm n'a pas les tirets longs ni les points de suspension.
IF=wlan0
CTRL=/run/wpa_supplicant

line() { printf '%s\n' "--------------------------------------------------------------"; }

echo "=== WI-FI ==="
if [ -e "/sys/class/net/$IF" ]; then
	printf '%s : %s  %s\n' "$IF" "$(cat /sys/class/net/$IF/address 2>/dev/null)" \
		"$(cat /sys/class/net/$IF/operstate 2>/dev/null)"
else
	echo "$IF : ABSENT"
fi
printf 'services : wpa-wlan0=%s  wifi-dhcp=%s\n' \
	"$(systemctl is-active wpa-wlan0 2>/dev/null)" \
	"$(systemctl is-active wifi-dhcp 2>/dev/null)"
printf 'wpa      : %s\n' "$(wpa_cli -p "$CTRL" -i "$IF" status 2>/dev/null |
	sed -n 's/^\(wpa_state\|ssid\|key_mgmt\)=/\1=/p' | tr '\n' ' ')"
printf 'ip       : %s\n' "$(ip -4 -o addr show "$IF" 2>/dev/null | awk '{print $4}' | tr '\n' ' ')"

# Trace du supplicant : c'est elle qui dira pourquoi l'association echoue.
# Elle va dans le journal (option -dd). L'option -f n'existe pas dans
# wpa_supplicant (c'est une option de hostapd) : il imprimait son usage.
TRACE=$(journalctl -u wpa-wlan0 -n 14 -o cat 2>/dev/null | cut -c1-78)
if [ -n "$TRACE" ]; then
	echo "--- wpa_supplicant (fin de trace) ---"
	printf '%s\n' "$TRACE"
else
	echo "--- wpa_supplicant : journal vide (pas demarre) ---"
fi

if [ -f /run/wifi-direct.log ]; then
	echo "--- wifi-dhcp ---"
	tail -6 /run/wifi-direct.log 2>/dev/null | cut -c1-78
fi

printf 'modules  : %s\n' \
	"$(ls /sys/module 2>/dev/null | grep -E 'wcn36xx|qcom_wcnss|mac80211|cfg80211' | tr '\n' ' ')"
printf 'firmware : %s fichier(s) wcnss dans /lib/firmware, %s dans la cible\n' \
	"$(ls /lib/firmware/wcnss* 2>/dev/null | wc -l)" \
	"$(ls /run/msm-firmware-loader/target 2>/dev/null | grep -ci wcnss)"
printf 'calib    : %s\n' \
	"$([ -f /lib/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin ] && echo presente || echo MANQUANTE)"
# Le DTB reellement demarre se lit dans /proc/device-tree.
DT=/proc/device-tree/soc/remoteproc@fb204000
if [ -e "$DT/iris/vddxo-supply" ] && [ -e "$DT/pinctrl-0" ]; then
	echo "dtb      : WCNSS configure (iris + pinctrl wlan)"
else
	echo "dtb      : ANCIEN (iris ou pinctrl absent) - mauvais fichier flashe"
fi

line
echo "=== ECRAN ==="
DISPLAY=:0 xdpyinfo 2>/dev/null | grep -E 'dimensions|depth of root' || echo "xdpyinfo absent"
printf 'fb0   %s  stride %s  bpp %s\n' \
	"$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)" \
	"$(cat /sys/class/graphics/fb0/stride 2>/dev/null)" \
	"$(cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null)"

line
echo "=== USB (gadget) ==="
printf 'udc       : [%s]\n' "$(ls /sys/class/udc 2>/dev/null | tr '\n' ' ')"
for u in /sys/class/udc/*; do
	[ -d "$u" ] || continue
	printf '%s : %s / %s\n' "$(basename "$u")" \
		"$(cat "$u/state" 2>/dev/null)" \
		"$(cat "$u/function" 2>/dev/null | cut -c1-30)"
done

line
echo "=== RESEAU ==="
ip -4 addr 2>/dev/null | grep -E '^[0-9]+:|inet ' | cut -c1-70
printf 'sshd : %s   x11vnc : %s\n' \
	"$(systemctl is-active sshd 2>/dev/null)" \
	"$(systemctl is-active x11vnc 2>/dev/null)"

line
echo "Commandes utiles :"
echo "  wifi.sh status   etat du Wi-Fi et journal"
echo "  wifi.sh debug    trace complete du supplicant"
echo "  wifi.sh scan     liste des reseaux"
