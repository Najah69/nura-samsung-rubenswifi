#!/bin/sh
# grandit-racine.sh - agrandit le systeme de fichiers racine a la taille de sa
# partition.
#
# Sur cette tablette la racine n'est pas une partition directe : l'initramfs
# monte l'image disque posee sur /dev/mmcblk0p26, ce qui donne /dev/loop0p1
# (/boot) et /dev/loop0p2 (/). L'initramfs agrandit bien la partition loop, mais
# rien n'agrandit l'ext4 : la racine reste bloquee a ~1,2 Go sur les ~11 Go
# disponibles, et "apk add" finit par echouer faute de place.
#
# Appele a chaque demarrage par nura-grandit-racine.service. resize2fs travaille
# en ligne (la racine reste montee) et ne fait rien si le systeme de fichiers
# occupe deja toute la partition : l'appel est sans danger et repetable.

set -u

LOG=/var/log/nura-grandit.log
mkdir -p "$(dirname "$LOG")" 2>/dev/null

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null; }

# 1. Quelle est la source montee sur / ?
ROOT=$(findmnt -no SOURCE / 2>/dev/null)
[ -n "$ROOT" ] || ROOT=$(awk '$2 == "/" { print $1 }' /proc/mounts 2>/dev/null)
# /proc/mounts affiche parfois /dev/root : on prefere le nom reel.
if [ "$ROOT" = "/dev/root" ] || [ -z "$ROOT" ]; then
	ROOT=$(readlink -f /dev/root 2>/dev/null)
fi

if [ -z "$ROOT" ]; then
	log "racine introuvable, rien a faire"
	exit 0
fi
if [ ! -b "$ROOT" ]; then
	log "racine $ROOT : pas un peripherique bloc (overlay ?), rien a faire"
	exit 0
fi
if ! command -v resize2fs >/dev/null 2>&1; then
	log "resize2fs absent (e2fsprogs non installe ?), rien a faire"
	exit 0
fi

total() { df -k / 2>/dev/null | awk 'NR == 2 { print $2 }'; }

avant=$(total)
log "racine $ROOT : ${avant:-?} Ko avant"

essai=0
apres=""
while [ "$essai" -lt 3 ]; do
	essai=$((essai + 1))
	sortie=$(resize2fs "$ROOT" 2>&1)
	printf '  %s\n' "$sortie" >>"$LOG" 2>/dev/null
	apres=$(total)
	if [ -n "$avant" ] && [ -n "$apres" ] && [ "$apres" -gt "$avant" ]; then
		log "agrandi : $avant -> $apres Ko"
		exit 0
	fi
	# Au tout premier demarrage la partition peut grandir apres nous.
	[ "$essai" -lt 3 ] && sleep 5
done

log "inchange : ${apres:-?} Ko (partition deja pleine, ou pas encore agrandie)"
exit 0