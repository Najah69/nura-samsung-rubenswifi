#!/bin/sh
# Installe le firmware WCNSS de la Galaxy Tab Active 8.0 (Wi-Fi).
#
# Historique des constats, pour ne pas refaire les memes hypotheses :
#  - les etiquettes GPT de cette tablette sont en minuscules (apnhlos, modem,
#    persist, system) ; le chargeur postmarketOS en monte donc bien certaines,
#    mais sa liste ne contient pas "system", ou se trouve justement la
#    calibration Wi-Fi (WCNSS_qcom_wlan_nv.bin) dont wcn36xx a besoin ;
#  - les blobs wcnss.* sont dans la partition APNHLOS, sous /image/ ;
#  - wcn36xx reclame "wlan/prima/WCNSS_qcom_wlan_nv.bin" et echoue si absent.
#
# Plutot que de deviner, ce script parcourt TOUTES les partitions montables,
# cherche tout ce qui ressemble a du firmware Wi-Fi et le depose aux deux
# endroits ou le noyau le cherche : le dossier pointe par firmware_class.path
# (celui du chargeur) et /lib/firmware.
set -u
TARGET=/run/msm-firmware-loader/target
WORK=/run/wcnss-fw
LOG=/run/wcnss-fw.log
mkdir -p "$TARGET/wlan/prima" "$WORK" /lib/firmware/wlan/prima

: >"$LOG"
log() { echo "$*" >>"$LOG"; echo "$*"; }

log "=== load-wcnss-fw $(date -Is) ==="

install_blob() { # $1 = fichier source, $2 = sous-dossier relatif (vide ou wlan/prima)
	src=$1
	sub=${2:-}
	b=$(basename "$src")
	cp -f "$src" /lib/firmware/"$sub"/"$b" 2>/dev/null || return 1
	mkdir -p "$TARGET/$sub"
	cp -f "$src" "$TARGET/$sub"/"$b" 2>/dev/null || true
	return 0
}

# Traite le contenu d'une arborescence deja montee.
harvest() { # $1 = point de montage, $2 = nom affiche
	mp=$1
	name=$2
	n=0
	# Blobs WCNSS et calibration Wi-Fi, ou qu'ils soient dans l'arborescence.
	for f in $(find "$mp" \( -iname 'wcnss*' -o -iname 'WCNSS_qcom*' \) -type f 2>/dev/null); do
		case "$(basename "$f")" in
		WCNSS_qcom_wlan_nv.bin)
			install_blob "$f" wlan/prima && {
				log "    + wlan/prima/$(basename "$f") ($(stat -c %s "$f") o) depuis ${f#"$mp"}"
				n=$((n + 1))
			}
			;;
		WCNSS_qcom_cfg.ini)
			install_blob "$f" wlan/prima && {
				log "    + wlan/prima/$(basename "$f") depuis ${f#"$mp"}"
				n=$((n + 1))
			}
			;;
		*)
			install_blob "$f" && {
				log "    + $(basename "$f") ($(stat -c %s "$f") o) depuis ${f#"$mp"}"
				n=$((n + 1))
			}
			;;
		esac
	done
	log "  $name : $n fichier(s) recupere(s)"
}

# 0. Le paquet firmware-samsung-rubenswifi-wcnss-nv fournit la calibration.
#    C'est desormais la source de verite : sur cette tablette le fichier vit
#    dans system/etc/firmware/wlan/prima/, que le chargeur ne monte pas.
FWPKG=/usr/lib/firmware/postmarketos/wlan/prima
if [ -d "$FWPKG" ]; then
	log "--- calibration fournie par le paquet ---"
	for f in "$FWPKG"/*; do
		[ -f "$f" ] || continue
		install_blob "$f" wlan/prima &&
			log "  + $(basename "$f") ($(stat -c %s "$f") o)"
	done
fi

# 1. Le chargeur postmarketOS a peut-etre deja monte des partitions : on
#    commence par ce qu'il a fait, sans remonter par-dessus.
log "--- deja monte par le chargeur ---"
if [ -d /run/msm-firmware-loader/mnt ]; then
	log "  dossier mnt : [$(ls /run/msm-firmware-loader/mnt 2>/dev/null | tr '\n' ' ')]"
	for d in /run/msm-firmware-loader/mnt/*; do
		[ -d "$d" ] || continue
		harvest "$d" "mnt/$(basename "$d")"
	done
else
	log "  le chargeur n'a rien monte"
fi

# 2. Puis TOUTES les partitions du disque interne, sauf USERDATA (notre propre
#    racine) et les partitions trop petites pour contenir un firmware.
log "--- partitions scannees ---"
SELF=$(findmnt -n -o SOURCE / 2>/dev/null)
for p in /sys/block/mmcblk*/mmcblk*p* /sys/block/sd*/sd*; do
	[ -e "$p/uevent" ] || continue
	dev=$(sed -n 's/^DEVNAME=//p' "$p/uevent")
	name=$(sed -n 's/^PARTNAME=//p' "$p/uevent")
	[ -n "$dev" ] || continue
	case "$name" in
	userdata|USERDATA|"") continue ;;
	esac
	# deja monte (par le chargeur ou par nous) ?
	if grep -qs "/dev/$dev " /proc/mounts; then
		mp=$(awk -v d="/dev/$dev" '$1==d{print $2; exit}' /proc/mounts)
		[ -n "$mp" ] && { log "  $name : deja monte sur $mp"; continue; }
	fi
	size=$(cat "$p/size" 2>/dev/null || echo 0)
	[ "$size" -gt 8192 ] 2>/dev/null || continue   # < 4 Mio : inutile
	mp="$WORK/$name"
	mkdir -p "$mp"
	if mount -o ro,nodev,noexec,nosuid "/dev/$dev" "$mp" 2>/dev/null; then
		harvest "$mp" "$name"
	else
		rmdir "$mp" 2>/dev/null
	fi
