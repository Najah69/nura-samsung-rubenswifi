#!/bin/sh
#  maj-interface.sh : rend l'interface utilisable au doigt sur une tablette Nura
#  deja installee, sans reflashage ni redemarrage.
#
#      sudo sh maj-interface.sh
#
#  - theme IceWM « Nura » : barres de titre de 40 px, boutons de fenetre de
#    40 x 40 px contrastes (fermer en rouge) ;
#  - prefoverride : icones de 32 px dans la barre et les menus, polices
#    agrandies. Ce fichier est lu APRES le theme, seul moyen d'imposer la
#    hauteur des barres de titre ; les anciens noms d'options de preferences
#    (IconSize, TaskBarFontName...) sont ignores par IceWM 4.
#
#  Ne touche ni au noyau, ni au demarrage, ni aux comptes. Rejouable. Les
#  fichiers remplaces sont gardes en .avant-tactile. A lancer depuis inject/.
set -u

SRC=$(dirname "$(readlink -f "$0")")
SUF=.avant-tactile

if [ "$(id -u)" != 0 ]; then
	echo "A lancer en root :  sudo sh maj-interface.sh" >&2
	exit 1
fi

pose() { # source-relative destination mode
	if [ ! -f "$SRC/$1" ]; then
		echo "  !! $1 absent : lancer ce script depuis inject/" >&2
		exit 1
	fi
	mkdir -p "$(dirname "$2")"
	if [ -f "$2" ] && ! cmp -s "$SRC/$1" "$2" && [ ! -f "$2$SUF" ]; then
		cp -a "$2" "$2$SUF"
	fi
	cp -f "$SRC/$1" "$2" && chmod "$3" "$2"
	echo "  ok  $2"
}

echo "== 1. theme Nura =="
for f in "$SRC"/usr/share/icewm/themes/Nura/*; do
	pose "usr/share/icewm/themes/Nura/${f##*/}" "/usr/share/icewm/themes/Nura/${f##*/}" 644 >/dev/null
done
chmod 755 /usr/share/icewm/themes/Nura
echo "  ok  /usr/share/icewm/themes/Nura ($(ls /usr/share/icewm/themes/Nura | wc -l) fichiers)"

echo "== 2. tailles et choix du theme =="
for D in /root/.icewm /home/najah/.icewm; do
	[ -d "$D" ] || continue
	pose home/najah/.icewm/prefoverride "$D/prefoverride" 644
	pose home/najah/.icewm/theme        "$D/theme"        644
	[ "$D" = /home/najah/.icewm ] && chown najah:najah "$D/prefoverride" "$D/theme" 2>/dev/null
done

echo "== 3. IceWM =="
if [ -x /usr/bin/icewm ] && DISPLAY=:0 HOME=/root /usr/bin/icewm --restart >/dev/null 2>&1; then
	echo "  ok  IceWM relance"
else
	echo "  ..  IceWM non relance : les tailles s'appliqueront au prochain demarrage"
fi
echo "== termine =="
echo "   Retour en arriere : remettre les fichiers .avant-tactile (s'ils existent) ou"
echo "   supprimer /root/.icewm/prefoverride et /root/.icewm/theme, puis icewm --restart."
