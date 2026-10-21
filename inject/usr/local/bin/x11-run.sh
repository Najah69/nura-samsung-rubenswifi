#!/bin/sh
# Lancement de la session X sur la Galaxy Tab Active 8.0 (samsung-rubenswifi).
# Appelé par /etc/systemd/system/x11-icewm.service sur tty1.
# Écrit son journal dans /tmp/x11-boot.log et publie ses rapports
# (x11-state.txt, xorg-diag.txt, dock-report.txt) vers /boot puis la carte SD.

LOG=/tmp/x11-boot.log
: > "$LOG"
log() { echo "$*" >> "$LOG"; }
exec >>"$LOG" 2>&1

SDMSG="pas de carte SD"
BOOTMSG="pas de /boot inscriptible"

# --------------------------------------------------------------------------
# publish FICHIER : copie vers /boot/<nom>, puis vers une carte microSD FAT.
# Ne touche jamais aux partitions eMMC.
# --------------------------------------------------------------------------
publish() {
	src=$1
	[ -f "$src" ] || return 0
	name=$(basename "$src")
	if [ -d /boot ] && [ -w /boot ]; then
		if cp "$src" "/boot/$name" 2>/dev/null; then
			sync
			BOOTMSG="/boot/$name"
		else
			BOOTMSG="copie /boot impossible"
		fi
	fi
	for part in /dev/mmcblk1p1 /dev/mmcblk1p2; do
		[ -b "$part" ] || continue
		d="/run/sd-$(basename "$part")"
		mkdir -p "$d" || continue
		mounted=no
		for fs in vfat exfat; do
			if mount -t "$fs" "$part" "$d" 2>/dev/null; then
				mounted=yes
				break
			fi
		done
		[ "$mounted" = yes ] || continue
		if cp "$src" "$d/$name" 2>/dev/null; then
			sync
			SDMSG="SD $part/$name"
		else
			SDMSG="SD $part refus d'ecriture"
		fi
		umount "$d" 2>/dev/null
		break
	done
}

# --------------------------------------------------------------------------
# Le noyau expose le framebuffer sous /dev/graphics/fb0 sur cette tablette.
# --------------------------------------------------------------------------
if [ ! -e /dev/fb0 ] && [ -e /dev/graphics/fb0 ]; then
	ln -s /dev/graphics/fb0 /dev/fb0
	log "fb0 : lien cree depuis /dev/graphics/fb0"
fi
log "fb0 : $(ls -l /dev/fb0 2>/dev/null)"
log "proc/fb : $(tr '\n' ' ' < /proc/fb 2>/dev/null)"
for f in virtual_size stride bits_per_pixel; do
	log "fb0/$f = $(cat /sys/class/graphics/fb0/$f 2>/dev/null)"
done

# --------------------------------------------------------------------------
# Rapport complet, utilisable sans photographier l'écran.
# --------------------------------------------------------------------------
build_diag() {
	{
		echo "=== framebuffer ==="
		echo "proc/fb : $(tr '\n' ' ' < /proc/fb 2>/dev/null)"
		for f in virtual_size stride bits_per_pixel; do
			printf 'fb0/%s = %s\n' "$f" "$(cat /sys/class/graphics/fb0/$f 2>/dev/null)"
		done
		echo
		echo "=== Xorg (lignes utiles) ==="
		grep -aE 'Virtual screen|\(EE\)|Fatal|Using fbdev|depth [0-9]+|Depth' \
			/var/log/Xorg.0.log 2>/dev/null | tail -20
		echo
		echo "=== taille de l'ecran X ==="
		DISPLAY=:0 xdpyinfo 2>/dev/null | grep -E 'dimensions|depth of root|number of screens'
		echo
		echo "=== fenetres ==="
		DISPLAY=:0 xwininfo -root -children 2>/dev/null | grep -aE 'matchbox|icewm|xterm' | head -20
		echo
		echo "=== processus ==="
		ps -o pid,args 2>/dev/null | grep -E 'Xorg|icewm|matchbox|xterm' | grep -v grep
	} >/tmp/xorg-diag.txt 2>&1
	publish /tmp/xorg-diag.txt
	publish /var/log/Xorg.0.log
}

