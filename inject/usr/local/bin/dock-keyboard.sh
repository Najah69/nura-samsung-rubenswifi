#!/bin/sh
# dock-keyboard.sh - ancre le clavier virtuel (matchbox-keyboard) en bas de
# l'ecran et lui donne la largeur de l'ecran.
#
# Le paquet installe n'accepte ni --geometry ni --fontsize : c'est xdotool qui
# place la fenetre. On le fait UNE fois (deux passes, IceWM replace parfois la
# fenetre apres son apparition) et on rend la main : l'ancienne version
# repositionnait le clavier pendant 60 s, ce qui le faisait sauter dans tous les
# sens des que l'ecran tournait.
#
# usage : dock-keyboard.sh [secondes_d_attente]   (defaut 8)

set -u
export DISPLAY=${DISPLAY:-:0}
ATTENTE=${1:-8}
case $ATTENTE in
*[!0-9]*) ATTENTE=8 ;;
esac

if ! command -v xdotool >/dev/null 2>&1; then
	echo "dock : xdotool absent, rien a faire" >&2
	exit 0
fi

# matchbox-keyboard ne pose PAS de WM_CLASS : seule la recherche par nom
# (WM_NAME = "Keyboard") le trouve. Les deux autres formes restent en secours.
chercher() {
	FEN=""
	for opt in "--name ^Keyboard$" "--name Keyboard" \
		"--classname matchbox-keyboard" "--class matchbox-keyboard"; do
		FEN=$(xdotool search $opt 2>/dev/null | head -1)
		[ -n "$FEN" ] && return 0
	done
	return 1
}

# 1. Attendre la fenetre du clavier (ATTENTE secondes au plus).
i=0
FEN=""
while [ "$i" -lt "$ATTENTE" ]; do
	chercher && break
	i=$((i + 1))
	sleep 1
done
if [ -z "$FEN" ]; then
	echo "dock : aucune fenetre de clavier apres ${ATTENTE} s" >&2
	exit 1
fi

# 2. Taille et position, deux passes espacees d'une seconde.
# 42 % de la hauteur : au tiers, la derniere rangee (Ctrl, Alt, espace) etait
# coupee par le bas de l'ecran. Les 24 px retires correspondent a la barre de
# titre de la fenetre, que IceWM place AU-DESSUS de la zone demandee.
n=0
while [ "$n" -lt 2 ]; do
	GEOM=$(xdotool getdisplaygeometry 2>/dev/null)
	SW=${GEOM% *}
	SH=${GEOM#* }
	[ -n "$SW" ] || SW=800
	[ -n "$SH" ] || SH=1280
	KH=$((SH * 42 / 100))
	xdotool windowsize "$FEN" "$SW" "$KH" 2>/dev/null
	# Le clavier arrondit sa hauteur : on la mesure, puis on colle son bas au
	# bas de l'ecran (les 24 px retires sont la barre de titre placee par IceWM
	# AU-DESSUS de la zone demandee).
	HEIGHT=$(xdotool getwindowgeometry --shell "$FEN" 2>/dev/null | sed -n 's/^HEIGHT=//p')
	[ -n "$HEIGHT" ] || HEIGHT=$KH
	KY=$((SH - HEIGHT - 24))
	[ "$KY" -lt 0 ] && KY=0
	xdotool windowmove "$FEN" 0 "$KY" 2>/dev/null
	xdotool windowraise "$FEN" 2>/dev/null
	echo "dock : clavier ${SW}x${HEIGHT} en (0,${KY})"
	n=$((n + 1))
	[ "$n" -lt 2 ] && sleep 1
done

# 3. Masquer d'eventuelles fenetres en double.
PREMIER=1
for w in $(xdotool search --name Keyboard 2>/dev/null); do
	if [ "$PREMIER" = 1 ]; then
		PREMIER=0
	else
		xdotool windowunmap "$w" 2>/dev/null
		echo "dock : fenetre en double $w masquee"
	fi
done

exit 0
