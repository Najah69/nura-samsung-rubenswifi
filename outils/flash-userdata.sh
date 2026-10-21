#!/bin/bash
#  flash-userdata.sh - ecrit une image Nura dans la partition USERDATA.
#
#  usage : flash-userdata.sh <image.img> [lk2nd-rubens.img]
#
#    image          l'image systeme (samsung-rubenswifi-v1.0.img)
#    lk2nd          facultatif : flashe aussi lk2nd dans la partition BOOT
#                   (une seule fois par tablette)
#
#  Verifie l'empreinte SHA-256 de l'image contre SHA256SUMS.txt place a cote
#  d'elle, s'il existe. Ne flashe jamais une image dont l'empreinte ne
#  correspond pas.
#
#  Prerequis :
#    - heimdall installe (apt install heimdall-flash) ;
#    - tablette en mode download : eteinte, Volume bas + Home + Power,
#      puis Volume haut a l'avertissement ;
#    - sous WSL : usbipd attach --wsl --busid <n> juste avant.
set -u

IMG=${1:?usage : flash-userdata.sh <image.img> [lk2nd-rubens.img]}
LK2ND=${2:-}

[ -f "$IMG" ] || { echo "image absente : $IMG"; exit 1; }
command -v heimdall >/dev/null || { echo "heimdall absent : apt install heimdall-flash"; exit 1; }

# --- empreinte -------------------------------------------------------------
DIR=$(dirname "$IMG")
SOM="$DIR/SHA256SUMS.txt"
if [ -f "$SOM" ] && grep -q "$(basename "$IMG")" "$SOM"; then
	echo "== verification de l'empreinte =="
	(cd "$DIR" && grep " $(basename "$IMG")\$" SHA256SUMS.txt | sha256sum -c -) || {
		echo "EMPREINTE FAUSSE : l'image est corrompue ou incomplete, ne pas flasher."
		exit 1
	}
else
	echo "== pas d'empreinte de reference : image non verifiee =="
	printf '  sha256 : %s\n' "$(sha256sum "$IMG" | cut -d' ' -f1)"
fi

# --- tablette --------------------------------------------------------------
echo "== peripherique =="
if ! heimdall detect 2>/dev/null | grep -qi detected; then
	echo "  TABLETTE NON DETECTEE"
	echo "  Eteignez-la, puis Volume bas + Home + Power, puis Volume haut."
	echo "  Sous WSL : usbipd attach --wsl --busid <n>"
	exit 1
fi
echo "  tablette detectee"

# --- lk2nd (facultatif) ----------------------------------------------------
if [ -n "$LK2ND" ]; then
	[ -f "$LK2ND" ] || { echo "lk2nd absent : $LK2ND"; exit 1; }
	echo "== lk2nd -> BOOT ($(basename "$LK2ND")) =="
	heimdall flash --BOOT "$LK2ND" --no-reboot || { echo "echec de l'ecriture de lk2nd"; exit 1; }
fi

# --- systeme ---------------------------------------------------------------
echo "== image =="
ls -l "$IMG" | sed 's/^/  /'
echo "== ecriture dans USERDATA (1 a 3 minutes) =="
if heimdall flash --USERDATA "$IMG" --no-reboot; then
	echo "== redemarrage =="
	heimdall close-pc-screen --resume && echo "  la tablette redemarre"
else
	echo "ECHEC de l'ecriture. La tablette reste en mode download :"
	echo "  verifiez le cable, l'empreinte de l'image, puis recommencez."
	exit 1
fi
