#!/bin/bash
#  prepare-image-publique.sh — fabrique l'image publiable a partir d'une image
#  de travail, en retirant tout ce qui est personnel.
#
#  usage : prepare-image-publique.sh <image source> <image destination> [inject/]
#
#  Ce qui est retire :
#    - le reseau Wi-Fi enregistre (nom + empreinte PSK : une empreinte WPA
#      connue avec son SSID se casse hors ligne par dictionnaire) ;
#    - les reseaux memorises par l'assistant (/etc/nura/wifi) ;
#    - les mots de passe de l'auteur (comptes et VNC) ;
#    - les cles SSH, historiques de shell et journaux de la machine de l'auteur.
#
#  Aucune modification n'est faite dans l'image source : on travaille sur copie.
set -euo pipefail

SRC=${1:?usage : prepare-image-publique.sh <source.img> <destination.img> [inject/]}
DST=${2:?usage : prepare-image-publique.sh <source.img> <destination.img> [inject/]}
PAYLOAD=${3:-}
M=/mnt/pub

[ -f "$SRC" ] || { echo "source absente : $SRC"; exit 1; }
[ -f "$DST" ] && { echo "destination deja presente : $DST"; exit 1; }

echo "== copie (c'est long : 1,8 Go) =="
cp --reflink=auto "$SRC" "$DST"
chmod u+w "$DST"

echo "== montage =="
L=$(losetup -fP --show "$DST")
mkdir -p "$M"
nettoyer() {
	sync
	umount "$M" 2>/dev/null || true
	losetup -d "$L" 2>/dev/null || true
}
trap nettoyer EXIT
mount "${L}p2" "$M"

echo "== Wi-Fi : remplacement par un modele vierge =="
cat >"$M/etc/wpa_supplicant/wpa_supplicant-wlan0.conf" <<'EOF'
# Aucun reseau enregistre : c'est l'assistant, au premier demarrage, qui
# enregistre le Wi-Fi (mot de passe stocke hache par wpa_passphrase).
# Voir aussi : wifi.sh scan | wifi.sh connect SSID MOTDEPASSE
ctrl_interface=/run/wpa_supplicant
update_config=0
EOF
chmod 600 "$M/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
chown 0:0 "$M/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"

echo "== description du service : plus de nom de reseau =="
sed -i 's/^Description=.*/Description=wpa_supplicant pour wlan0/' \
	"$M/etc/systemd/system/wpa-wlan0.service"

echo "== reseaux memorises par l'assistant =="
rm -f "$M"/etc/nura/wifi/*.conf 2>/dev/null || true

# Le nom du reseau de l'auteur trainait encore dans deux commentaires de
# wifi-dhcp.sh (le script, lui, est generique), et deux fichiers de service
# gagnent a porter exactement la version du depot. Si le dossier inject/ est
# fourni en 3e argument, toute la charge utile est reprise de la-bas : l'image
# publiee et le depot restent ainsi identiques, octet pour octet.
echo "== charge utile : version du depot =="
if [ -n "${PAYLOAD:-}" ] && [ -d "$PAYLOAD" ]; then
	n=0
	while IFS= read -r f; do
		rel=${f#"$PAYLOAD/"}
		case "$rel" in inject.sh | wcnss-dtb.sh | outils/*) continue ;; esac
		[ -e "$M/$rel" ] || continue # fichier propre a l'image : on n'ajoute rien
		install -m "$(stat -c %a "$f")" "$f" "$M/$rel"
		n=$((n + 1))
	done < <(find "$PAYLOAD" -type f)
	echo "  [ok] $n fichiers repris de $PAYLOAD"
	grep -c . "$M/usr/local/bin/wifi-dhcp.sh" >/dev/null && echo "  [ok] wifi-dhcp.sh"
	# Les droits ne survivent pas au passage par Windows : on les remet.
	chmod 600 "$M/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
	chmod 755 "$M"/usr/local/bin/*.sh "$M"/usr/local/bin/nura-* 2>/dev/null || true
	chmod 644 "$M"/etc/systemd/system/*.service "$M"/etc/nftables.d/*.nft 2>/dev/null || true
else
	echo "  (pas de dossier inject fourni : image laissee telle quelle)"
fi

echo "== traces personnelles =="
rm -f "$M/var/lib/nura/assistant.done"
rm -rf "$M/root/.vnc" "$M/root/.ssh" "$M/root/.Xauthority"
rm -f "$M"/root/.serverauth.* "$M"/root/.bash_history "$M"/root/.python_history
rm -f "$M"/home/*/.bash_history "$M"/home/*/.python_history "$M"/home/*/.Xauthority
rm -rf "$M"/home/*/.ssh "$M"/home/*/.vnc
rm -f "$M"/var/log/nura-*.log "$M"/var/log/orientation.log
rm -f "$M"/var/log/nura-dnsmasq.log "$M"/var/log/usb-gadget.log
rm -rf "$M"/var/lib/nura/* 2>/dev/null || true

echo "== reglages de l'assistant : valeurs d'usine =="
if [ -f "$M/etc/nura/assistant.conf" ]; then
	sed -i -e 's/^NOM=.*/NOM=rubenswifi/' \
	       -e 's/^ORIENTATION=.*/ORIENTATION=portrait/' \
	       -e 's/^ASSISTANT_DONE=.*/ASSISTANT_DONE=0/' \
	       "$M/etc/nura/assistant.conf"
