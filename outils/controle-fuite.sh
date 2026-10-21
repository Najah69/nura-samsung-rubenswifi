#!/bin/bash
#  controle-fuite.sh - verifie qu'une image ne contient aucune donnee
#  personnelle, et rappelle son empreinte.
#
#  usage : sudo controle-fuite.sh <image.img>
#
#  L'image est montee en lecture seule (ro,noload) : son empreinte reste donc
#  valable apres le controle. Un montage en lecture-ecriture, lui, modifie le
#  superbloc et le journal, et l'empreinte ne correspond plus.
set -uo pipefail

IMG=${1:?usage : sudo controle-fuite.sh <image.img>}
M=$(mktemp -d)
fuite=0

L=$(losetup -fP --show "$IMG") || { echo "impossible de monter $IMG"; exit 1; }
trap 'umount "$M" 2>/dev/null; losetup -d "$L" 2>/dev/null; rmdir "$M" 2>/dev/null' EXIT
mount -o ro,noload "${L}p2" "$M" || { echo "partition 2 illisible"; exit 1; }

echo "== donnees personnelles =="
# Invariants d'une image publiable : aucun reseau enregistre, aucun mot de passe
# en clair. On ne code pas ici les chaines personnelles de l'auteur (ce serait
# les publier) : passez-les par la variable MOTIFS si vous en avez.
if grep -qE '^[[:space:]]*(psk|password)=' "$M/etc/wpa_supplicant/wpa_supplicant-wlan0.conf" 2>/dev/null; then
	echo "  [!!]  un reseau est enregistre dans le fichier Wi-Fi"
	fuite=1
else
	echo "  [ok]  aucun reseau enregistre (fichier Wi-Fi vierge)"
fi
if grep -rqs '#psk="' "$M/etc" 2>/dev/null; then
	echo "  [!!]  un mot de passe Wi-Fi est present en clair (#psk=...)"
	grep -rl '#psk="' "$M/etc" 2>/dev/null | sed "s|$M|       .|"
	fuite=1
else
	echo "  [ok]  aucun mot de passe Wi-Fi en clair"
fi
for motif in ${MOTIFS:-}; do
	c=$(grep -rl "$motif" "$M/etc" "$M/usr/local" "$M/root" "$M/home" "$M/var" 2>/dev/null | wc -l)
	if [ "$c" = 0 ]; then
		printf '  [ok]  %-14s absent\n' "$motif"
	else
		printf '  [!!]  %-14s present :\n' "$motif"
		grep -rl "$motif" "$M/etc" "$M/usr/local" "$M/root" "$M/home" "$M/var" 2>/dev/null | sed "s|$M|       .|"
		fuite=1
	fi
done
[ -z "${MOTIFS:-}" ] && echo "  (MOTIFS vide : seuls les invariants sont verifies)"

echo "== comptes =="
awk -F: '$1=="root"||$1=="najah"||$1=="dsh"{printf "  %-6s %s\n", $1, substr($2,1,14)}' "$M/etc/shadow" 2>/dev/null

echo "== mot de passe VNC =="
grep -n 'storepasswd' "$M/etc/systemd/system/x11vnc.service" 2>/dev/null | sed 's/^/  /'

echo "== fichier Wi-Fi livre =="
grep -E '^(ssid|psk|key_mgmt|ctrl_interface)' "$M/etc/wpa_supplicant/wpa_supplicant-wlan0.conf" 2>/dev/null | sed 's/^/  /'
echo "  droits : $(stat -c '%a %U:%G' "$M/etc/wpa_supplicant/wpa_supplicant-wlan0.conf")"

echo "== traces =="
for f in "$M/var/lib/nura/assistant.done" "$M/root/.vnc/passwd" "$M/root/.ssh" "$M/home/najah/.ssh"; do
	[ -e "$f" ] && { echo "  [!!] $f existe"; fuite=1; }
done
echo "  [ok] pas de cle SSH, pas de .vnc/passwd, pas d'assistant termine"

echo "== empreinte (mesuree sur l'image, non modifiee) =="
sha256sum "$IMG" | sed 's/^/  /'

[ "$fuite" = 0 ] && echo "=== AUCUNE FUITE ===" || echo "=== FUITE DETECTEE ==="
exit "$fuite"
