#!/bin/bash
# Applique au DTB de l'image les correctifs materiels propres a la Galaxy Tab
# Active 8.0 (APQ8026 + WCN3660A), tous mesures en v1 puis repris ici :
#
#   USB    : suppression du reset "por" fantome du PHY (sinon "not attached")
#   WCNSS  : remoteproc + wcnss passes a "okay"        (coeur pronto + canal SMD)
#   WCNSS  : firmware-name = "wcnss.mdt"               (nom reel des blobs Samsung)
#   WCNSS  : vddmx<-l3 vddpx<-l6, iris vddxo<-l10 vddrfa/vdddig<-l24 vddpa<-l16
#   WCNSS  : pinctrl wcnss-pin-a sur gpio40..44, fonction "wlan"
#
# usage : bash wcnss-dtb.sh [image.img]
# Sans argument : l'image de travail pmbootstrap. A lancer en root, sous WSL,
# APRES "pmbootstrap install" (l'installation reecrit le DTB).
# Idempotent : relance sans risque, les corrections deja en place sont signalees.
set -uo pipefail

IMG=${1:-/home/najah/.local/var/pmbootstrap/chroot_native/home/pmos/rootfs/samsung-rubenswifi.img}
SRC=$(dirname "$(readlink -f "$0")")
PY="$SRC/outils"
B=/mnt/t360boot
NOM=qcom-apq8026-samsung-rubenswifi.dtb
W=/tmp/wcnss-dtb

ok()   { printf '  [ok]   %s\n' "$*"; }
bad()  { printf '  [!!]   %s\n' "$*"; }

[ -f "$IMG" ] || { echo "image absente : $IMG"; exit 1; }
command -v dtc     >/dev/null || { echo "dtc manquant"; exit 1; }
command -v python3 >/dev/null || { echo "python3 manquant"; exit 1; }
for s in prep-dts.py add-wcnss-fwname.py fix-wcnss-real.py; do
	[ -f "$PY/$s" ] || { echo "outil manquant : $PY/$s"; exit 1; }
done

mkdir -p "$B" "$W"
L=$(losetup -fP --show "$IMG") || { echo "losetup impossible"; exit 1; }
trap 'umount "$B" 2>/dev/null; losetup -d "$L" 2>/dev/null' EXIT
mount "${L}p1" "$B" || { echo "montage p1 impossible"; exit 1; }
DTB="$B/$NOM"
[ -f "$DTB" ] || { echo "DTB introuvable : $DTB"; exit 1; }

echo "=== DTB de l'image : $DTB ==="
echo "  taille avant : $(stat -c %s "$DTB") octets"

echo
echo "--- 1. decomposition ---"
dtc -I dtb -O dts -o "$W/in.dts" "$DTB" 2>/dev/null || { echo "dtc a echoue"; exit 1; }
cp -f "$DTB" "$W/avant.dtb"
echo "  $W/in.dts : $(wc -l < "$W/in.dts") lignes"

echo
echo "--- 2. reset USB et activation du coeur WCNSS ---"
python3 "$PY/prep-dts.py" "$W/in.dts" "$W/a.dts" || { echo "prep-dts a echoue"; exit 1; }

echo
echo "--- 3. nom du firmware WCNSS ---"
python3 "$PY/add-wcnss-fwname.py" "$W/a.dts" "$W/b.dts" || { echo "fwname a echoue"; exit 1; }

echo
echo "--- 4. alimentations pm8226 et pinctrl WLAN ---"
python3 "$PY/fix-wcnss-real.py" "$W/b.dts" "$W/c.dts" || { echo "supplies a echoue"; exit 1; }

echo
echo "--- 5. compilation ---"
if ! dtc -I dts -O dtb -o "$W/out.dtb" "$W/c.dts" 2>"$W/dtc.err"; then
	echo "  dtc a echoue :"; sed 's/^/    /' "$W/dtc.err"; exit 1
fi
if grep -q 'ERROR' "$W/dtc.err"; then
	echo "  erreurs dtc :"; grep ERROR "$W/dtc.err" | sed 's/^/    /'; exit 1
fi
ok "compile : $(stat -c %s "$W/out.dtb") octets (avant $(stat -c %s "$W/avant.dtb"))"

echo
echo "--- 6. controle du DTB produit (lecture independante) ---"
dtc -I dtb -O dts "$W/out.dtb" 2>/dev/null > "$W/verif.dts"
fail=0
present() { if grep -q "$1" "$W/verif.dts"; then ok "$2"; else bad "manquant : $2"; fail=1; fi; }
absent()  { if grep -q "$1" "$W/verif.dts"; then bad "encore present : $2"; fail=1; else ok "absent : $2"; fi; }

present 'vddmx-supply = <0x'            'pronto : vddmx-supply'
present 'vddpx-supply = <0x'            'pronto : vddpx-supply'
present 'pinctrl-0 = <0x'               'pronto : pinctrl-0'
present 'vddxo-supply = <0x'            'iris   : vddxo-supply'
present 'vddrfa-supply = <0x'           'iris   : vddrfa-supply'
present 'vddpa-supply = <0x'            'iris   : vddpa-supply'
present 'vdddig-supply = <0x'           'iris   : vdddig-supply'
present 'firmware-name = "wcnss.mdt"'   'firmware-name = wcnss.mdt'
present 'function = "wlan"'             'pinctrl : fonction wlan'
present 'pins = "gpio40", "gpio41"'     'pinctrl : gpio40..44'
absent  'reset-names = "phy", "por"'    'reset por du PHY USB'

# Verification par etat des noeuds (valable aussi si le DTB est deja corrige :
# inject.sh rejoue ce script a chaque image).
echo "  --- etat des noeuds WCNSS ---"
if python3 "$PY/verif-wcnss.py" "$W/verif.dts"; then
	ok "sous-systeme Wi-Fi complet"
else
	bad "sous-systeme Wi-Fi incomplet"
	fail=1
fi

if [ $fail -ne 0 ]; then
	echo
	echo "  CONTROLE NEGATIF : le DTB de l'image n'a PAS ete modifie."
	exit 1
fi

echo
echo "--- 7. ecriture dans l'image ---"
cp -f "$W/out.dtb" "$DTB" || { echo "  ecriture impossible"; exit 1; }
sync
taille=$(stat -c %s "$DTB")
ok "DTB en place : $taille octets"

echo
echo "--- 8. relecture depuis l'image ---"
dtc -I dtb -O dts "$DTB" 2>/dev/null > "$W/final.dts"
for w in 'vddmx-supply' 'firmware-name = "wcnss.mdt"' 'function = "wlan"'; do
	grep -q "$w" "$W/final.dts" && ok "relu : $w" || bad "relu : $w ABSENT"
done
grep -q 'reset-names = "phy", "por"' "$W/final.dts" && bad 'relu : por toujours la' || ok 'relu : plus de reset "por"'

echo
echo "--- 9. noeuds WCNSS dans le DTB final ---"
sed -n '/remoteproc@fb204000 {/,/smd-edge {/p' "$W/final.dts" | sed 's/^/    /'
echo
echo "=== FIN ==="
