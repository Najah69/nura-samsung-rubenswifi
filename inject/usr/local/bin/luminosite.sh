#!/bin/sh
# luminosite.sh - regle le retroeclairage de l'ecran (puce lp8556).
#
# usage : luminosite.sh plus | moins | NN% | N | etat | init
#   plus / moins : un cran (20 sur 255) ; NN% : pourcentage ; N : valeur brute.
#   init : passe la puce en mode « registre » (lance au demarrage par
#          nura-energie.service, voir plus bas).
# La valeur est memorisee dans /var/lib/nura/luminosite, que relit le service
# nura-energie (touches de volume, extinction de l'ecran).
#
# Pourquoi « init » : le device tree configure la LP8556 avec dev-ctrl = 0x80,
# soit BRT_MODE = 00 (« entree PWM seulement ») : la puce ignore alors son
# registre de luminosite, que le pilote lp855x ecrit pourtant. Rien ne bougeait
# a l'ecran. En ecrivant 0x85 dans le registre 0x01 (BL_CTL = 1, BRT_MODE = 10,
# « registre seulement », valeur donnee en exemple par la documentation du
# pilote), la luminosite suit /sys/class/backlight. Fait a chaud par I2C :
# le device tree et le demarrage ne sont pas touches (un redemarrage remet 0x80,
# d'ou l'appel a chaque lancement du service). Verifie sur la tablette le 23/10.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BL=/sys/class/backlight/lcd-backlight
ETAT=/var/lib/nura/luminosite
MIN=8
PAS=20

[ -d "$BL" ] || { echo "retroeclairage introuvable ($BL)" >&2; exit 1; }
max=$(cat "$BL/max_brightness")
cur=$(cat "$BL/brightness")

case "${1:-etat}" in
init)
	# Bus I2C de la puce, lu dans sysfs (.../i2c-N/N-002c), pas suppose.
	dev=$(readlink -f "$BL/device")
	bus=$(basename "$(dirname "$dev")"); bus=${bus#i2c-}
	adr=0x$(basename "$dev" | sed 's/^[0-9]*-00*//')
	command -v i2cget >/dev/null || { echo "i2c-tools absent" >&2; exit 1; }
	ctl=$(i2cget -f -y "$bus" "$adr" 0x01 2>/dev/null)
	case "$ctl" in
	0x85) echo "lp8556 deja en mode registre (bus $bus, $adr)" ;;
	0x80)
		i2cset -f -y "$bus" "$adr" 0x01 0x85 || exit 1
		echo "$cur" > "$BL/brightness"
		echo "lp8556 : mode registre active (bus $bus, $adr, 0x80 -> 0x85)"
		;;
	*) echo "lp8556 : registre de controle inattendu ($ctl), rien change" >&2; exit 1 ;;
	esac
	exit 0
	;;
plus)  v=$((cur + PAS)) ;;
moins) v=$((cur - PAS)) ;;
*%)    v=$(( ${1%\%} * max / 100 )) ;;
etat)
	echo "Luminosite : $cur / $max ($((cur * 100 / max)) %)"
	exit 0
	;;
*[!0-9]*|'')
	echo "usage : luminosite.sh plus | moins | NN% | N | etat" >&2
	exit 1
	;;
*)     v=$1 ;;
esac

[ "$v" -lt "$MIN" ] && v=$MIN
[ "$v" -gt "$max" ] && v=$max
echo "$v" > "$BL/brightness" || exit 1
mkdir -p "$(dirname "$ETAT")"
echo "$v" > "$ETAT"
echo "Luminosite : $v / $max"