done

# 3. Le noyau accepte .mbn a la place de .mdt.
log "--- alias .mdt / .mbn ---"
for d in /lib/firmware "$TARGET"; do
	[ -f "$d/wcnss.mdt" ] && [ ! -e "$d/wcnss.mbn" ] && ln -sf wcnss.mdt "$d/wcnss.mbn"
	[ -f "$d/wcnss.mbn" ] && [ ! -e "$d/wcnss.mdt" ] && ln -sf wcnss.mbn "$d/wcnss.mdt"
done

# 4. Bilan
log "--- resultat ---"
if [ -f /lib/firmware/wcnss.mdt ]; then
	log "  wcnss.mdt present, $(ls /lib/firmware/wcnss.b* 2>/dev/null | wc -l) segment(s)"
else
	log "  [!!] wcnss.mdt INTROUVABLE"
fi
if [ -f /lib/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin ]; then
	log "  calibration presente ($(stat -c %s /lib/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin) o)"
else
	log "  [!!] WCNSS_qcom_wlan_nv.bin INTROUVABLE : wcn36xx refusera de demarrer"
fi
log "  path du noyau : $(cat /sys/module/firmware_class/parameters/path 2>/dev/null)"

# 5. Modules : charges seulement maintenant, apres le firmware
#    (zz-wcnss.conf les protege du chargement automatique par udev).
log "--- modules ---"
for m in qcom_wcnss_pil wcn36xx; do
	modprobe "$m" 2>>"$LOG" && log "  modprobe $m : ok" || log "  modprobe $m : ECHEC"
done

sleep 3

# 6. Si wlan0 n'apparait pas, une seconde tentative : le premier demarrage du
#    coeur WCNSS peut echouer avant que ses alimentations soient stables.
if [ ! -e /sys/class/net/wlan0 ]; then
	log "--- deuxieme tentative ---"
	modprobe -r wcn36xx 2>>"$LOG"
	modprobe -r qcom_wcnss_pil 2>>"$LOG"
	sleep 1
	modprobe qcom_wcnss_pil 2>>"$LOG" && log "  qcom_wcnss_pil recharge" || log "  qcom_wcnss_pil : ECHEC"
	sleep 2
	modprobe wcn36xx 2>>"$LOG" && log "  wcn36xx recharge" || log "  wcn36xx : ECHEC"
	sleep 3
fi

log "--- interfaces ---"
for i in /sys/class/net/*; do log "  $(basename "$i")"; done
log "--- noyau ---"
dmesg 2>/dev/null | grep -iE 'wcnss|wcn36|pronto|remoteproc' | tail -14 | cut -c1-100 >>"$LOG"

# 7. En cas d'echec : etat du coeur et des alimentations, pour le prochain diagnostic.
if [ ! -e /sys/class/net/wlan0 ]; then
	log "--- etat apres echec ---"
	log "  remoteproc0 : $(cat /sys/class/remoteproc/remoteproc0/state 2>&1)"
	mkdir -p /sys/kernel/debug
	mount -t debugfs none /sys/kernel/debug 2>/dev/null
	log "  --- alimentations ---"
	grep -E '(^|[[:space:]])(l3|l6|l10|l16|l24)([[:space:]]|$)' \
		/sys/kernel/debug/regulator/regulator_summary 2>/dev/null |
		head -12 | cut -c1-96 >>"$LOG"
	log "  --- domaines ---"
	grep -iE 'wcnss|fb204000|VDDCX|VDDMX' /sys/kernel/debug/pm_genpd/pm_genpd_summary 2>/dev/null |
		head -6 | cut -c1-96 >>"$LOG"
fi

log "=== fin ==="
exit 0
