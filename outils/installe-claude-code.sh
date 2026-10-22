#!/bin/sh
#  installe-claude-code.sh : installe Claude Code (interface terminal) sur une
#  tablette Nura deja installee. A lancer SUR la tablette, en root :
#
#      sudo sh installe-claude-code.sh
#
#  Pourquoi une version 1.0.128 et pas la derniere : depuis la 2.0, Claude Code
#  est un binaire natif compile par plateforme (x64 et arm64 uniquement, glibc
#  et musl). Il n'existe rien pour armv7, l'architecture de cette tablette. La
#  1.0.128 est la derniere version en JavaScript pur, et elle fonctionne ici.
#
#  Le ripgrep embarque n'existe pas non plus en armv7 : on depose celui du
#  systeme a l'emplacement attendu, et on force USE_BUILTIN_RIPGREP=0 par securite.
#
#  La 1.0.128 ne connait que les modeles de 2025 et son modele par defaut
#  (claude-sonnet-4-20250514) a ete retire : l'API repond "404 not_found_error".
#  Le lanceur impose donc un modele actuel (ANTHROPIC_MODEL, modifiable).
#
#  Le lanceur travaille dans /root/projets, marque comme approuve dans
#  /root/.claude.json : ni avertissement "home directory", ni dialogue
#  "Do you trust the files in this folder?" (qui, sur cette tablette, laissait
#  un ecran noir apres validation).
#
#  Ne touche ni aux comptes, ni aux mots de passe, ni au Wi-Fi. Rejouable.
set -u

VERSION=1.0.128
CD=/usr/local/lib/node_modules/@anthropic-ai/claude-code
LANCEUR=/usr/local/bin/claude-tui
PROJETS=/root/projets

if [ "$(id -u)" != 0 ]; then
	echo "A lancer en root :  sudo sh installe-claude-code.sh" >&2
	exit 1
fi

echo "== 1. Node et npm =="
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
	echo "  deja la : node $(node --version), npm $(npm --version)"
else
	apk add --no-cache nodejs npm >/dev/null 2>&1 || { echo "  !! echec de apk add" >&2; exit 1; }
	echo "  installe : node $(node --version), npm $(npm --version)"
fi

echo "== 2. Claude Code $VERSION =="
actuelle=""
[ -x /usr/local/bin/claude ] && actuelle=$(/usr/local/bin/claude --version 2>/dev/null | head -1)
case "$actuelle" in
*"$VERSION"*) echo "  deja installe : $actuelle" ;;
*)
	npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@$VERSION" >/dev/null 2>&1 \
		|| { echo "  !! npm a echoue" >&2; exit 1; }
	echo "  installe : $(/usr/local/bin/claude --version 2>/dev/null | head -1)"
	;;
esac

echo "== 3. ripgrep pour armv7 =="
if [ -x "$CD/vendor/ripgrep/arm-linux/rg" ]; then
	echo "  deja en place : $("$CD/vendor/ripgrep/arm-linux/rg" --version | head -1)"
else
	mkdir -p "$CD/vendor/ripgrep/arm-linux"
	if [ -x /usr/sbin/rg ]; then
		cp /usr/sbin/rg "$CD/vendor/ripgrep/arm-linux/rg"
		chmod 755 "$CD/vendor/ripgrep/arm-linux/rg"
		echo "  copie de /usr/sbin/rg : $($CD/vendor/ripgrep/arm-linux/rg --version | head -1)"
	else
		echo "  !! /usr/sbin/rg absent : la recherche de fichiers sera degradee" >&2
	fi
fi

echo "== 4. dossier de travail approuve =="
mkdir -p "$PROJETS"
# Ajoute (ou met a jour) l'approbation de $PROJETS sans toucher au reste du
# fichier, ni a la connexion deja faite.
PROJETS="$PROJETS" node -e '
	const fs = require("fs"), f = "/root/.claude.json", d = process.env.PROJETS;
	let j = {};
	try { j = JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) {}
	j.projects = j.projects || {};
	j.projects[d] = Object.assign({}, j.projects[d], { hasTrustDialogAccepted: true });
	fs.writeFileSync(f, JSON.stringify(j, null, 2));
	fs.chmodSync(f, 0o600);