fi

# Les mots de passe de l'auteur (comptes + VNC) ne doivent pas partir avec
# l'image. On met celui des images postmarketOS (147147) : l'assistant demande
# d'en choisir un autre au premier demarrage, et le README le dit noir sur blanc.
echo "== mots de passe : valeur par defaut postmarketOS =="
H=$(openssl passwd -6 -salt nurav1 147147)
for u in najah dsh; do
	if grep -q "^$u:" "$M/etc/shadow" 2>/dev/null; then
		sed -i "s|^$u:[^:]*:|$u:$H:|" "$M/etc/shadow"
		echo "  [ok] $u"
	fi
done
if [ -f "$M/etc/systemd/system/x11vnc.service" ]; then
	sed -i 's/-storepasswd [^ ]*/-storepasswd 147147/' \
		"$M/etc/systemd/system/x11vnc.service"
	echo "  [ok] mot de passe VNC"
fi

echo "== verification avant demontage =="
fuite=0
# Invariants d'une image publiable. Les chaines personnelles de l'auteur ne sont
# pas codees ici (ce serait les publier) : passez-les par MOTIFS="mot1 mot2".
if grep -qE '^[[:space:]]*(psk|password)=' "$M/etc/wpa_supplicant/wpa_supplicant-wlan0.conf" 2>/dev/null; then
	echo "  ATTENTION : un reseau est encore enregistre dans le fichier Wi-Fi"; fuite=1
else
	echo "  [ok] aucun reseau enregistre"
fi
if grep -rqs '#psk="' "$M/etc" 2>/dev/null; then
	echo "  ATTENTION : un mot de passe Wi-Fi est present en clair"; fuite=1
else
	echo "  [ok] aucun mot de passe en clair"
fi
for motif in ${MOTIFS:-}; do
	if grep -rl "$motif" "$M/etc" "$M/usr/local" "$M/root" "$M/home" "$M/var" 2>/dev/null | grep -q .; then
		echo "  ATTENTION : '$motif' est encore present :"
		grep -rl "$motif" "$M/etc" "$M/usr/local" "$M/root" "$M/home" "$M/var" 2>/dev/null | sed 's/^/    /'
		fuite=1
	else
		echo "  [ok] aucun '$motif'"
	fi
done
[ -z "${MOTIFS:-}" ] && echo "  (MOTIFS vide : seuls les invariants sont verifies)"
[ -z "$(ls -A "$M/var/lib/nura" 2>/dev/null)" ] && echo "  [ok] /var/lib/nura vide"
if [ -f "$M/etc/shadow" ]; then
	anciens=$(grep -c -E '^(najah|dsh):\$6\$' "$M/etc/shadow" 2>/dev/null || true)
	nouveaux=$(grep -c -E '^(najah|dsh):\$6\$nurav1\$' "$M/etc/shadow" 2>/dev/null || true)
	echo "  comptes avec mot de passe : $anciens (dont $nouveaux a la valeur par defaut)"
	[ "$anciens" = "$nouveaux" ] || fuite=1
fi
grep -q 'storepasswd 147147' "$M/etc/systemd/system/x11vnc.service" 2>/dev/null &&
	echo "  [ok] mot de passe VNC par defaut" || fuite=1
[ "$fuite" = 0 ] || { echo "  >>> FUITE DETECTEE : image non publiee"; exit 1; }

nettoyer
trap - EXIT

echo "== empreinte =="
sha256sum "$DST"
ls -l --time-style=+%Y-%m-%d_%H:%M "$DST"
echo "=== TERMINE ==="
