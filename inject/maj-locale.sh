#!/bin/sh
#  maj-locale.sh : applique les correctifs de la 1.0.1 a une tablette Nura
#  deja installee, sans reflashage. Aucun compte, aucun mot de passe, aucun
#  reglage Wi-Fi n'est touche.
#
#      sudo sh maj-locale.sh
#
#  A lancer depuis le dossier inject/ du depot (le script lit les fichiers
#  autour de lui). Les fichiers remplaces sont gardes en .avant-1.0.1.
set -u

SRC=$(dirname "$(readlink -f "$0")")
SUF=.avant-1.0.1
OK=0
MANQUE=0

if [ "$(id -u)" != 0 ]; then
	echo "A lancer en root :  sudo sh maj-locale.sh" >&2
	exit 1
fi

pose() { # $1 source relative au payload, $2 destination, $3 mode
	src="$SRC/$1"
	dst="$2"
	if [ ! -f "$src" ]; then
		printf '  --  %s (absent du payload)\n' "$1"
		MANQUE=$((MANQUE + 1))
		return 0
	fi
	if [ -f "$dst" ] && [ ! -f "$dst$SUF" ]; then
		cp -a "$dst" "$dst$SUF" 2>/dev/null || true
	fi
	mkdir -p "$(dirname "$dst")" 2>/dev/null || true
	if cp -f "$src" "$dst" 2>/dev/null && chmod "$3" "$dst" 2>/dev/null; then
		printf '  ok  %s\n' "$dst"
		OK=$((OK + 1))
	else
		printf '  !!  echec : %s\n' "$dst"
	fi
}

echo "== correctifs 1.0.1 appliques a cette tablette =="

echo "-- clavier tactile surveille par systemd"
pose usr/local/bin/clavier-virtuel.sh /usr/local/bin/clavier-virtuel.sh 755
pose usr/local/bin/keyboard.sh /usr/local/bin/keyboard.sh 755
pose usr/local/bin/dock-keyboard.sh /usr/local/bin/dock-keyboard.sh 755
pose etc/systemd/system/clavier-virtuel.service /etc/systemd/system/clavier-virtuel.service 644

echo "-- racine ext4 agrandie au demarrage"
pose usr/local/bin/grandit-racine.sh /usr/local/bin/grandit-racine.sh 755
pose etc/systemd/system/nura-grandit-racine.service /etc/systemd/system/nura-grandit-racine.service 644

echo "-- apparence : menu, barre, fond"
pose home/najah/.icewm/menu /root/.icewm/menu 644
pose home/najah/.icewm/toolbar /root/.icewm/toolbar 644
pose home/najah/.icewm/preferences /root/.icewm/preferences 644
pose usr/share/pixmaps/fond-nura.png /usr/share/pixmaps/fond-nura.png 644

echo "-- mise en service"
systemctl daemon-reload 2>/dev/null || true
if systemctl enable nura-grandit-racine.service >/dev/null 2>&1; then
	echo "  ok  nura-grandit-racine.service activee (verifie la place a chaque demarrage)"
fi
if systemctl start nura-grandit-racine.service >/dev/null 2>&1; then
	echo "  ok  racine verifiee maintenant (journal : /var/log/nura-grandit.log)"
fi
if systemctl enable clavier-virtuel.service >/dev/null 2>&1; then
	echo "  ok  clavier-virtuel.service activee"
fi
if systemctl restart clavier-virtuel.service >/dev/null 2>&1; then
	echo "  ok  clavier (re)lance par systemd"
fi

sleep 5
if pgrep -f matchbox-keyboard >/dev/null 2>&1; then
	echo "  ok  matchbox-keyboard tourne"
else
	echo "  ..  matchbox-keyboard pas encore visible ; voir /var/log/clavier-virtuel.log"
fi

if [ -x /usr/bin/icewm ]; then
	if DISPLAY=:0 /usr/bin/icewm --restart >/dev/null 2>&1; then
		echo "  ok  IceWM relance : le menu et la barre sont a jour"
	fi
fi

echo "== termine : $OK fichier(s) pose(s), $MANQUE absent(s) du payload =="
echo "   Redemarrage conseille : sudo reboot"