#!/bin/sh
# Session X de la Galaxy Tab Active 8.0 (samsung-rubenswifi) - v2
# Les reglages viennent de /etc/nura/assistant.conf (voir nura-config).
# Au premier demarrage, l'assistant Nura se lance par-dessus le bureau.

CFG=/usr/local/bin/nura-config
[ -x "$CFG" ] || CFG=/bin/false

xset s off
xset s noblank
xset -dpms
xrdb -merge /etc/X11/Xresources 2>/dev/null

# Langue du clavier. 99-keyboard.conf (ecrit par l'assistant) suffit au serveur
# X ; setxkbmap n'existe pas dans cette image, on ne l'appelle que s'il est la.
KB=$($CFG get KB_LAYOUT)
if [ -n "$KB" ] && command -v setxkbmap >/dev/null 2>&1; then
	setxkbmap "$KB" 2>/dev/null
fi

# La rotation n'est pas memorisee par le serveur X : il demarre toujours en
# portrait (800x1280). On applique l'orientation choisie, puis on recale la
# matrice du tactile en consequence.
ORIENT=$($CFG get ORIENTATION)
[ -n "$ORIENT" ] || ORIENT=portrait

# GARDE-FOU (21/10/2026 : premiere image v2 livree avec un ecran en paysage et
# un tactile qui tombait a cote, donc inutilisable). Sans xinput, impossible de
# recaler la matrice du Synaptics : on reste alors en PORTRAIT, qui est le
# repere natif du tactile et ou le doigt tombe juste sans rien appliquer.
if [ "$ORIENT" != portrait ] && ! command -v xinput >/dev/null 2>&1; then
	printf '%s xinput absent : portrait impose pour garder le tactile juste\n' \
		"$(date '+%F %T')" >>/var/log/orientation.log 2>/dev/null
	ORIENT=portrait
fi

/usr/local/bin/orientation.sh "$ORIENT" >/dev/null 2>&1

# Le peripherique tactile peut apparaitre apres X : une boucle de fond
# reapplique la matrice des qu'il existe (et se tait au bout d'une minute).
/usr/local/bin/orientation.sh surveiller >/dev/null 2>&1 &

# Clavier tactile : il est porte par clavier-virtuel.service, demarre avec la
# session et relance tout seul s'il meurt. Rien a faire ici : l'ancien appel
# apres un « sleep 6 » arrivait parfois avant IceWM et laissait le clavier mal
# ancre. Le reglage CLAVIER de l'assistant est lu par le service.

# Premier demarrage : assistant de configuration, par-dessus le bureau.
if [ ! -f /var/lib/nura/assistant.done ] && [ -x /usr/local/bin/nura-assistant ]; then
	( sleep 4; /usr/local/bin/nura-assistant ) >/dev/null 2>&1 &
fi

# Reseau par cable USB si demande
[ "$($CFG get RESEAU_USB)" = 1 ] && /usr/local/bin/reseau-usb.sh up >/dev/null 2>&1

# Supports deja branches (carte SD restee dans son logement)
[ "$($CFG get AUTOMOUNT)" = 1 ] && /usr/local/bin/automount.sh tout >/dev/null 2>&1

exec icewm-session
