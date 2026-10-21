#!/bin/sh
# keyboard.sh - affiche ou masque le clavier virtuel (matchbox-keyboard).
#
#   keyboard.sh on          affiche le clavier et l'ancre en bas de l'ecran
#   keyboard.sh off         ferme le clavier
#   keyboard.sh necessaire  code 0 s'il n'y a AUCUN clavier physique branche
#   keyboard.sh etat        dit s'il est affiche (0 = oui, 1 = non)
#   keyboard.sh             bascule (defaut)
#
# Au demarrage, .xinitrc affiche le clavier dans tous les cas : la detection
# d'un clavier USB ci-dessous prenait trop de temps au boot. Elle reste
# disponible a la main (`keyboard.sh necessaire`) pour le diagnostic.

set -u
export DISPLAY=${DISPLAY:-:0}
DOCK=/usr/local/bin/dock-keyboard.sh

# Le clavier est porte par un service systemd (Restart=always) : s'il meurt, il
# revient tout seul. On passe donc par systemctl quand l'unite existe, sinon
# « off » serait annule par le redemarrage automatique.
UNIT=clavier-virtuel.service

avec_service() {
	command -v systemctl >/dev/null 2>&1 && systemctl cat "$UNIT" >/dev/null 2>&1
}

# PIDs du clavier (on evite pkill -f, qui peut tuer le shell appelant).
pids() {
	pgrep -f matchbox-keyboard 2>/dev/null | grep -v "^$$\$"
}

tourne() {
	if avec_service; then
		systemctl is-active --quiet "$UNIT" && return 0
	fi
	[ -n "$(pids)" ]
}

# Un clavier physique existe-t-il ?
#
# 1. Le plus sur : un peripherique d'entree capable de rapporter la touche A
#    (KEY_A = 30, donc le bit 30 du premier mot de capabilities/key). Le
#    tactile, les boutons de volume et le bouton power ne l'ont pas.
# 2. En secours : udev cree /dev/input/by-path/<...>-kbd pour un clavier.
# 3. En dernier recours : le noyau attache le gestionnaire "kbd" *avec* les LED
#    ("sysrq kbd leds eventN") a un vrai clavier. Attention, ce gestionnaire
#    apparait aussi, sans espace devant, sur gpio-keys et le bouton power
#    ("Handlers=kbd event0") : d'ou l'espace exige dans le motif.
clavier_physique() {
	for f in "${CAPS_DIR:-/sys/class/input}"/event*/device/capabilities/key; do
		[ -f "$f" ] || continue
		# shellcheck disable=SC2046
		set -- $(cat "$f" 2>/dev/null)
		[ $# -ge 1 ] || continue
		w0=$1
		len=${#w0}
		# Le premier mot fait au plus 16 chiffres hexa (touches 0 a 63).
		[ "$len" -ge 8 ] || continue
		pos=$((len - 7))   # chiffre hexadecimal des touches 28 a 31
		ch=$(printf '%s' "$w0" | cut -c"$pos")
		case $ch in
		4|5|6|7|c|C|d|D|e|E|f|F) return 0 ;;
		esac
	done
	for lien in /dev/input/by-path/*-kbd /dev/input/by-id/*-kbd; do
		[ -e "$lien" ] && return 0
	done
	grep -qE '^H:.*[[:space:]]kbd([[:space:]]|$)' /proc/bus/input/devices \
		2>/dev/null && return 0
	return 1
}

demarrer() {
	if avec_service; then
		if systemctl is-active --quiet "$UNIT"; then
			echo "clavier : deja affiche"
		else
			systemctl start "$UNIT" >/dev/null 2>&1
			echo "clavier : affiche (service $UNIT)"
		fi
	elif tourne; then
		echo "clavier : deja affiche"
	else
		# setsid : le clavier ne doit pas mourir avec le terminal ou la session
		# SSH qui l'a lance.
		if command -v setsid >/dev/null 2>&1; then
			MB_KBD_LANG=fr setsid matchbox-keyboard \
				</dev/null >/tmp/matchbox-keyboard.log 2>&1 &
		else
			MB_KBD_LANG=fr matchbox-keyboard \
				</dev/null >/tmp/matchbox-keyboard.log 2>&1 &
		fi
		echo "clavier : affiche"
	fi
	[ -x "$DOCK" ] && "$DOCK" 10
	exit 0
}

arreter() {
	# systemctl stop empeche le redemarrage automatique ; on nettoie ensuite les
	# processus restants, au cas ou l'unite serait absente.
	avec_service && systemctl stop "$UNIT" >/dev/null 2>&1
	if tourne; then
		for p in $(pids); do
			kill "$p" 2>/dev/null
		done
		sleep 1
		for p in $(pids); do
			kill -9 "$p" 2>/dev/null
		done
		echo "clavier : ferme"
	else
		echo "clavier : deja ferme"
	fi
	exit 0
}

case ${1:-bascule} in
on|afficher|ouvrir)   demarrer ;;
off|fermer|masquer)   arreter ;;
bascule|toggle)
	if tourne; then arreter; else demarrer; fi
	;;
etat|state)
	if tourne; then
		echo "clavier : affiche (pid $(pids))"
		exit 0
	else
		echo "clavier : ferme"
		exit 1
	fi
	;;
necessaire|requis)
	if clavier_physique; then
		echo "clavier physique present : clavier virtuel inutile"
		exit 1
	else
		echo "aucun clavier physique : clavier virtuel necessaire"
		exit 0
	fi
	;;
dock)
	[ -x "$DOCK" ] && exec "$DOCK" "${2:-8}"
	exit 0
	;;
*)
	echo "usage : keyboard.sh [on|off|bascule|etat|necessaire|dock]" >&2
	exit 2
	;;
esac
