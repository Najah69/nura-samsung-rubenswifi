#!/bin/sh
# batterie.sh - estimation de la charge restante
#
# Cette tablette n'a pas de jauge a carburant exploitable en noyau libre
# (la charge est geree par un MAX77804K sans pilote ; le PM8226 ne fournit
# qu'une tension). On estime donc le pourcentage a partir de la tension
# vph_pwr lue par le convertisseur analogique du PM8226.
# C'est une ESTIMATION : elle ne remplace pas une jauge, et elle est
# pessimiste quand la tablette travaille (la tension s'ecroule sous charge).
#
# usage : batterie.sh [court|long]
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
ETIQUETTE="Batterie"

trouver_adc() {
	for d in /sys/bus/iio/devices/iio:device*; do
		n=$(cat "$d/name" 2>/dev/null)
		case "$n" in
		*adc@3100*) echo "$d"; return 0 ;;
		esac
	done
	return 1
}

lire_uv() {
	d=$(trouver_adc) || return 1
	# in_voltage7 = vph_pwr
	for f in in_voltage7_input in_voltage7_raw; do
		[ -f "$d/$f" ] && { cat "$d/$f"; return 0; }
	done
	return 1
}

lire_courant() {
	for d in /sys/bus/iio/devices/iio:device*; do
		n=$(cat "$d/name" 2>/dev/null)
		case "$n" in
		*adc@3600*)
			[ -f "$d/in_current0_raw" ] || continue
			raw=$(cat "$d/in_current0_raw" 2>/dev/null)
			sca=$(cat "$d/in_current0_scale" 2>/dev/null)
			[ -n "$raw" ] || return 1
			echo "$raw $sca"
			return 0
			;;
		esac
	done
	return 1
}

pourcentage() { # $1 = tension en mV
	awk -v mv="$1" 'BEGIN {
		n = split("3300 0 3400 1 3500 3 3550 5 3600 8 3650 12 3700 18 3750 25 \
3800 33 3850 42 3900 52 3950 61 4000 69 4050 77 4100 84 4150 90 4200 94 4250 97 4350 100", t, " ")
		if (mv <= t[1]) { print 0; exit }
		if (mv >= t[n-1]) { print 100; exit }
		for (i = 1; i < n; i += 2) {
			if (mv >= t[i] && mv <= t[i+2]) {
				p = t[i+1] + (mv - t[i]) * (t[i+3] - t[i+1]) / (t[i+2] - t[i])
				printf "%.0f\n", p
				exit
			}
		}
		print 0
	}'
}

uv=$(lire_uv) || {
	echo "Batterie : tension indisponible (PMIC non lisible)"
	exit 1
}
mv=$((uv / 1000))
pct=$(pourcentage "$mv")
volts=$(awk -v mv="$mv" 'BEGIN { printf "%.2f", mv / 1000 }')

if [ "${1:-long}" = court ]; then
	echo "≈ ${pct} % (${volts} V)"
	exit 0
fi

echo "Batterie de la tablette Nura"
echo "---------------------------"
echo "  Charge estimee : ${pct} %"
echo "  Tension        : ${volts} V  (${mv} mV sur vph_pwr)"
cur=$(lire_courant) || cur=""
if [ -n "$cur" ]; then
	set -- $cur
	ma=$(awk -v r="$1" -v s="${2:-0.001}" 'BEGIN { printf "%.0f", (r * s > 10 ? r * s : r * s * 1000) }')
	[ -n "$ma" ] && echo "  Courant        : ${ma} mA"
fi
echo
echo "Estimation par tension : pas de jauge dans le noyau libre."
echo "La valeur baisse quand la tablette travaille ; elle remonte au repos."
