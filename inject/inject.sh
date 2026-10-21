#!/bin/bash
# Injecte la configuration X/IceWM/clavier/VNC/Wi-Fi et les comptes dans l'image
# postmarketOS de la Galaxy Tab Active 8.0 (samsung-rubenswifi).
# A lancer sous WSL, en root, APRES "pmbootstrap install".
set -uo pipefail

IMG=/home/najah/.local/var/pmbootstrap/chroot_native/home/pmos/rootfs/samsung-rubenswifi.img
SRC=$(dirname "$(readlink -f "$0")")
M=/mnt/t360root
NAJAH_UID=10000

ok()   { printf '  [ok]   %s\n' "$*"; }
warn() { printf '  [!!]   %s\n' "$*"; }

[ -f "$IMG" ] || { echo "image absente : $IMG"; exit 1; }
mkdir -p "$M"
L=$(losetup -fP --show "$IMG") || { echo "losetup impossible"; exit 1; }
trap 'umount $M 2>/dev/null; losetup -d $L 2>/dev/null' EXIT
mount "${L}p2" "$M" || { echo "montage impossible"; exit 1; }
echo "=== image montee : $IMG ==="

# ---------------------------------------------------------------- fichiers
install_file() { # source relative, destination relative, mode
	local s="$SRC/$1" d="$M/$2"
	[ -f "$s" ] || { warn "source absente : $1"; return 1; }
	mkdir -p "$(dirname "$d")"
	cp "$s" "$d" && chmod "$3" "$d" && ok "$2 ($3)" || warn "copie ratee : $2"
}

# Active une unite systemd en lisant son WantedBy (pas de systemctl hors chroot).
# Les unites ecrites dans /etc/systemd/system sont liees en relatif, celles des
# paquets (/usr/lib, /lib) en absolu vers le chemin interne de l'image.
enable_unit() { # nom-de-unite [cible-par-defaut]
	local unit=$1 def=${2:-multi-user.target} path="" link targets t
	for path in "$M/etc/systemd/system/$unit" \
	            "$M/usr/lib/systemd/system/$unit" \
	            "$M/lib/systemd/system/$unit"; do
		[ -f "$path" ] && break
		path=""
	done
	[ -n "$path" ] || { warn "unite introuvable : $unit"; return 1; }
	case "$path" in
	"$M/etc/systemd/system/"*) link="../$unit" ;;
	*)                         link=${path#"$M"} ;;
	esac
	targets=$(awk -F= '/^WantedBy=/{print $2}' "$path" | tr -d '\r')
	[ -n "$targets" ] || targets=$def
	for t in $targets; do
		mkdir -p "$M/etc/systemd/system/$t.wants"
		ln -sf "$link" "$M/etc/systemd/system/$t.wants/$unit"
	done
	ok "active : $unit -> $targets"
}

echo "--- binaires et scripts ---"
install_file usr/local/bin/x11-run.sh       usr/local/bin/x11-run.sh       755
install_file usr/local/bin/dock-keyboard.sh usr/local/bin/dock-keyboard.sh 755
install_file usr/local/bin/x11-diag.sh      usr/local/bin/x11-diag.sh      755
install_file usr/local/bin/wifi.sh          usr/local/bin/wifi.sh          755
install_file usr/local/bin/wifi-dhcp.sh     usr/local/bin/wifi-dhcp.sh     755
install_file etc/wpa_supplicant/wpa_supplicant-wlan0.conf \
            etc/wpa_supplicant/wpa_supplicant-wlan0.conf 600
install_file etc/NetworkManager/conf.d/99-wlan-unmanaged.conf \
            etc/NetworkManager/conf.d/99-wlan-unmanaged.conf 644
install_file usr/local/bin/usb-gadget.sh    usr/local/bin/usb-gadget.sh    755
install_file usr/local/bin/load-wcnss-fw.sh usr/local/bin/load-wcnss-fw.sh 755
install_file etc/modprobe.d/zz-wcnss.conf   etc/modprobe.d/zz-wcnss.conf   644
# Pare-feu : sans ce fichier, le port 5900 de x11vnc est bloque a l'entree.
install_file etc/nftables.d/50_vnc.nft      etc/nftables.d/50_vnc.nft      644
# Bascule portrait / paysage (commande + icone de la barre des taches).
install_file usr/local/bin/orientation.sh   usr/local/bin/orientation.sh   755
# Clavier virtuel a la demande (icone de la barre des taches).
install_file usr/local/bin/keyboard.sh      usr/local/bin/keyboard.sh      755