' && echo "  $PROJETS approuve dans /root/.claude.json" \
	|| echo "  !! approbation impossible : Claude Code posera la question au premier lancement" >&2

echo "== 5. lanceur et menu =="
cat > "$LANCEUR" <<'LANCEUR'
#!/bin/sh
# Claude Code (interface texte) dans un terminal X.
#
# Particularites de cette tablette :
#  - xterm plutot que kitty : kitty demarre lentement et s'ouvre petit ici ;
#  - Claude Code met une quinzaine de secondes a afficher son premier ecran
#    (requete reseau au demarrage) : d'ou le message d'attente ;
#  - le dossier de travail est /root/projets, dont la confiance est deja
#    enregistree : le dialogue "Do you trust the files in this folder?"
#    ne s'affiche donc pas.
#
# Le client 1.0.128 (derniere version en JavaScript pur, seule compatible avec
# l'armv7 de la tablette) ne connait que les identifiants de modeles de 2025,
# et son modele par defaut (claude-sonnet-4-20250514) a ete retire : l'API
# repond alors "404 not_found_error". On impose donc un modele actuel.
# Pour en changer : ANTHROPIC_MODEL=claude-opus-5-5 claude-tui
ANTHROPIC_MODEL=${ANTHROPIC_MODEL:-claude-sonnet-5-5}
export ANTHROPIC_MODEL
export USE_BUILTIN_RIPGREP=0

# Dossier de travail : evite l'avertissement "home directory" et le dialogue
# de confiance.
cd /root/projets 2>/dev/null || cd /root

XT=/usr/sbin/xterm
[ -x "$XT" ] || XT=/usr/bin/xterm
[ -x "$XT" ] || XT=$(command -v xterm)
[ -n "$XT" ] || { echo "xterm introuvable" >&2; exit 1; }

"$XT" -geometry 110x28+0+20 -fa Monospace -fs 10 -bg black -fg white \
	-T "Claude Code" -e /bin/sh -c '
	echo "Claude Code demarre : comptez une quinzaine de secondes."
	echo "Modele : '"'"'"$ANTHROPIC_MODEL"'"'"'."
	echo "Premiere fois : tapez /login pour vous connecter."
	echo
	exec /usr/local/bin/claude
' &
pid=$!

# Le clavier virtuel repasse au premier plan : on tape au doigt.
(
	sleep 3
	clavier=$(xdotool search --name "^Keyboard$" 2>/dev/null | head -1)
	[ -n "$clavier" ] && xdotool windowraise "$clavier" 2>/dev/null
) &
wait $pid
LANCEUR
chmod 755 "$LANCEUR"
echo "  $LANCEUR"

MENU=/root/.icewm/menu
if [ -f "$MENU" ] && ! grep -q claude-tui "$MENU"; then
	sed -i '/prog "Kitty (terminal moderne)"/a\	prog "Claude Code (terminal)" /usr/share/icons/hicolor/256x256/apps/kitty.png /usr/local/bin/claude-tui' "$MENU"
	echo "  entree ajoutee au menu Fichiers"
fi
BARRE=/root/.icewm/toolbar
if [ -f "$BARRE" ] && ! grep -q claude-tui "$BARRE"; then
	printf 'prog "Claude Code" /usr/share/icons/hicolor/256x256/apps/kitty.png /usr/local/bin/claude-tui\n' >> "$BARRE"
	echo "  entree ajoutee a la barre"
fi
if [ -x /usr/bin/icewm ] && [ -n "${DISPLAY:-}" ]; then
	/usr/bin/icewm --restart >/dev/null 2>&1 && echo "  IceWM relance"
fi

echo "== 6. espace =="
df -h / | tail -1

echo
echo "== termine =="
echo "   Lancement : icone 'Claude Code' du menu Fichiers, ou la commande claude"
echo "   Il reste a s'authentifier : lancer claude, puis /login (compte Anthropic)"
echo "   ou definir ANTHROPIC_API_KEY."