#!/bin/sh
# clavier-virtuel.sh - affiche le clavier tactile et l'ancre en bas de l'ecran.
#
# Appele par clavier-virtuel.service, qui le relance si matchbox-keyboard meurt.
# keyboard.sh passe par systemctl pour l'afficher ou le masquer, afin que ce
# redemarrage automatique ne le rallume pas aussitot.

set -u

export DISPLAY=:0
export HOME=${HOME:-/root}
export MB_KBD_LANG=fr

DOCK=/usr/local/bin/dock-keyboard.sh
ATTENTE=60
JOURNAL=/var/log/clavier-virtuel.log

dire() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$JOURNAL" 2>/dev/null; }

# 0. Reglage de l'assistant (CLAVIER on/off), evalue une seule fois par
#    demarrage : ensuite c'est keyboard.sh qui commande, via systemctl.
if [ ! -f /run/clavier-virtuel.vu ]; then
	: >/run/clavier-virtuel.vu 2>/dev/null
	if [ "$(/usr/local/bin/nura-config get CLAVIER 2>/dev/null)" = off ]; then
		dire "reglage CLAVIER=off : clavier non affiche"
		exit 0
	fi
fi

# 1. Attendre le serveur X. Son cookie change a chaque demarrage
#    (/root/.serverauth.<pid>) : on le cherche donc a chaque fois.
i=0
while [ "$i" -lt "$ATTENTE" ]; do
	auth=$(ls -1 /root/.serverauth.* 2>/dev/null | head -1)
	if [ -n "${auth:-}" ] && XAUTHORITY="$auth" xdpyinfo >/dev/null 2>&1; then
		export XAUTHORITY="$auth"
		break
	fi
	sleep 1
	i=$((i + 1))
done

if [ -z "${XAUTHORITY:-}" ]; then
	dire "X indisponible apres $ATTENTE s"
	exit 1
fi
dire "X pret (cookie $XAUTHORITY)"

# 2. Laisser la rotation et la matrice du tactile s'appliquer : l'ancrage du
#    clavier depend de la geometrie de l'ecran.
sleep 3

# 3. Lancer le clavier, l'ancrer, puis rester en vie tant qu'il tourne : c'est
#    ce processus qui porte l'etat du service.
matchbox-keyboard </dev/null >/tmp/matchbox-keyboard.log 2>&1 &
kbd=$!
sleep 1
if [ -x "$DOCK" ]; then
	"$DOCK" 10 >/dev/null 2>&1
fi
wait "$kbd"
code=$?
dire "matchbox-keyboard termine (code $code)"

# Code 1 : le service (Restart=on-failure) le relance. Un arret volontaire passe
# par « systemctl stop », qui ne declenche aucun redemarrage.
exit 1