# --- v2 : assistant de configuration et services associes ---
install_file usr/local/bin/nura-config      usr/local/bin/nura-config      755
install_file usr/local/bin/nura-assistant   usr/local/bin/nura-assistant   755
install_file usr/local/bin/automount.sh     usr/local/bin/automount.sh     755
install_file usr/local/bin/reseau-usb.sh    usr/local/bin/reseau-usb.sh    755
install_file usr/local/bin/batterie.sh      usr/local/bin/batterie.sh      755
# Navigateurs : netsurf par defaut, firefox en secours sur les sites modernes.
install_file usr/local/bin/navigateur.sh    usr/local/bin/navigateur.sh    755
# Trouve le fichier d'authentification reel du serveur X : sans lui, x11vnc
# ecoute sur 5900 sans jamais obtenir l'ecran (voir l'unite x11vnc.service).
install_file usr/local/bin/x11vnc-start.sh  usr/local/bin/x11vnc-start.sh  755
install_file etc/udev/rules.d/70-nura-automount.rules \
            etc/udev/rules.d/70-nura-automount.rules 644
mkdir -p "$M/etc/nura" "$M/etc/nura/wifi" "$M/media" "$M/var/lib/nura" "$M/var/log"
# Ne pas ecraser des reglages deja faits par l'utilisateur.
if [ -f "$M/etc/nura/assistant.conf" ]; then
	ok "etc/nura/assistant.conf conserve (reglages existants)"
else
	install_file etc/nura/assistant.conf etc/nura/assistant.conf 644
fi
chmod 755 "$M/media" "$M/var/lib/nura"
mkdir -p "$M/usr/share/pixmaps"
install_file usr/share/pixmaps/orientation.png  usr/share/pixmaps/orientation.png  644
install_file usr/share/pixmaps/orientation48.png usr/share/pixmaps/orientation48.png 644
install_file usr/share/pixmaps/keyboard.png     usr/share/pixmaps/keyboard.png     644
install_file usr/share/pixmaps/keyboard48.png   usr/share/pixmaps/keyboard48.png   644
# Le XPM est le format que la barre des taches d'IceWM lit toujours.
install_file usr/share/pixmaps/orientation.xpm  usr/share/pixmaps/orientation.xpm  644
install_file usr/share/pixmaps/keyboard.xpm     usr/share/pixmaps/keyboard.xpm     644

echo "--- unites systemd fournies ---"
install_file etc/systemd/system/x11-icewm.service   etc/systemd/system/x11-icewm.service   644
install_file etc/systemd/system/usb-gadget.service  etc/systemd/system/usb-gadget.service  644
install_file etc/systemd/system/x11vnc.service      etc/systemd/system/x11vnc.service      644
install_file etc/systemd/system/wcnss-firmware.service etc/systemd/system/wcnss-firmware.service 644
install_file etc/systemd/system/wpa-wlan0.service      etc/systemd/system/wpa-wlan0.service      644
install_file etc/systemd/system/wifi-dhcp.service      etc/systemd/system/wifi-dhcp.service      644
install_file etc/modules-load.d/usb-gadget.conf     etc/modules-load.d/usb-gadget.conf     644
mkdir -p "$M/root/.vnc"
chmod 700 "$M/root/.vnc"

echo "--- activation ---"
enable_unit x11-icewm.service
enable_unit usb-gadget.service
enable_unit x11vnc.service
enable_unit sshd.service
enable_unit NetworkManager.service
enable_unit msm-firmware-loader.service sysinit.target
enable_unit wcnss-firmware.service sysinit.target
# Console serie sur la fonction ACM du gadget (secours si RNDIS echoue).
mkdir -p "$M/etc/systemd/system/getty.target.wants"
if [ -f "$M/usr/lib/systemd/system/serial-getty@.service" ] ||
   [ -f "$M/lib/systemd/system/serial-getty@.service" ]; then
	ln -sf /usr/lib/systemd/system/serial-getty@.service \
		"$M/etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service"
	ok "active : serial-getty@ttyGS0"
else
	warn "serial-getty@.service introuvable"
