#!/bin/sh
#  maj-bluetooth.sh : installe le son par Bluetooth (enceinte, casque) sur une
#  tablette Nura deja installee, sans reflashage ni redemarrage.
#
#      sudo sh maj-bluetooth.sh
#
#  - BlueZ (service bluetooth, adaptateur allume au demarrage) ;
#  - PipeWire + WirePlumber + pipewire-pulse pour root, qui fait tourner le
#    bureau : leurs unites refusent root par defaut (ConditionUser=!root) et
#    WirePlumber n'active le Bluetooth que pour un siege logind actif ;
#  - icone Bluetooth (blueman-applet) au demarrage d'IceWM, menu Son.
#
#  Le micro d'une enceinte ou d'un casque (mode mains libres) ne marche PAS :
#  la puce envoie la voix vers le processeur audio, pas vers Linux.
#
#  Ne touche ni au noyau, ni au demarrage (/boot), ni aux comptes, ni au
#  Wi-Fi. Rejouable. Les fichiers remplaces sont gardes en .avant-bluetooth.
#  Il faut Internet pour installer les paquets.
#  A lancer depuis le dossier inject/ du depot.
set -u

SRC=$(dirname "$(readlink -f "$0")")
SUF=.avant-bluetooth

if [ "$(id -u)" != 0 ]; then
	echo "A lancer en root :  sudo sh maj-bluetooth.sh" >&2
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
if apk add --no-cache bluez bluez-btmon pipewire wireplumber pipewire-pulse \
	pipewire-spa-bluez pipewire-alsa blueman pavucontrol >/dev/null 2>&1; then
	echo "  ok  bluez, pipewire-pulse, pipewire-spa-bluez, blueman, pavucontrol"
else
	echo "  !! apk add a echoue (Internet ?) : rien d'autre ne sera fait" >&2
	exit 1
fi

echo "== 2. fichiers =="
for u in pipewire.socket pipewire.service pipewire-pulse.socket pipewire-pulse.service wireplumber.service; do
	pose etc/systemd/user/$u.d/50-nura-root.conf /etc/systemd/user/$u.d/50-nura-root.conf 644
done
pose etc/wireplumber/wireplumber.conf.d/50-nura-bluetooth.conf \
	/etc/wireplumber/wireplumber.conf.d/50-nura-bluetooth.conf 644
pose etc/systemd/system/x11-icewm.service.d/50-nura-son.conf \
	/etc/systemd/system/x11-icewm.service.d/50-nura-son.conf 644
# X tourne en root et lit /root/.icewm ; la copie de /home/najah sert de modele.
pose home/najah/.icewm/startup /root/.icewm/startup 755
if [ -d /home/najah/.icewm ]; then
	pose home/najah/.icewm/startup /home/najah/.icewm/startup 755
	chown najah:najah /home/najah/.icewm/startup 2>/dev/null
fi

echo "== 3. adaptateur allume au demarrage =="
B=/etc/bluetooth/main.conf
if [ -f $B ]; then
	[ -f $B$SUF ] || cp -a $B $B$SUF
	if grep -q '^#\?AutoEnable=' $B; then
		sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' $B
	else
		printf '\n[Policy]\nAutoEnable=true\n' >> $B
	fi
	echo "  ok  $B : $(grep '^AutoEnable' $B)"
fi

echo "== 4. menu Son =="
for MENU in /root/.icewm/menu /home/najah/.icewm/menu; do
	[ -f "$MENU" ] || continue
	if grep -q 'blueman-manager' "$MENU"; then
		echo "  ok  $MENU deja a jour"
		continue
	fi
	[ -f "$MENU$SUF" ] || cp -a "$MENU" "$MENU$SUF"
	awk '/^menu "Ecran"/ {
		print "menu \"Son\" folder {"
		print "\tprog \"Bluetooth : appairer une enceinte\" folder blueman-manager"
		print "\tprog \"Volume et sortie du son\" folder pavucontrol"
		print "}"
		print ""
	}
	{ print }' "$MENU$SUF" > "$MENU.tmp" && mv "$MENU.tmp" "$MENU"
	echo "  ok  $MENU (menu Son)"
done

echo "== 5. services =="
systemctl daemon-reload
systemctl enable --now bluetooth.service >/dev/null 2>&1
echo "  bluetooth : $(systemctl is-active bluetooth.service)"
# Gestionnaire utilisateur de root lance au demarrage, sans connexion.
loginctl enable-linger root
i=0
while [ $i -lt 20 ] && [ "$(systemctl is-active user@0.service)" != active ]; do sleep 1; i=$((i+1)); done
U="systemctl --user -M root@.host"
$U daemon-reload
$U start pipewire.socket pipewire-pulse.socket wireplumber.service
sleep 3
for s in pipewire wireplumber; do echo "  $s : $($U is-active $s)"; done
if ! pgrep -x blueman-applet >/dev/null; then
	DISPLAY=:0 HOME=/root XDG_RUNTIME_DIR=/run/user/0 \
		DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus \
		setsid blueman-applet >/dev/null 2>&1 </dev/null &
fi
[ -x /usr/bin/icewm ] && DISPLAY=:0 HOME=/root /usr/bin/icewm --restart >/dev/null 2>&1 && echo "  ok  IceWM relance"

echo "== termine =="
echo "   Icone Bluetooth dans la barre des taches : Rechercher, puis choisir l'enceinte"
echo "   (en mode appairage). Menu Son : appairer, volume et sortie du son."
echo "   Au prochain demarrage, toutes les applications trouvent le serveur de son."
echo "   Le micro Bluetooth (mains libres) ne fonctionne pas sur cette tablette."
