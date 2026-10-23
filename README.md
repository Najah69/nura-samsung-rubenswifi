# Nura (postmarketOS) sur Samsung Galaxy Tab Active 8.0 Wi-Fi — SM-T360

**Le premier portage publié de cette tablette.** Linux, X11, Wi-Fi, tactile,
clavier tactile, VNC et SSH sur une Galaxy Tab Active 8.0 de 2014 que Samsung a
abandonnée en Android 5.1.

![statut](https://img.shields.io/badge/statut-fonctionnelle-brightgreen)
![appareil](https://img.shields.io/badge/appareil-SM--T360%20(2014)-blue)
![noyau](https://img.shields.io/badge/noyau-6.16.12-informational)
![licence](https://img.shields.io/badge/licence-MIT-lightgrey)

---

## Sommaire

- [En deux mots](#en-deux-mots)
- [Aucun portage avant celui-ci](#aucun-portage-avant-celui-ci)
- [Ce qui marche, ce qui ne marche pas](#ce-qui-marche-ce-qui-ne-marche-pas)
- [Installer en cinq étapes](#installer-en-cinq-étapes)
- [Le premier démarrage](#le-premier-démarrage)
- [Au quotidien](#au-quotidien)
- [Questions fréquentes](#questions-fréquentes)
- [Le portage en détail (développeurs)](#le-portage-en-détail-développeurs)
- [Contribuer](#contribuer)
- [Crédits](#crédits)

---

## En deux mots

Une **Samsung Galaxy Tab Active 8.0 Wi-Fi (SM-T360)**, sortie en 2014 avec
Android 4.4 puis abandonnée en Android 5.1, fait maintenant tourner
**Nura** — qui est postmarketOS renommé depuis septembre 2026 — avec un noyau
Linux **6.16.12** à jour.

| | |
|---|---|
| Processeur | Qualcomm APQ8026 (msm8226), 4 × Cortex-A7 |
| Mémoire | 1,5 Go |
| Écran | 800 × 1280, tactile Synaptics S5707 |
| Stockage | eMMC 16 Go (11,1 Go pour le système une fois installé) |
| Système | Nura / postmarketOS 3.12.1, armv7 (32 bits), `systemd-edge` |
| Interface | X11 + IceWM + clavier tactile `matchbox-keyboard` |
| Accès | VNC (5900), SSH, et réseau par câble USB (172.16.42.1) |

Ce n'est **pas** une tablette Android modifiée : c'est un vrai Linux, avec
`apk`, `bash`, `gcc`, `git`, `nano`, `mc`, `ssh`, et un assistant qui configure
tout au premier démarrage.

---

## Aucun portage avant celui-ci

C'est le point important de ce dépôt, et il est vérifiable :

- Le wiki de Nura ne contient **aucune page** pour ce modèle :
  <https://wiki.nura.eco/wiki/Samsung_Galaxy_Tab_Active_8.0_(samsung-rubenswifi)>
  répond « page inexistante ».
- Une recherche plein texte sur **`SM-T360`** — la référence exacte de la
  tablette — ne renvoie **aucun résultat** :
  <https://wiki.nura.eco/index.php?search=SM-T360&fulltext=1>.
- Une recherche sur « Galaxy Tab Active » renvoie 8 pages, dont **aucune** ne
  concerne une Tab Active : ce sont les pages Tab 3 Lite, Tab S2 9.7, Tab A 8.0
  (2015), Tab S5e, et des pages génériques qui contiennent seulement les mots
  « tab » et « active ».
- Aucun paquet `device-samsung-rubens*` n'existe dans pmaports (le nom de code
  Samsung de cette tablette est `rubenswifi`, châssis `rubens`, révision r04).

Le modèle le plus proche déjà porté est la **Galaxy Tab 4 8.0 Wi-Fi**
(`samsung-milletwifi`), même SoC APQ8026. C'est une excellente référence — et
c'est précisément ce qui rend le travail possible — mais ce n'est **pas** le même
appareil : dalle, tactile, révisions matérielles, partitions et boutons
diffèrent. Aucune image `milletwifi` ne démarre sur une SM-T360.

Tout ce qui est dans ce dépôt a donc été écrit pour cette tablette : le DTB
(**558 lignes** de description matérielle), la configuration du noyau, le paquet
device, la récupération des firmwares Wi-Fi, l'affichage X11 sur `simpledrm`, la
rotation avec recalage du tactile, le clavier virtuel, le réseau par câble USB et
l'assistant de premier démarrage.

---

## Ce qui marche, ce qui ne marche pas

### Fonctionne

| | |
|---|---|
| Démarrage | `lk2nd` → extlinux → noyau 6.16.12, sans Android |
| Écran | 800 × 1280, X11 + IceWM, rotation paysage/portrait (commande, bouton, icône) |
| Tactile | Synaptics S5707, recalé automatiquement à chaque rotation |
| Clavier | clavier tactile AZERTY à l'écran, affiché au démarrage |
| Wi-Fi | WPA2 et WPA3, balayage et connexion par l'assistant, DHCP |
| Réseau USB | 172.16.42.1, actif dès le branchement du câble, sans Wi-Fi |
| VNC | `x11vnc` sur 5900 : la tablette est le serveur, le PC est le client |
| SSH | `sshd`, comptes `najah` (sudo) et `dsh` |
| USB | montage automatique des clés et cartes SD |
| Écran et luminosité | extinction après 3 min sans toucher, **Power** = éteindre / rallumer l'écran, **Vol Haut / Vol Bas** = luminosité avec une barre à l'écran |
| Touches du bas | **Accueil** = bureau, **Menu** = menu principal, **Retour** = page précédente |
| Usage au doigt | thème **Nura** : barres de titre et boutons de 40 px (fermer en rouge), icônes de 32 px, polices agrandies |
| Batterie | niveau **estimé** par la tension, icône dans la barre, alerte à 15 %, arrêt propre à 3 % |
| Son ? | voir ci-dessous : non |
| Paquets | `apk add` fonctionne, `gcc`, `git`, `python3`, `nano`, `mc` disponibles |
| Navigateurs | `netsurf` par défaut, `firefox` en secours sur les sites modernes |

### Ne fonctionne pas (et pourquoi)

| | Cause |
|---|---|
| **Batterie / charge** | le chargeur est un **MAX77804K**, sans pilote mainline : pas de recharge pilotée, pas de jauge. Le niveau est **estimé** par la tension (`batterie.sh`, icône de la barre), ce qui suffit à ne pas tomber en panne mais pas à une jauge fiable |
| **Son** | ampli **MAX98504**, routage propre à Samsung : travail DTS + `qcom-cdc` non fait |
| **Veille / suspend** | seul l'écran s'éteint. Les états de repos du processeur (`cpuidle`, SPC) **figent la tablette au démarrage** : essayé et abandonné, voir « Pièges vérifiés » |
| **Accélération graphique** | pas de KMS `msm` pour l'APQ8026 : `simpledrm` et rendu logiciel |
| **Bluetooth** | puce présente dans le WCNSS, transport UART non déclaré |
| **GPS, appareil photo, NFC** | non documentés pour cette révision, non testés |
| **Capteur de luminosité** | CM3323 reconnu (`iio:device0`), pas encore exploité pour la luminosité automatique |
| **Port série USB** | le gadget ne déclare que `ncm.usb0` ; `/dev/ttyGS0` n'existe pas |
| **HDMI / MHL** | non pris en charge |

Conséquence pratique : la batterie n'est **pas pilotée**. Il n'y a ni recharge
contrôlée ni veille du système, et le niveau affiché par `batterie.sh` et par
l'icône de la barre est une estimation par la tension — pessimiste quand la
tablette travaille, puisqu'elle baisse sous charge, et sans signification
pendant la charge. Éteindre l'écran (Power) reste le geste qui économise le plus. Une batterie pleine tient **4 à 5 heures** d'écran allumé en
usage bureautique/VNC.

---

## Installer en cinq étapes

Le détail complet, les pilotes Windows et les erreurs courantes sont dans
**[docs/INSTALLATION.md](docs/INSTALLATION.md)**. Voici l'essentiel.

### 1. Télécharger

Dans les **versions publiées** de ce dépôt :

- `samsung-rubenswifi-v1.0.1.img.xz` — l'image système (1,84 Gio une fois
  décompressée)
- `lk2nd-rubens.img` — le micro-chargeur d'amorçage (300 Ko)

Décompressez l'image (7-Zip sous Windows, `unxz` sous Linux) et vérifiez son
empreinte SHA-256 si vous voulez être tranquille.

### 2. Installer Heimdall

```sh
sudo apt install heimdall-flash      # Debian / Ubuntu / Mint
```

Sous Windows : Heimdall 1.4.2 + [Zadig](https://zadig.akeo.ie/) pour installer le
pilote WinUSB, ou WSL2 + `usbipd`. Tout est expliqué dans
[docs/INSTALLATION.md](docs/INSTALLATION.md).

### 3. Mettre la tablette en mode download

Éteinte, puis **Volume bas + Home + Power** ; à l'avertissement, **Volume haut**.

```sh
heimdall detect     # doit répondre : Device detected
```

### 4. Flasher

```sh
heimdall flash --BOOT lk2nd-rubens.img --no-reboot            # une seule fois
heimdall flash --USERDATA samsung-rubenswifi-v1.0.1.img --no-reboot
heimdall close-pc-screen --resume
```

L'écriture dure 1 à 3 minutes. **Ne débranchez pas.**

### 5. Démarrer

Premier démarrage : **1 à 3 minutes**. Écran Samsung, puis noir (c'est normal),
puis le bureau avec le clavier tactile et **l'assistant** qui vous guide :
langue du clavier, fuseau horaire, nom de la tablette, compte et mot de passe,
Wi-Fi, orientation.

C'est tout. La tablette est utilisable, sans compte Google, sans Android.

---

### Mettre à jour sans reflasher

Une correction de scripts ne demande pas de reflasher la tablette. Recopiez le
dossier `inject/` de ce dépôt sur la tablette (clé USB, `scp`, dossier partagé de
WSL), puis, **sur la tablette** :

```sh
sudo sh inject/maj-locale.sh
sudo sh inject/maj-clavier.sh
sudo sh inject/maj-energie.sh       # ecran, Power, luminosite, batterie, touches
sudo sh inject/maj-interface.sh     # theme Nura et tailles au doigt
sudo reboot
```

`maj-locale.sh` pose les scripts et les unités systemd, active les services,
redémarre le clavier et relance IceWM ; il garde une copie de chaque fichier
remplacé en `.avant-1.0.1`. Il ne touche ni aux comptes, ni aux mots de passe,
ni au Wi-Fi.

`maj-clavier.sh` corrige à lui seul la **taille des fenêtres** : le clavier
tactile annonçait à IceWM une réserve d'espace de ~534 px en bas de l'écran
alors qu'il n'en occupe que 266, si bien que toute fenêtre ouverte s'affichait
sur 245 px de haut, collée en bas (kitty en 25×25 pixels, Claude Code tronqué).
Le script remplace `dock-keyboard.sh` par la version qui retire cette réserve ;
le fichier précédent est gardé en `.avant-strut`. Sans lui, les fenêtres restent
minuscules — c'est la première chose à appliquer sur une tablette en 1.0.1.

`maj-energie.sh` installe la gestion de l'écran, du bouton marche, de la
luminosité et de la batterie (service `nura-energie`) et les touches du bas. Il
faut Internet : il installe `xprintidle`, `yad`, `xmessage`, `i2c-tools` et
`python3-tkinter`. Fichiers remplacés gardés en `.avant-energie`.

`maj-interface.sh` pose le thème **Nura** et les tailles au doigt, puis relance
IceWM. Fichiers remplacés gardés en `.avant-tactile`.

Aucun de ces scripts ne touche au noyau ni au démarrage (`/boot`).

À ne pas confondre : `inject.sh` travaille sur le **fichier image**, sur
l'ordinateur, pour fabriquer une image neuve. Lancé sur une tablette allumée, il
ne trouve pas l'image et s'arrête.

## Le premier démarrage

L'assistant ([docs/PREMIER-DEMARRAGE.md](docs/PREMIER-DEMARRAGE.md)) demande :

1. **la disposition du clavier** — `fr` par défaut ;
2. **le fuseau horaire** — `Europe/Paris` par défaut ;
3. **le nom de la tablette** sur le réseau ;
4. **le compte utilisateur** et son **mot de passe** (à choisir, ne le laissez pas
   par défaut) ;
5. **le Wi-Fi** : liste des réseaux détectés, puis mot de passe ;
6. **le réseau par câble USB** : rien à faire, il s'active au branchement ;
7. **l'orientation** : portrait ou paysage.

À la fin, la tablette affiche son adresse et de quoi s'y connecter :

```
Depuis l'ordinateur  : ssh najah@172.16.42.1
VNC                  : 172.16.42.1:5900
```

> **Mots de passe par défaut** (avant que vous ne les changiez) : comptes
> `najah` et `dsh` — `147147` ; VNC — `147147`. Ce sont les valeurs des images
> postmarketOS, choisies pour que rien ne soit secret dans une image publiée.
> **Changez-les** : `passwd` pour le compte, et
> `sudo x11vnc -storepasswd MONMOTDEPASSE /root/.vnc/passwd` pour VNC.

---

## Au quotidien

### VNC depuis Windows, macOS ou Linux

La tablette est le **serveur**, votre ordinateur le **client** :

1. branchez le câble USB (le réseau USB s'active tout seul), **ou** connectez les
   deux au même Wi-Fi ;
2. ouvrez un client VNC (TightVNC, RealVNC, Remmina, `vncviewer`) ;
3. connectez-vous à `172.16.42.1:5900` (USB) ou à l'adresse Wi-Fi de la
   tablette, mot de passe VNC.

L'écran de la tablette et celui de la fenêtre VNC sont le même : ce que vous
faites dans VNC se voit sur la tablette.

### SSH

```sh
ssh najah@172.16.42.1          # par le câble USB
ssh najah@192.168.1.xx         # par le Wi-Fi (adresse à relever sur la tablette)
```

### Retourner l'écran

```sh
orientation.sh paysage     # ou : portrait
```

Il y a aussi un **bouton dans la barre des tâches** (icône d'écran qui pivote) et
l'entrée de menu correspondante. La rotation recale le tactile ; sans elle, le
toucher resterait dans l'ancien repère.

### Afficher ou cacher le clavier tactile

```sh
keyboard.sh off     # cacher (utile quand il masque des boutons)
keyboard.sh on      # montrer
keyboard.sh etat    # état
```

### Brancher une clé USB ou une carte SD

Le montage est automatique (dans `/media`). `automount.sh --liste` montre ce qui
est monté.

### Installer un logiciel

```sh
sudo apk update
sudo apk add htop
```

### Claude Code dans le terminal

Claude Code (l'assistant d'Anthropic en mode texte) s'installe sur la tablette
avec un seul script, puis s'ouvre depuis le menu **Fichiers → Claude Code
(terminal)** ou la barre de tâches :

```sh
sudo sh outils/installe-claude-code.sh
```

Cinq choses à savoir, toutes expliquées dans le script :

- **la version installée est la 1.0.128, pas la dernière.** Depuis la 2.0,
  Claude Code est un binaire natif compilé pour x86-64 et arm64 : il n'existe
  rien pour l'armv7 de cette tablette. La 1.0.128 est la dernière version en
  JavaScript pur, et elle fonctionne ici ;
- **le `ripgrep` fourni avec Claude Code n'existe pas non plus en armv7** : le
  script dépose celui du système (ripgrep 15.2.0) à l'emplacement attendu et
  force `USE_BUILTIN_RIPGREP=0` ;
- **le modèle est imposé par le lanceur.** La 1.0.128 ne connaît que les
  modèles de 2025, et son modèle par défaut (`claude-sonnet-4-20250514`) a été
  retiré : l'API répond alors `404 not_found_error`. Le lanceur exporte donc
  `ANTHROPIC_MODEL=claude-sonnet-5-5`. Pour en changer, le temps d'une
  session : `ANTHROPIC_MODEL=claude-opus-5-5 claude-tui` ;
- **le dossier de travail est `/root/projets`**, que le script marque comme
  approuvé dans `/root/.claude.json`. Sans cela, Claude Code demande
  « Do you trust the files in this folder? », et sur cette tablette l'écran
  restait noir après la réponse ;
- **le premier écran met une quinzaine de secondes à apparaître** (requête
  réseau au démarrage). Le lanceur affiche un message d'attente pour éviter de
  croire à un blocage.

Sur une tablette où Claude Code est déjà installé, relancer le script suffit
pour obtenir ces deux corrections : il ne réinstalle pas ce qui est déjà en
place et ne touche pas à la connexion.

Il reste ensuite à s'authentifier, une seule fois : dans Claude Code, tapez
`/login` (compte Anthropic), ou définissez `ANTHROPIC_API_KEY`. Sans cela, la
réponse est `Invalid API key · Please run /login`.

Le terminal utilisé est **xterm** : kitty démarre lentement ici et n'apporte
rien sur un écran de 8 pouces.

### Écran, bouton marche et luminosité

| Geste | Effet |
|---|---|
| **Power**, appui court | éteindre l'écran ; un nouvel appui (ou **Accueil**) le rallume |
| **Power**, appui long (5 s) | arrêt propre de la tablette |
| **Vol Haut / Vol Bas** | luminosité, avec une barre « Luminosité NN % » à l'écran |
| 3 minutes sans toucher | l'écran s'éteint tout seul |
| Menu **Écran** | « Éteindre l'écran », luminosité +, −, 25 %, 50 %, 100 % |

Écran éteint, la dalle tactile est désactivée : un appui sur l'écran ne déclenche
rien par mégarde. Les réglages (délai, réveil au toucher, seuils de batterie)
sont dans `/etc/nura/energie.conf` ; après modification,
`sudo systemctl restart nura-energie`. En ligne de commande :
`luminosite.sh plus | moins | 50% | etat`.

### Touches du bas

| Touche | Effet |
|---|---|
| **Accueil** | afficher le bureau (un second appui ramène les fenêtres) |
| **Menu** | menu principal d'IceWM |
| **Retour** | page précédente (Alt+Gauche) dans Firefox et NetSurf |

Ce sont des raccourcis IceWM (`~/.icewm/keys`) : on peut les changer sans rien
recompiler.

### Batterie

L'icône à droite de la barre des tâches donne le niveau estimé (toucher l'icône
ouvre le détail de `batterie.sh`). À 15 % une alerte s'affiche ; à 3 %, confirmé
pendant 3 minutes, la tablette s'éteint proprement après un compte à rebours de
60 secondes, sauf si la tension remonte (chargeur branché).

### Éteindre proprement

Appui long (5 s) sur **Power**, l'entrée **Éteindre** du menu, ou :

```sh
sudo poweroff
```

---

## Questions fréquentes

**Pourquoi X11 et pas Wayland ?**
Parce que c'est ce qui fonctionne sur cette tablette, et ce que l'usage demandait
(un bureau léger, un clavier tactile, du VNC). Avec `simpledrm` et sans
accélération, Wayland n'apporterait rien et compliquerait la rotation et le
clavier.

**Pourquoi un clavier tactile plutôt qu'un clavier USB ?**
La tablette est utilisée sans dock. Chercher un clavier USB au démarrage coûtait
6 secondes et bloquait quand aucune station n'était branchée. Le clavier tactile
s'affiche maintenant dans tous les cas.

**Ça chauffe ?**
Oui, modérément : le processeur est plafonné à 787 MHz et il n'y a pas de
gestion fine de l'énergie. C'est supportable pour de la bureautique et du VNC.

**Je peux revenir à Android ?**
Oui, en reflashant un firmware Samsung d'origine pour SM-T360 avec Odin. Voir la
fin de [docs/INSTALLATION.md](docs/INSTALLATION.md).

**Est-ce que ça remplace une tablette Android ?**
Pour lire, écrire, naviguer sur des sites légers, prendre la main à distance,
administrer un serveur ou apprendre Linux : oui. Pour regarder YouTube en HD,
jouer ou utiliser l'appareil photo : non.

**Nura, c'est quoi ?**
postmarketOS, renommé en septembre 2026. Mêmes dépôts, mêmes paquets, même
`pmbootstrap`. Les littéraux techniques (`pmOS_boot`, `pmOS_root`) n'ont pas
changé.

---

## Le portage en détail (développeurs)

Tout est dans **[docs/DEVELOPPEMENT.md](docs/DEVELOPPEMENT.md)** ; voici la
carte.

### La chaîne de fabrication

```
pmaports  →  pmbootstrap install  →  inject.sh  →  prepare-image-publique.sh  →  heimdall
```

- `pmaports/` : le patch DTS, la config noyau, le paquet device.
- `inject/` : ce qui est copié dans l'image (scripts, unités systemd, réglages).
- `outils/` : fabrication de l'image publiable, flashage vérifié,
  `installe-claude-code.sh` (Claude Code sur la tablette) et
  `genere-theme-nura.py` (boutons du thème Nura).

### Les trois difficultés du portage

1. **L'amorçage.** Le chargeur Samsung ne lit pas `extlinux.conf` et la partition
   `BOOT` fait 10 Mio — trop pour un `boot.img` de 19 Mio. D'où `lk2nd` (300 Ko)
   dans `BOOT`, qui lit `extlinux.conf` sur la partition système.
2. **L'affichage.** Aucun KMS `msm` pour l'APQ8026 : seul `simpledrm` fournit
   `/dev/dri/card0`. X utilise `modesetting`, la sortie s'appelle `None-1`, et
   `AddScreen/ScreenInit failed` est un symptôme qu'il faut diagnostiquer, pas
   contourner en forçant `DefaultDepth`.
3. **Le Wi-Fi.** `msm-firmware-loader` ne fait que pointer vers les partitions ;
   il faut récolter `wcnss.mdt` et `wcnss.b*` sur `APNHLOS`, les copier aux deux
   endroits attendus, puis charger `qcom_wcnss_pil` et `wcn36xx` dans le bon
   ordre (`load-wcnss-fw.sh`).

### Le dépôt

```
pmaports/     patch DTS (558 lignes), config noyau, paquet device, firmware WCNSS
inject/       le payload (74 fichiers) : scripts, unités systemd, configurations,
              thème IceWM Nura, plus inject.sh (fabrication de l'image) et les
              mises à jour d'une tablette en marche (maj-locale.sh,
              maj-clavier.sh, maj-energie.sh, maj-interface.sh), outils
              Python du DTS
outils/       prepare-image-publique.sh, flash-userdata.sh,
              installe-claude-code.sh (Claude Code en terminal),
              genere-theme-nura.py (boutons du thème Nura, taille au choix)
docs/         installation, premier démarrage, utilisation, développement,
              connaissances brutes du chantier (CONNAISSANCES.md), état final
```

### Reconstruire

```sh
pmbootstrap init                      # armv7, systemd-edge, ui console
cp -r pmaports/* ~/pmaports/device/testing/
pmbootstrap checksum linux-postmarketos-qcom-msm8226
pmbootstrap build linux-postmarketos-qcom-msm8226 --arch armv7
pmbootstrap install
sudo bash inject/inject.sh            # ou : wsl -d Ubuntu -u root -- bash inject.sh
sudo bash outils/prepare-image-publique.sh <image> <sortie> inject
```

L'image publiée est fabriquée par `outils/prepare-image-publique.sh`, qui retire
les données personnelles et **refuse** d'écrire l'image si un contrôle de fuite
échoue. C'est ce qui garantit que l'image du dépôt et le dossier `inject/` sont
identiques octet pour octet.

### Vérifications

```sh
x11-diag.sh            # X, sortie, rotation, tactile, VNC, clavier
wifi.sh debug          # supplicant, réseaux vus
systemctl --failed     # doit être vide
```

### Pièges vérifiés (22 et 23 octobre 2026)

Constatés sur la tablette elle-même, à connaître avant d'y toucher :

- **Le rétroéclairage ignorait toute luminosité.** Le device tree configure la
  LP8556 avec `dev-ctrl = 0x80`, soit `BRT_MODE = 00` (« entrée PWM seulement ») :
  la puce ignore son registre de luminosité, que le pilote `lp855x` écrit
  pourtant (`bl_ctl_mode = register based`). `luminosite.sh init`, lancé par
  `nura-energie.service`, écrit `0x85` dans le registre `0x01` par I²C (bus lu
  dans sysfs), à chaque démarrage puisque le device tree remet `0x80`.
- **`bl_power` n'éteint pas l'écran** : `lp855x` ne regarde que l'état
  « fbblank ». L'extinction passe donc par une luminosité 0.
- **systemd-logind éteint la tablette au moindre appui sur Power** (réglage par
  défaut) : `etc/systemd/logind.conf.d/50-nura-bouton-marche.conf` le remplace
  par `HandlePowerKey=ignore` et `HandlePowerKeyLongPress=poweroff`.
- **IceWM 4.1 ignore les anciens noms d'options** (`IconSize`, `TaskBarFontName`,
  `TitleFontName`…), et le thème impose sa hauteur de barre de titre : les
  tailles au doigt passent par `~/.icewm/prefoverride`, lu après le thème.
- **`cpuidle` fige la tablette.** Déclarer l'état `qcom,idle-state-spc` sur les
  quatre cœurs (valeurs du msm8974 : 150/200/2000 µs) donne une tablette bloquée
  sur la mire Samsung + « lk2nd-msm8226 », alors que `spm.c` gère bien
  `qcom,msm8226-saw2-v2.1-cpu`. Ne pas réessayer sans moyen de retour éprouvé.
- **Le mode fastboot de lk2nd n'est pas vu par le PC** sur cette tablette
  (aucun périphérique USB, même avec un câble qui marche en mode download) :
  pas de `fastboot boot` de secours.
- **Heimdall efface tout `USERDATA`** avant d'écrire, même si le fichier envoyé
  est plus court : réécrire seulement `/boot` (les 488 premiers Mo) a fait perdre
  la partition système. Toute écriture de `USERDATA` est un reflash complet.

Conséquence pour qui modifie le démarrage (`/boot`, device tree, noyau) : prévoir
le retour arrière **dans le système lui-même**, ne compter ni sur fastboot ni sur
une écriture partielle.

---

## Contribuer

Les contributions les plus utiles, dans l'ordre :

1. **un pilote `power_supply` pour le MAX77804K** (batterie et charge) — c'est le
   chaînon manquant le plus important ;
2. l'audio (MAX98504 + routage DTS) ;
3. le Bluetooth ;
4. la vérification du capteur de luminosité et du signe de l'accéléromètre ;
5. la proposition du paquet device à pmaports, pour que ce portage devienne
   officiel.

Ouvrez une *issue* pour discuter avant d'envoyer du code, et joignez toujours la
sortie de `x11-diag.sh` et `dmesg` : c'est ce qui permet de diagnostiquer à
distance.

---

## Crédits

- **postmarketOS / Nura** et `pmbootstrap`, sans lesquels rien de tout cela
  n'existerait : <https://postmarketos.org>, <https://wiki.nura.eco>.
- **msm8226-mainline** (<https://github.com/msm8226-mainline/linux>) pour le
  noyau mainline du SoC, et le portage `samsung-milletwifi` qui a servi de
  référence.
- **lk2nd** (<https://github.com/msm8916-mainline/lk2nd>) pour le chargeur
  d'amorçage.
- Le noyau Samsung 3.4 de la tablette, dont les sources (GPL) ont donné les
  adresses et les paramètres du tactile, des capteurs et du WCNSS.
- **Najah** ([@Najah69](https://github.com/Najah69)) pour le portage, les tests
  sur matériel réel et la documentation.

---

## Licence

Le travail original de ce dépôt (patch DTS, paquet device, scripts, unités
systemd, documentation) est sous licence **MIT** — voir [LICENSE](LICENSE).

Le noyau Linux est en GPL-2.0, postmarketOS/Nura a ses propres licences, et les
firmwares Samsung extraits de la tablette restent la propriété de Samsung.

**Projet non officiel** : ni édité, ni validé, ni soutenu par Samsung, par
l'équipe postmarketOS ou par Nura. Flasher une tablette efface ses données et
peut la rendre inutilisable ; c'est à vos risques.

---

## English summary

This repository is the **first public port of postmarketOS/Nura to the Samsung
Galaxy Tab Active 8.0 Wi-Fi (SM-T360)** — a 2014 tablet that had no mainline
support of any kind (the device wiki page does not exist and a full-text search
for its model number returns nothing).

What works: mainline Linux 6.16.12 boot (lk2nd → extlinux), X11 + IceWM on
`simpledrm`, Synaptics touchscreen with rotation-aware calibration, on-screen
QWERTY/AZERTY keyboard, Wi-Fi (WPA2/WPA3, WCNSS firmware harvested from the
device's own partitions), USB networking (172.16.42.1), VNC, SSH, automatic USB
storage mounting, and a first-boot setup assistant. Power management in user
space: screen blanking after inactivity, Power key toggles the screen (long press
= clean shutdown), Vol keys set the backlight (LP8556 switched to register mode
over I²C) with an on-screen bar, Home/Menu/Back keys mapped, voltage-based
battery estimate with tray icon and clean shutdown when empty, and a
finger-friendly IceWM theme ("Nura", 40 px title buttons).

What does not work: battery/charging (MAX77804K has no mainline driver), audio
(MAX98504), suspend (SPC cpuidle states hang the boot), GPU acceleration,
Bluetooth, GPS, camera, NFC, USB serial. Beware: Heimdall wipes the whole
USERDATA partition, and lk2nd's fastboot mode is not seen by the host.

Install: flash `lk2nd-rubens.img` to `BOOT` once, then the system image to
`USERDATA` with Heimdall. See [docs/INSTALLATION.md](docs/INSTALLATION.md).
Default passwords are `147147` (postmarketOS convention) — change them.

Licence MIT for the original work; unofficial project, not affiliated with
Samsung, postmarketOS or Nura.