fi
# tty1 est reserve a la session X.
mkdir -p "$M/etc/systemd/system/getty.target.wants"
ln -sf /dev/null "$M/etc/systemd/system/getty.target.wants/getty@tty1.service"
ok "getty@tty1 masque"

# Wi-Fi : on ne passe plus par NetworkManager, qui gardait wlan0 a
# "indisponible" (GENERAL.STATE: 20) meme avec la carte et rfkill en etat.
# Deux services specialises :
#   - wpa-wlan0.service : wpa_supplicant en Type=simple, avec sa trace -dd ;
#   - wifi-dhcp.service : attend l'association puis lance udhcpc.
# Le supplicant D-Bus de NetworkManager est masque : sinon il demarre par
# activation D-Bus (sans -c, donc sans socket de controle) et se dispute wlan0.
# NetworkManager ignore de toute facon wlan0 (99-wlan-unmanaged.conf).
rm -f "$M/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service"
ln -sf /dev/null "$M/etc/systemd/system/wpa_supplicant.service"
if [ -L "$M/etc/systemd/system/wpa_supplicant.service" ]; then
	ok "wpa_supplicant.service (D-Bus) masque"
else
	warn "masquage de wpa_supplicant.service rate"
fi
# Retrait de la premiere version (script unique oneshot), remplacee.
rm -f "$M/etc/systemd/system/wifi-direct.service" \
      "$M/etc/systemd/system/multi-user.target.wants/wifi-direct.service" \
      "$M/usr/local/bin/wifi-direct.sh"
ok "ancienne unite wifi-direct retiree"
enable_unit wpa-wlan0.service
enable_unit wifi-dhcp.service

echo "--- espace disque dans l'image ---"
df -h "$M" | tail -1

echo "--- session X ---"
install_file home/najah/.xinitrc home/najah/.xinitrc 755
cp "$M/home/najah/.xinitrc" "$M/root/.xinitrc" && chmod 755 "$M/root/.xinitrc" && ok "root/.xinitrc"
chown -R $NAJAH_UID:$NAJAH_UID "$M/home/najah" 2>/dev/null

install_file home/najah/.icewm/preferences home/najah/.icewm/preferences 644
install_file home/najah/.icewm/menu        home/najah/.icewm/menu        644
mkdir -p "$M/root/.icewm"
cp "$SRC/home/najah/.icewm/preferences" "$M/root/.icewm/preferences"
chmod 644 "$M/root/.icewm/preferences"
ok "root/.icewm/preferences"
if [ -f "$SRC/home/najah/.icewm/menu" ]; then
	cp "$SRC/home/najah/.icewm/menu" "$M/root/.icewm/menu"
	chmod 644 "$M/root/.icewm/menu"
	ok "root/.icewm/menu"
fi
# Barre de lancement rapide : l'icone qui bascule l'ecran.
install_file home/najah/.icewm/toolbar home/najah/.icewm/toolbar 644
cp "$SRC/home/najah/.icewm/toolbar" "$M/root/.icewm/toolbar"
chmod 644 "$M/root/.icewm/toolbar"
ok "root/.icewm/toolbar"

echo "--- editeur et pager par defaut ---"
install_file etc/profile.d/editor.sh etc/profile.d/editor.sh 644

echo "--- Xorg ---"
for f in 20-fbdev.conf 30-touch.conf 99-keyboard.conf; do
	install_file "etc/X11/xorg.conf.d/$f" "etc/X11/xorg.conf.d/$f" 644
done
install_file etc/X11/xorg-modesetting.conf etc/X11/xorg-modesetting.conf 644
mkdir -p "$M/etc/X11/xorg-empty.conf.d"

# --------------------------------------------------------------- comptes
echo "--- comptes ---"
set_pw() { # utilisateur, mot de passe en clair
	local u=$1 p=$2 h
	h=$(openssl passwd -6 "$p") || { warn "openssl absent"; return 1; }
	if grep -q "^$u:" "$M/etc/shadow"; then
		awk -F: -v u="$u" -v h="$h" 'BEGIN{OFS=":"} { if ($1==u) $2=h; print }' \
			"$M/etc/shadow" >/tmp/shadow.new && cat /tmp/shadow.new >"$M/etc/shadow"
		ok "mot de passe de $u defini"
	else
		warn "utilisateur $u absent de /etc/shadow"
	fi
}
# root reste verrouille ("!" dans /etc/shadow) : c'est le defaut postmarketOS.
# Mot de passe des comptes crees ici : MOT_DE_PASSE=... sur la ligne de commande.
# Par defaut 147147, la valeur des images postmarketOS, que l'assistant demande
# de changer au premier demarrage.
set_pw najah "${MOT_DE_PASSE:-147147}"

