# Journal des versions

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
