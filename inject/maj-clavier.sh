#!/bin/sh
#  maj-clavier.sh : corrige la taille des fenetres sur une tablette Nura deja
#  installee, sans reflashage.
#
#      sudo sh maj-clavier.sh
#
#  Le clavier virtuel annoncait a IceWM une reserve d'espace (_NET_WM_STRUT) de
#  ~534 px en bas de l'ecran, alors qu'il n'en occupe que 266. IceWM ne laissait
#  donc qu'une zone utile de ~236 px : toute fenetre ouverte s'affichait a 245 px
#  de haut, collee en bas (kitty en 25x25 pixels, Claude Code tronque...).
#
#  Ce script remplace dock-keyboard.sh par la version qui retire cette reserve.
#  Il ne touche ni aux comptes, ni aux mots de passe, ni au Wi-Fi. Rejouable.
#
#  A lancer depuis le dossier inject/ du depot (le script lit les fichiers
#  autour de lui). Le fichier remplace est garde en .avant-strut.
set -u

SRC=$(dirname "$(readlink -f "$0")")
SUF=.avant-strut
DOCK=/usr/local/bin/dock-keyboard.sh

if [ "$(id -u)" != 0 ]; then
	echo "A lancer en root :  sudo sh maj-clavier.sh" >&2
	exit 1
fi

echo "== correction de la taille des fenetres =="

if [ ! -f "$SRC/usr/local/bin/dock-keyboard.sh" ]; then
	echo "  !! usr/local/bin/dock-keyboard.sh absent : lancer ce script depuis inject/" >&2
	exit 1
fi

if [ -f "$DOCK" ] && [ ! -f "$DOCK$SUF" ]; then
	cp -a "$DOCK" "$DOCK$SUF" 2>/dev/null || true
fi
if cp -f "$SRC/usr/local/bin/dock-keyboard.sh" "$DOCK" && chmod 755 "$DOCK"; then
	echo "  ok  $DOCK remplace (ancien garde en $DOCK$SUF)"
else
	echo "  !! echec de la copie vers $DOCK" >&2
	exit 1
fi

echo "-- clavier relance avec la correction"
if systemctl restart clavier-virtuel.service >/dev/null 2>&1; then
	echo "  ok  clavier-virtuel.service relance"
else
	echo "  ..  clavier non relance ; relancer a la main : systemctl restart clavier-virtuel"
fi

sleep 6

if DISPLAY=:0 xprop -name Keyboard _NET_WM_STRUT_PARTIAL 2>/dev/null | grep -q CARDINAL; then
	echo "  ..  la reserve d'espace est encore annoncee ; voir /var/log/clavier-virtuel.log"
else
	echo "  ok  plus de reserve d'espace : les fenetres peuvent occuper tout l'ecran"
fi

echo "== termine =="
echo "   Ouvrir une fenetre pour verifier : elle doit prendre la hauteur demandee."
