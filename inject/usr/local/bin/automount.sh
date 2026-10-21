#!/bin/sh
# automount.sh - montage automatique des cartes SD et des cles USB
# usage : automount.sh mount <peripherique> | umount <peripherique> | tout | etat
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
LOG=/var/log/nura-automount.log
CFG=/usr/local/bin/nura-config
MEDIA=/media

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG" 2>/dev/null; }

uid_user() {
	u=$($CFG get USER_LOGIN najah)
	id -u "$u" 2>/dev/null || echo 10000
}

point_de_montage() { # $1 = nom court du peripherique
	label=$(blkid -s LABEL -o value "/dev/$1" 2>/dev/null | tr -d '\r')
	[ -n "$label" ] || label=$1
	label=$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-32)
	[ -n "$label" ] || label=$1
	echo "$MEDIA/$label"
}

deja_monte() { # $1 = /dev/xxx -> point de montage sur stdout si monte
	awk -v d="/dev/$1" '$1 == d { print $2; exit }' /proc/mounts
}

monter() {
	dev=$1
	[ -n "$dev" ] || return 0
	[ -b "/dev/$dev" ] || return 0
	if [ "$($CFG get AUTOMOUNT)" != 1 ]; then
		log "monte ignore ($dev) : montage automatique desactive"
		return 0
	fi
	pt=$(deja_monte "$dev")
	[ -n "$pt" ] && return 0
	pt=$(point_de_montage "$dev")
	mkdir -p "$pt" || return 0
	u=$(uid_user)
	# vfat / exfat / ntfs : acces en ecriture pour l'utilisateur
	if mount -t vfat -o rw,noatime,uid="$u",gid="$u",umask=000 "/dev/$dev" "$pt" 2>/dev/null ||
	   mount -t exfat -o rw,noatime,uid="$u",gid="$u",umask=000 "/dev/$dev" "$pt" 2>/dev/null ||
	   mount -o rw,noatime "/dev/$dev" "$pt" 2>/dev/null; then
		chmod 777 "$pt" 2>/dev/null
		log "monte /dev/$dev -> $pt"
		# previent le bureau (IceWM n'ecoute pas, mais utile pour les outils)
		[ -x /usr/local/bin/notifier.sh ] && /usr/local/bin/notifier.sh "Support monte : $pt" >/dev/null 2>&1 &
	else
		log "echec du montage de /dev/$dev"
	fi
}

demonter() {
	dev=$1
	[ -n "$dev" ] || return 0
	pt=$(deja_monte "$dev")
	[ -n "$pt" ] || return 0
	if umount "$pt" 2>/dev/null; then
		rmdir "$pt" 2>/dev/null
		log "demonte $pt"
	else
		log "echec du demontage de $pt (occupe ?)"
	fi
}

tout() {
	for d in /dev/mmcblk1p* /dev/sd[b-z][0-9]*; do
		[ -b "$d" ] || continue
		monter "${d#/dev/}"
	done
}

etat() {
	awk '$2 ~ /^\/media\// { printf "%-18s %-28s %s\n", $1, $2, $3 }' /proc/mounts
}

case "${1:-}" in
mount)  monter "${2:-}" ;;
umount) demonter "${2:-}" ;;
tout)   tout ;;
etat)   etat ;;
*)
	echo "usage: automount.sh mount <dev> | umount <dev> | tout | etat" >&2
	exit 1
	;;
esac