if ! grep -q '^dsh:' "$M/etc/passwd"; then
	echo 'dsh:x:1001:1001:Compte de service:/home/dsh:/bin/ash' >>"$M/etc/passwd"
	echo 'dsh:x:1001:' >>"$M/etc/group"
	echo "dsh:$(openssl passwd -6 "${MOT_DE_PASSE:-147147}"):19000:0:99999:7:::" >>"$M/etc/shadow"
	mkdir -p "$M/home/dsh"
	chown 1001:1001 "$M/home/dsh"
	chmod 700 "$M/home/dsh"
	ok "compte dsh cree (uid 1001, /home/dsh)"
else
	ok "compte dsh deja present"
fi
chmod 600 "$M/etc/shadow"
chown 0:0 "$M/etc/shadow" "$M/etc/passwd" "$M/etc/group"

if [ -x "$M/usr/bin/sudo" ] || [ -x "$M/bin/sudo" ]; then
	mkdir -p "$M/etc/sudoers.d"
	echo 'dsh ALL=(ALL) NOPASSWD:ALL' >"$M/etc/sudoers.d/dsh"
	chmod 440 "$M/etc/sudoers.d/dsh"
	ok "sudo sans mot de passe pour dsh"
else
	warn "sudo absent de l'image"
fi

# ----------------------------------------------------------------- sshd
echo "--- ssh ---"
mkdir -p "$M/etc/ssh/sshd_config.d"
cat >"$M/etc/ssh/sshd_config.d/10-rubens.conf" <<'EOF'
# Galaxy Tab Active 8.0 : acces par mot de passe pour les comptes non-root.
# root reste verrouille (! dans /etc/shadow) : prohibit-password le refuse.
PasswordAuthentication yes
PermitRootLogin prohibit-password
PubkeyAuthentication yes
EOF
chmod 600 "$M/etc/ssh/sshd_config.d/10-rubens.conf"
SSHD="$M/etc/ssh/sshd_config"
if ! grep -q 'sshd_config.d' "$SSHD" 2>/dev/null; then
	{ echo 'Include /etc/ssh/sshd_config.d/*.conf'; echo; cat "$SSHD"; } >/tmp/sshd.new
	cat /tmp/sshd.new >"$SSHD"
	ok "Include ajoute en tete de sshd_config"
else
	ok "Include deja present"
fi

# --------------------------------------------------------- verification
echo
echo "--- shells interactifs : bash (busybox reste /bin/sh) ---"
# /bin et /sbin sont des liens ABSOLUS vers /usr/bin et /usr/sbin dans l'image :
# tester "$M/bin/bash" interrogerait l'hote. On teste donc les chemins reels.
chroot_bash=""
if [ -f "$M/usr/bin/bash" ] && [ ! -L "$M/usr/bin/bash" ]; then
	chroot_bash=/bin/bash
elif [ -f "$M/usr/sbin/bash" ] && [ ! -L "$M/usr/sbin/bash" ]; then
	chroot_bash=/usr/sbin/bash
fi
if [ -n "$chroot_bash" ]; then
	for u in root najah dsh; do
		sed -i "/^$u:/ s|:/bin/[a]*sh\$|:$chroot_bash|" "$M/etc/passwd"
	done
	# /bin/sh n'est PAS touche : tous les scripts POSIX restent sur busybox.
	ok "shells de connexion en $chroot_bash (/bin/sh -> busybox conserve)"
else
	warn "bash absent de l'image : shells de connexion inchanges"
fi

