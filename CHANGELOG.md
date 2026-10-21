# Journal des versions

## 1.0.1 — 21 octobre 2026

Corrections de l'image `v1.0`. Le noyau ne change pas : seuls le payload
(`inject/`) et une dépendance du paquet `device-samsung-rubenswifi` bougent.
Sur une tablette déjà installée, une réinjection suffit.

- **La racine ext4 grandit au démarrage.** L'initramfs agrandissait la partition
  (`mmcblk0p26`) mais pas le système de fichiers : la racine restait à
  **1,27 Gio** dans une partition de 11,5 Gio, et `apk add` finissait par
  échouer sur « No space left on device ». Nouveau service
  `nura-grandit-racine.service` → `/usr/local/bin/grandit-racine.sh`, qui lance
  `resize2fs` au démarrage (idempotent, journalisé dans
  `/var/log/nura-grandit.log`).
- **Le clavier tactile est surveillé.** `.xinitrc` ne le lançait qu'une fois :
  s'il mourait, la tablette n'avait plus aucun moyen de saisie. Nouveau service
  `clavier-virtuel.service` (`Restart=on-failure`, rattaché à
  `x11-icewm.service`), et l'icône « clavier » de la barre passe désormais par
  `systemctl` au lieu de tuer puis relancer le processus à la main.
- **Kitty** (terminal moderne, kitty 0.48) entre dans les dépendances du paquet
  `device-samsung-rubenswifi`, donc dans l'image. Il apparaît dans le menu
  *Fichiers* et dans la barre de lancement rapide, avec son icône d'origine
  (`/usr/share/icons/hicolor/256x256/apps/kitty.png`) : IceWM 4 lit les PNG via
  Imlib2, vérifié sur la tablette.
- **Fond de bureau réparé.** Le fichier `preferences` contenait
  `DesktopBackgroundCenter = "/usr/share/icewm/themes/Infadel2/desktop.jpg"`.
  Dans IceWM 4 cette clé est un **booléen** et ce JPEG n'existe pas dans l'image :
  `icewmbg` refusait de démarrer (`Bad argument: … for DesktopBackgroundCenter
  [0,1]`) et le bureau restait noir. La clé correcte est
  `DesktopBackgroundImage`, avec l'image `fond-nura.png` livrée dans
  `/usr/share/pixmaps` (et `DesktopBackgroundScaled = 1`).
- **Où se règle le menu.** La session X tourne en root : IceWM lit
  `/root/.icewm/`, et `inject.sh` y recopie `home/najah/.icewm/`. C'est donc le
  fichier du payload qu'il faut modifier ; éditer seulement
  `/home/najah/.icewm/menu` sur une tablette n'a aucun effet visible.

## 1.0 — 21 octobre 2026

Première version publique. C'est aussi, à notre connaissance, la **première
image fonctionnelle jamais publiée pour la Samsung Galaxy Tab Active 8.0 Wi-Fi
(SM-T360)** : aucune page de wiki, aucun paquet, aucun rapport ne documentait ce
modèle avant ce travail (voir « Aucun portage avant celui-ci » dans le README).

### Ce que fait cette version

- **Démarrage** : `lk2nd` → extlinux → noyau Linux **6.16.12** (msm8226-mainline),
  avec le DTB de la tablette (`qcom-apq8026-samsung-rubenswifi`).
- **Affichage** : X11 + IceWM sur `simpledrm`, 800 × 1280, rotation paysage et
  portrait par commande, bouton de barre des tâches et icône.
- **Tactile** : Synaptics S5707 (RMI4), matrice recalculée à chaque rotation.
- **Clavier tactile** : `matchbox-keyboard`, AZERTY, 42 % de la hauteur d'écran,
  affiché au démarrage dans tous les cas (plus de recherche de clavier USB).
- **Wi-Fi** : WPA2/WPA3, balayage et connexion par l'assistant ; firmwares WCNSS
  récoltés automatiquement sur les partitions de la tablette.
- **Réseau par câble USB** : 172.16.42.1 côté tablette, DHCP et DNS prêts avant
  même le premier démarrage, sans Wi-Fi.
- **Assistant de premier démarrage** : langue du clavier, fuseau horaire, nom de
  la tablette, compte utilisateur et mot de passe, Wi-Fi (liste des réseaux et
  mot de passe), réseau USB, orientation, résumé.
- **VNC** (5900) et **SSH** : la tablette est le serveur, l'ordinateur est le
  client. `x11vnc` retrouve seul le fichier d'authentification de X.
- **Outils** : `nano`, `mc`, `wpa_cli`, `iw`, `xinput`, `xrandr`, `scrot`,
  `openssh`, `netsurf` (navigateur léger), `firefox` en secours, `bash`,
  `gcc`, `git`.
- **Montage automatique** des cartes SD et clés USB (`udev` + `automount.sh`).

### Corrections apportées depuis les images de travail

- Le mot de passe Wi-Fi n'est plus écrit en clair dans le fichier de
  configuration (`wpa_passphrase` laissait `#psk="…"` : le filtre le supprime).
- Deux serveurs DHCP pouvaient se disputer `usb0` : `reseau-usb.sh` ne lance plus
  `dnsmasq` quand `unudhcpd` est déjà actif.
- `reseau-usb.sh` lit l'état du câble dans `/sys/class/net/usb0/carrier` et non
  dans `operstate`, qui reste `down` même câble branché.
- L'assistant ne prétend plus que le réseau USB est « inactif » quand il attend
  simplement un câble.
- Le clavier tactile n'attend plus un clavier USB au démarrage (≈ 6 s gagnées et
  plus de blocage sur une station d'accueil absente).
- Le fichier Wi-Fi livré ne contient plus aucun réseau : c'est l'assistant qui
  l'enregistre au premier démarrage.

### Ce qui a été retiré de l'image avant publication

- le réseau Wi-Fi de l'auteur (nom et empreinte PSK : une empreinte WPA connue
  avec son SSID se casse hors ligne par dictionnaire) ;
- les mots de passe de l'auteur, remplacés par la valeur par défaut des images
  postmarketOS (`147147`, à changer au premier démarrage) ;
- le mot de passe VNC de l'auteur ;
- les clés SSH, historiques de shell, journaux et fichiers d'authentification X.

Le script [`outils/prepare-image-publique.sh`](outils/prepare-image-publique.sh)
refait ces opérations et refuse de produire l'image si une fuite subsiste.

### Numérotation

L'image publiée ici correspond à la version de travail **2.5**. Les versions
1.x et 2.x étaient des étapes internes (respectivement : premier démarrage
réussi, puis assistant et services). La numérotation repart à 1.0 pour la
première publication, comme prévu avec l'auteur du portage.
