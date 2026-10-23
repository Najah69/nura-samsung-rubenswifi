#!/bin/sh
#  maj-energie.sh : installe la gestion de l'ecran, du bouton marche, de la
#  luminosite et de la batterie sur une tablette Nura deja installee, sans
#  reflashage ni redemarrage.
#
#      sudo sh maj-energie.sh
#
#  - service nura-energie (ecran eteint apres inactivite, Power = eteindre /
#    rallumer l'ecran, Vol Haut / Vol Bas = luminosite, icone de batterie,
#    alerte et arret propre quand la batterie est presque vide) ;
#  - systemd-logind : un appui court sur Power n'eteint plus la tablette,
#    l'appui long (5 s) fait un arret propre ;
#  - luminosite.sh et entrees du menu Ecran.
#
#  Ne touche ni au noyau, ni au demarrage (/boot), ni aux comptes, ni au
#  Wi-Fi. Rejouable. Les fichiers remplaces sont gardes en .avant-energie.
#  Il faut Internet pour installer xprintidle, yad et xmessage.
#  A lancer depuis le dossier inject/ du depot.
set -u

SRC=$(dirname "$(readlink -f "$0")")
SUF=.avant-energie

if [ "$(id -u)" != 0 ]; then
	echo "A lancer en root :  sudo sh maj-energie.sh" >&2
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
	cp -f "$SRC/$1" "$2" && chmod "$3" "$2" && chown root:root "$2"
	echo "  ok  $2"
}

echo "== 1. paquets =="
if apk add --no-cache xprintidle yad xmessage adwaita-icon-theme i2c-tools python3-tkinter tk >/dev/null 2>&1; then
	echo "  ok  xprintidle, yad, xmessage, adwaita-icon-theme, i2c-tools, python3-tkinter"
else
	echo "  !! apk add a echoue (Internet ?) : l'extinction automatique et l'icone" >&2
	echo "     de batterie ne marcheront pas ; sans i2c-tools, la luminosite non plus." >&2
fi

echo "== 2. fichiers =="
pose usr/local/bin/nura-energie                       /usr/local/bin/nura-energie 755
pose usr/local/bin/luminosite.sh                      /usr/local/bin/luminosite.sh 755
pose usr/local/bin/nura-osd                           /usr/local/bin/nura-osd 755
# Touches Android (Accueil, Menu, Retour) : raccourcis IceWM. X tourne en root
# et lit /root/.icewm ; la copie de /home/najah sert de modele.
pose home/najah/.icewm/keys                           /root/.icewm/keys 644
if [ -d /home/najah/.icewm ]; then
	pose home/najah/.icewm/keys                   /home/najah/.icewm/keys 644
	chown najah:najah /home/najah/.icewm/keys 2>/dev/null
fi
pose etc/systemd/system/nura-energie.service          /etc/systemd/system/nura-energie.service 644
pose etc/systemd/logind.conf.d/50-nura-bouton-marche.conf /etc/systemd/logind.conf.d/50-nura-bouton-marche.conf 644
if [ -f /etc/nura/energie.conf ]; then
	echo "  ok  /etc/nura/energie.conf conserve (reglages existants)"
else
	pose etc/nura/energie.conf                    /etc/nura/energie.conf 644
fi

echo "== 3. bouton marche (systemd-logind) =="
systemctl kill -s HUP systemd-logind.service 2>/dev/null
sleep 1
etat=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
	org.freedesktop.login1.Manager HandlePowerKey 2>/dev/null)
case "$etat" in
*ignore*) echo "  ok  appui court ignore par logind, appui long = arret" ;;
*)
	systemctl restart systemd-logind.service
	sleep 2
	etat=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
		org.freedesktop.login1.Manager HandlePowerKey 2>/dev/null)
	echo "  ..  logind relance : HandlePowerKey = ${etat:-inconnu}"
	;;
esac

echo "== 4. menu Ecran =="
for MENU in /root/.icewm/menu /home/najah/.icewm/menu; do
	[ -f "$MENU" ] || continue
	if grep -q 'luminosite.sh' "$MENU"; then
		echo "  ok  $MENU deja a jour"
		continue
	fi
	[ -f "$MENU$SUF" ] || cp -a "$MENU" "$MENU$SUF"
	awk '{ print }
	/prog "Etat de l.ecran"/ {
		print "\tprog \"Eteindre l'"'"'ecran (Power pour rallumer)\" folder systemctl kill -s USR1 nura-energie.service"
		print "\tprog \"Luminosite +\" folder /usr/local/bin/luminosite.sh plus"
		print "\tprog \"Luminosite -\" folder /usr/local/bin/luminosite.sh moins"
		print "\tprog \"Luminosite 25 %\" folder /usr/local/bin/luminosite.sh 25%"
		print "\tprog \"Luminosite 50 %\" folder /usr/local/bin/luminosite.sh 50%"
		print "\tprog \"Luminosite 100 %\" folder /usr/local/bin/luminosite.sh 100%"
	}' "$MENU$SUF" > "$MENU.tmp" && mv "$MENU.tmp" "$MENU"
	echo "  ok  $MENU (6 entrees dans Ecran)"
done
[ -x /usr/bin/icewm ] && DISPLAY=:0 HOME=/root /usr/bin/icewm --restart >/dev/null 2>&1 && echo "  ok  IceWM relance"

echo "== 5. service =="
systemctl daemon-reload
systemctl enable nura-energie.service >/dev/null 2>&1
systemctl restart nura-energie.service
sleep 3
echo "  nura-energie : $(systemctl is-active nura-energie.service)"
journalctl -u nura-energie.service -b --no-pager -n 3 -o cat 2>/dev/null | sed 's/^/  /'

echo "== termine =="
echo "   Appui court sur Power : eteindre / rallumer l'ecran ; appui long (5 s) : arret."
echo "   Vol Haut / Vol Bas : luminosite. Accueil : bureau ; Menu : menu ; Retour : page precedente."
echo "   Reglages : /etc/nura/energie.conf"