echo
echo "=== verification : binaires ==="
for t in usr/bin/nmcli usr/bin/nmtui usr/bin/x11vnc usr/bin/iw usr/sbin/wpa_supplicant \
         sbin/wpa_supplicant usr/bin/lsusb usr/bin/scrot usr/bin/xdotool usr/bin/xdpyinfo \
         usr/bin/xwininfo usr/bin/ssh usr/sbin/sshd usr/bin/tcpdump usr/bin/socat \
         usr/bin/nano usr/bin/mc usr/bin/mcedit usr/bin/xfe \
         usr/bin/bash usr/bin/rg usr/bin/fd usr/bin/git usr/bin/gcc usr/bin/make \
         usr/bin/pkg-config usr/bin/unzip usr/bin/zstd usr/bin/xz; do
	if [ -e "$M/$t" ]; then
		printf '  present  %-32s %s\n' "$t" "$(stat -c '%s o' "$M/$t")"
	else
		printf '  ABSENT   %s\n' "$t"
	fi
done

echo
echo "=== verification : unites activees ==="
for u in x11-icewm.service usb-gadget.service x11vnc.service NetworkManager.service \
         msm-firmware-loader.service wcnss-firmware.service wpa-wlan0.service \
         wifi-dhcp.service sshd.service serial-getty@ttyGS0.service; do
	found=$(find "$M/etc/systemd/system" -maxdepth 2 -name "$u" -type l 2>/dev/null | head -1)
	if [ -n "$found" ]; then printf '  ok       %s\n' "${found#"$M"}"
	else printf '  ABSENT   %s\n' "$u"; fi
done

echo
echo "=== verification : script du firmware WCNSS ==="
for t in usr/sbin/msm-firmware-loader.sh usr/lib/systemd/system/msm-firmware-loader.service; do
	[ -e "$M/$t" ] && ok "/$t" || warn "/$t absent"
done

echo
echo "=== verification : fichiers injectes ==="
for f in root/.xinitrc root/.icewm/preferences root/.icewm/menu home/najah/.icewm/menu \
         usr/local/bin/x11-diag.sh usr/local/bin/wifi.sh usr/local/bin/wifi-dhcp.sh \
         etc/wpa_supplicant/wpa_supplicant-wlan0.conf \
         etc/NetworkManager/conf.d/99-wlan-unmanaged.conf \
         etc/systemd/system/wpa-wlan0.service \
         etc/systemd/system/wifi-dhcp.service \
         etc/systemd/system/x11vnc.service \
         usr/local/bin/load-wcnss-fw.sh etc/systemd/system/wcnss-firmware.service \
         etc/modprobe.d/zz-wcnss.conf \
         etc/profile.d/editor.sh etc/ssh/sshd_config.d/10-rubens.conf; do
	if [ -e "$M/$f" ]; then
		printf '  present  %-46s %s\n' "$f" "$(stat -c '%s o, mode %a' "$M/$f")"
	else
		printf '  ABSENT   %s\n' "$f"
	fi
done

echo
echo "=== verification : comptes ==="
awk -F: '$1=="root"||$1=="najah"||$1=="dsh" {
	printf "    %-6s hash=%s... (%d champs)\n", $1, substr($2,1,10), NF }' "$M/etc/shadow"
for u in root najah dsh; do
	printf '    %-6s shell = %s\n' "$u" "$(awk -F: -v u="$u" '$1==u{print $7}' "$M/etc/passwd")"
done

echo
echo "=== verification : gestionnaires reseau ==="
for u in systemd-networkd.service wpa_supplicant.service iwd.service; do
	if [ -L "$M/etc/systemd/system/$u" ] && [ "$(readlink "$M/etc/systemd/system/$u")" = /dev/null ]; then
		printf '  MASQUE   %s\n' "$u"
	elif find "$M/etc/systemd/system" -maxdepth 2 -name "$u" -type l 2>/dev/null | grep -q .; then
		printf '  ACTIF    %s\n' "$u"
	else
		printf '  inactif  %s\n' "$u"
	fi
done

echo
echo "=== correctif DTB (Wi-Fi WCNSS et PHY USB) ==="
# A faire ici, et pas a la main : "pmbootstrap install" regenere le DTB depuis
# le paquet noyau, donc les corrections doivent etre reappliquees a chaque
# image. Le script monte la partition p1 (celle-ci est p2) et verifie tout
# avant d'ecrire. Sans lui : aucun Wi-Fi (remoteproc "disabled").
if [ -x "$SRC/wcnss-dtb.sh" ]; then
	bash "$SRC/wcnss-dtb.sh" "$IMG" || warn "correctif DTB en echec : Wi-Fi non fonctionnel"
else
	warn "wcnss-dtb.sh absent : le Wi-Fi ne demarrera pas"
fi

echo
echo "=== injection terminee ==="
