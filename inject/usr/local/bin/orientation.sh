#!/bin/sh
# orientation.sh - met l'ecran de la tablette en paysage ou en portrait.
#
# Le pilote X "fbdev" accepte la rotation RandR : inutile de redemarrer X ou de
# toucher a xorg.conf. En revanche le serveur X ne recalcule PAS la matrice du
# tactile quand l'ecran tourne : sans la correction ci-dessous, le doigt tombe a
# cote en paysage (le pointeur part dans la mauvaise direction).
#
# usage : orientation.sh [paysage|portrait|bascule|etat]

set -u
OUT=${OUT:-None-1}
export DISPLAY=${DISPLAY:-:0}

M_NORMAL="1 0 0 0 1 0 0 0 1"
M_LEFT="0 -1 1 1 0 0 0 0 1"
M_RIGHT="0 1 0 -1 0 1 0 0 1"
M_INVERTED="-1 0 1 0 -1 1 0 0 1"

usage() {
	cat <<'EOF'
usage : orientation.sh [paysage|portrait|bascule|sync|etat]

  paysage   1280x800, rotation a gauche
  portrait   800x1280, orientation native
  bascule    inverse l'orientation courante (defaut)
  sync       reapplique la matrice du tactile sans tourner l'ecran
  etat       affiche l'orientation, la taille et la matrice du tactile
EOF
}

# Ligne de sortie de xrandr pour notre sortie, par exemple :
#   None-1 connected primary 1280x800+0+0 left (normal left inverted right ...)
ligne_sortie() {
	xrandr --query 2>/dev/null | grep "^$OUT " | head -1
}

# Rotation actuelle = dernier mot avant la parenthese.
# (Attention : la parenthese commence par la LISTE "normal left inverted right",
# d'ou l'extraction avant elle.)
etat_courant() {
	ligne_sortie | sed 's/ (.*//' | awk '{print $NF}'
}

taille_courante() {
	ligne_sortie | awk '{print $4}' | cut -d+ -f1
}

# Identifiants des peripheriques tactiles (le Synaptics s5707 de la tablette).
# Le peripherique peut s'appeler "syna_...", "Synaptics ...", "rmi4_...",
# "s5707", ou simplement "touchscreen" selon la version du pilote : on accepte
# tous ces noms plutot qu'un seul (un grep trop etroit laissait le tactile
# non corrige alors que le peripherique existait).
ids_tactile() {
	command -v xinput >/dev/null 2>&1 || return 0
	xinput list --short 2>/dev/null |
		grep -i 'syna\|synaptics\|touchscreen\|touch screen\|rmi4\|s5707' |
		sed -n 's/.*id=\([0-9][0-9]*\).*/\1/p'
}

# Le noyau sonde le RMI4 apres le demarrage de X : au moment ou .xinitrc appelle
# orientation.sh, le peripherique existe parfois deja (cas normal) et parfois
# pas encore. On attend donc son apparition jusqu'a 30 s avant d'abandonner.
attendre_tactile() {
	_n=0
	while [ "$_n" -lt 30 ]; do
		[ -n "$(ids_tactile)" ] && return 0
		sleep 1
		_n=$((_n + 1))
	done
	return 1
}

matrice_courante() {
	id=$(ids_tactile | head -1)
	[ -n "$id" ] || { echo "inconnu (xinput absent)"; return 0; }
	xinput list-props "$id" 2>/dev/null |
		sed -n 's/.*Coordinate Transformation Matrix ([0-9]*):[[:space:]]*/ /p' |
		head -1
}

# Journal : sans lui, un echec de calibration etait invisible (silence total,
# l'ecran tourne mais le doigt tombe a cote).
journal() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>/var/log/orientation.log 2>/dev/null; }

regler_tactile() { # $1 = matrice "a b c d e f g h i"
	command -v xinput >/dev/null 2>&1 || {
		msg="xinput absent : le tactile ne suivra pas la rotation (apk add xinput)"
		echo "note : $msg" >&2
		journal "$msg"
		return 1
	}
	_ok=1
	for id in $(ids_tactile); do
		# shellcheck disable=SC2086
		xinput set-prop "$id" "Coordinate Transformation Matrix" $1 \
			>/dev/null 2>&1 \
			&& { journal "matrice [$1] appliquee a l'id $id"; _ok=0; } \
			|| journal "ECHEC matrice sur l'id $id"
	done
	return "$_ok"
}

# Si le clavier virtuel est affiche, il doit suivre la nouvelle geometrie
# (sinon il reste au milieu de l'ecran, ce qui donne l'impression qu'il "devient
# fou"). On ne le lance pas ici : on le replace seulement s'il tourne deja.
redocker_clavier() {
	[ -x /usr/local/bin/dock-keyboard.sh ] || return 0
	pgrep -f matchbox-keyboard >/dev/null 2>&1 || return 0
	/usr/local/bin/dock-keyboard.sh 6 >/dev/null 2>&1 || true
}

