#!/bin/sh
# Demarre x11vnc avec le fichier d'authentification REELLEMENT utilise par X.
#
# Pourquoi pas un chemin fixe : startx/xinit lance Xorg avec un fichier
# temporaire, par exemple
#     /usr/libexec/Xorg :0 vt1 ... -auth /root/.serverauth.1770
# Un chemin fixe (/root/.Xauthority) ne contient alors pas le bon cookie :
# x11vnc ecoutait sur 5900 mais n'obtenait jamais l'ecran ("Authorization
# required"). L'option -auth guess de x11vnc echoue ici (elle a besoin de
# HOME et ne retrouve pas le fichier). On lit donc l'argument -auth dans la
# ligne de commande du serveur X, ce qui marche quel que soit son nom.
set -u
export HOME=/root

AUTH=""
for p in /proc/[0-9]*; do
	[ -r "$p/cmdline" ] || continue
	c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
	case "$c" in
	*Xorg* | */usr/libexec/X* | *"/usr/bin/X "* | *"/usr/bin/Xorg "*) ;;
	*) continue ;;
	esac
	case "$c" in
	*" -auth "*) ;;
	*) continue ;;
	esac
	AUTH=$(printf '%s' "$c" | sed -n 's/.* -auth \([^ ]*\).*/\1/p' | head -1)
	[ -n "$AUTH" ] && break
done

[ -n "$AUTH" ] || AUTH=/root/.Xauthority
[ -r "$AUTH" ] || { echo "x11vnc-start : fichier d'auth illisible ($AUTH)" >&2; }
echo "x11vnc-start : auth = $AUTH" >&2

exec /usr/bin/x11vnc -display :0 -auth "$AUTH" \
	-forever -shared -rfbport 5900 -rfbauth /root/.vnc/passwd \
	-noxdamage -repeat -desktop rubenswifi