# --------------------------------------------------------------------------
# Surveillance : 25 s après le lancement, on fige l'état sur disque.
# --------------------------------------------------------------------------
watchdog() {
	sleep 25
	{
		echo "=== etat a 25 s ==="
		ps -o pid,args 2>/dev/null | grep -E 'Xorg|icewm|matchbox|xterm|startx' | grep -v grep
		echo
		echo "=== erreurs Xorg ==="
		grep -aE '\(EE\)' /var/log/Xorg.0.log 2>/dev/null | head -20
		echo
		echo "=== taille de l'ecran X ==="
		DISPLAY=:0 xdpyinfo 2>/dev/null | grep -E 'dimensions|depth of root'
		echo
		echo "=== fenetres ==="
		DISPLAY=:0 xwininfo -root -children 2>/dev/null | head -30
		echo
		echo "=== rapport du clavier ==="
		cat /tmp/dock-report.txt 2>/dev/null
	} >/tmp/x11-state.txt 2>&1
	publish /tmp/x11-state.txt
	publish /tmp/dock-report.txt
	publish /tmp/dock-keyboard.log
}

# --------------------------------------------------------------------------
# Écran de secours si X ne démarre pas : on reprend la console texte.
# --------------------------------------------------------------------------
to_text_mode_and_dump() {
	for vc in /sys/class/vtconsole/vtcon*; do
		[ -w "$vc/bind" ] || continue
		echo 0 >"$vc/bind" 2>/dev/null
		echo 1 >"$vc/bind" 2>/dev/null
	done
	clear
	{
		echo "##### X n'a pas demarre #####"
		echo "##### SD : $SDMSG | BOOT : $BOOTMSG #####"
		echo
		head -74 /tmp/xorg-diag.txt 2>/dev/null
	} >/dev/tty1
	sleep 600
}

# --------------------------------------------------------------------------
# Lancement
# --------------------------------------------------------------------------
watchdog &
build_diag >/dev/null 2>&1 &
sleep 2

# Le pilote fbdev ne peut pas s'initialiser sur ce noyau : simpledrm expose un
# framebuffer sans memoire mappable (smem_len = 0), d'ou « AddScreen/ScreenInit
# failed for driver 0 ». C'est le pilote modesetting, sur le meme /dev/dri/card0,
# qui fonctionne (et c'est lui qui donne l'ecran « None-1 » et la rotation RandR).
# On l'essaie donc en premier ; fbdev ne reste qu'en secours.
# -configdir evite de relire /etc/X11/xorg.conf.d/20-fbdev.conf, qui declare un
# second ecran du meme nom : il serait en conflit avec xorg-modesetting.conf.
log "--- startx (modesetting sur simpledrm) ---"
startx /root/.xinitrc -- :0 vt1 -config /etc/X11/xorg-modesetting.conf \
	-configdir /etc/X11/xorg-empty.conf.d
RC=$?
log "startx modesetting : code $RC"

# X a-t-il vécu ? Si oui, le diagnostic est déjà bon.
build_diag

if [ "$RC" -ne 0 ]; then
	log "--- deuxieme essai : fbdev ---"
	startx /root/.xinitrc -- :0 vt1
	RC=$?
	log "startx fbdev : code $RC"
fi

if [ "$RC" -ne 0 ]; then
	log "--- dernier recours : Xorg seul ---"
	Xorg :1 vt2 -config /etc/X11/xorg.conf.d/20-fbdev.conf -logfile /dev/stdout 2>&1 |
		grep -aE '\(EE\)|\(WW\)|Fatal|Screen|depth|bpp|FBDEV|ABI' |
		head -40 >>"$LOG"
fi

build_diag
to_text_mode_and_dump