# Matrice du tactile qui correspond a une rotation.
matrice_pour() {
	case $1 in
	normal)   echo "$M_NORMAL" ;;
	left)     echo "$M_LEFT" ;;
	right)    echo "$M_RIGHT" ;;
	inverted) echo "$M_INVERTED" ;;
	*)        echo "$M_NORMAL" ;;
	esac
}

# Reapplique la matrice correspondant a la rotation courante, sans tourner
# l'ecran. Utile au demarrage de X (la matrice n'est pas memorisee) et apres
# un rebranchement du peripherique tactile.
# Boucle de securite appelee en tache de fond par .xinitrc : si le peripherique
# tactile apparait apres le demarrage de X, la matrice finit par etre appliquee.
surveiller() {
	_n=0
	while [ "$_n" -lt 12 ]; do
		_cur=$(etat_courant)
		if [ -n "$_cur" ] && [ "$_cur" != normal ] && [ -n "$(ids_tactile)" ]; then
			regler_tactile "$(matrice_pour "$_cur")"
			journal "surveillance : matrice reappliquee ($_cur)"
			return 0
		fi
		sleep 5
		_n=$((_n + 1))
	done
	journal "surveillance : tactile toujours absent apres 60 s"
	return 1
}

synchroniser() {
	cur=$(etat_courant)
	[ -n "$cur" ] || {
		echo "echec : X ne repond pas" >&2
		return 1
	}
	regler_tactile "$(matrice_pour "$cur")"
	printf 'orientation : %s (matrice du tactile reappliquee)\n' "$cur"
}

# Le gestionnaire de fenetres replace la barre de taches et les fenetres
# maximisees sur la nouvelle geometrie. ATTENTION : "icewm --restart" lance un
# IceWM s'il n'y en a pas deja un, et icewm-session refuse alors de demarrer
# ("un gestionnaire de fenetres est deja en cours") : la session X meurt. On ne
# redemarre donc le WM que s'il tourne vraiment, ce qui est le cas quand
# .xinitrc appelle le paysage avant de lancer icewm-session.
redemarrer_wm() {
	command -v pgrep >/dev/null 2>&1 || return 0
	pgrep -x icewm >/dev/null 2>&1 || return 0
	icewm --restart >/dev/null 2>&1 &
}

appliquer() { # $1 = normal|left|right|inverted
	mat=$(matrice_pour "$1")
	case $1 in
	normal|left|right|inverted) ;;
	*) echo "rotation inconnue : $1" >&2; return 2 ;;
	esac

	# REGLE ABSOLUE : sans xinput on ne sait pas recaler la matrice du tactile,
	# et un ecran tourne avec un tactile non recale rend la tablette
	# inutilisable (doigt a cote : constate a l'ecran le 21/10/2026). On refuse
	# donc de tourner, et on le dit dans le journal.
	if [ "$1" != normal ] && ! command -v xinput >/dev/null 2>&1; then
		msg="rotation $1 refusee : xinput absent, le tactile resterait decale"
		echo "$msg" >&2
		journal "$msg"
		return 3
	fi

	if ! xrandr --output "$OUT" --rotate "$1" >/dev/null 2>&1; then
		echo "echec : xrandr ne peut pas tourner $OUT (X est-il demarre ?)" >&2
		journal "xrandr a echoue pour la rotation $1"
		return 1
	fi

	# Le noyau sonde le RMI4 parfois apres le demarrage de X : on attend le
	# peripherique avant d'appliquer la matrice, sinon la correction est perdue.
	if [ "$1" != normal ]; then
		if ! { attendre_tactile && regler_tactile "$mat"; }; then
			# Dernier filet : ecran tourne + tactile non recale = tablette
			# inutilisable. On REVIENT en portrait, ou le tactile est juste
			# sans aucune matrice. Mieux vaut un ecran etroit qu'un ecran mort.
			journal "tactile non recale : retour force en portrait"
			echo "tactile non recale, retour en portrait" >&2
			xrandr --output "$OUT" --rotate normal >/dev/null 2>&1
			regler_tactile "$M_NORMAL"
			redemarrer_wm
			return 4
		fi
	else
		regler_tactile "$mat"
	fi

	redemarrer_wm
	( sleep 2; redocker_clavier ) &

	return 0
}

case ${1:-bascule} in
paysage)
	appliquer left
	;;
portrait)
	appliquer normal
	;;
bascule|toggle)
	cur=$(etat_courant)
	case $cur in
	left|right|inverted) appliquer normal ;;
	*)                   appliquer left ;;
	esac
	;;
etat|state)
	printf 'orientation : %s\n' "$(etat_courant)"
	printf 'taille      : %s\n' "$(taille_courante)"
	printf 'tactile     :%s\n' "$(matrice_courante)"
	;;
sync|synchroniser|matrice)
	synchroniser
	;;
surveille|surveiller)
	surveiller
	;;
-h|--help|aide|help)
	usage
	;;
*)
	usage >&2
	exit 2
	;;
esac
