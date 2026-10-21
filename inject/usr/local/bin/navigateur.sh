#!/bin/sh
# Lance un navigateur web sur la Galaxy Tab Active 8.0 (SM-T360).
#
#   navigateur.sh netsurf   -> navigateur leger (paquet netsurf)
#   navigateur.sh firefox   -> Firefox, pour les sites modernes
#   navigateur.sh           -> netsurf
#
# La tablette n'a ni GPU pilote ni KMS msm : le rendu est logiciel, et elle ne
# dispose que de 1,5 Go de RAM. On force donc explicitement le rendu logiciel
# et on desactive Wayland (la session est X11).

export LIBGL_ALWAYS_SOFTWARE=1
export MOZ_WEBRENDER=0
export MOZ_ACCELERATED=0
export MOZ_ENABLE_WAYLAND=0
export GDK_BACKEND=x11

# Un profil Firefox par utilisateur, sans quoi un HOME en lecture seule casse
# le demarrage.
if [ -z "${HOME:-}" ] || [ ! -w "${HOME:-/nonexistent}" ]; then
	HOME=/tmp
	export HOME
fi

case "${1:-netsurf}" in
	firefox|ff)
		shift
		for c in firefox firefox-esr; do
			if command -v "$c" >/dev/null 2>&1; then
				exec "$c" "$@"
			fi
		done
		manquant="firefox"
		;;
	*)
		shift
		for c in netsurf netsurf-gtk3 netsurf-gtk netsurf-fb; do
			if command -v "$c" >/dev/null 2>&1; then
				exec "$c" "$@"
			fi
		done
		manquant="netsurf"
		;;
esac

# Le binaire n'est pas la : on le dit, dans un terminal si possible.
msg="navigateur introuvable : le paquet $manquant n'est pas installe.
  installer : apk add $manquant"
echo "$msg" >&2
if command -v xterm >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
	xterm -xrm "XTerm*font: 10x20" -geometry 78x10 -e sh -c "echo '$msg'; sleep 5" &
fi
exit 1
