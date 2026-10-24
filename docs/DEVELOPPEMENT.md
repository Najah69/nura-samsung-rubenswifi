# Notes de développement

Tout ce qu'il faut savoir pour reconstruire, réparer ou faire évoluer ce
portage. Ce document suppose que vous connaissez déjà `pmbootstrap` et le
fonctionnement général de postmarketOS/Nura.

---

## 1. Vue d'ensemble

```
pmaports/ (patch DTS + config noyau + paquet device)
        │  pmbootstrap build / install
        ▼
samsung-rubenswifi.img  ──►  inject.sh  ──►  prepare-image-publique.sh  ──►  image publiée
   (armv7, extlinux)          (scripts,           (retrait des données
                               services,           personnelles, contrôle)
                               comptes)
        │  heimdall flash --USERDATA
        ▼
lk2nd (partition BOOT) ──► extlinux.conf ──► vmlinuz + DTB + initramfs
```

L'ordre est **important** : `pmbootstrap install` recrée l'image de zéro et
efface tout ce qui a été injecté. Un changement de script ne demande donc
qu'`inject.sh` ; un changement de noyau, de DTS ou de paquet demande un
`install` complet, puis `inject.sh`.

---

## 2. Arborescence du dépôt

```
README.md                    vue d'ensemble et installation rapide
CHANGELOG.md                 historique
LICENSE                      MIT (travail original seulement)
docs/
  INSTALLATION.md            flashage détaillé, erreurs courantes
  PREMIER-DEMARRAGE.md       l'assistant, étape par étape
  UTILISATION.md             commandes du quotidien
  DEVELOPPEMENT.md           ce fichier
  CONNAISSANCES.md           notes brutes du portage (reprise de chantier)
  ETAT-FINAL.md              état mesuré de la tablette
pmaports/
  device-samsung-rubenswifi/            paquet device (deviceinfo, cmdline)
  firmware-samsung-rubenswifi/          calibration WCNSS
  linux-postmarketos-qcom-msm8226/      patch DTS + config noyau
inject/                      ce qui est copié dans l'image (charge utile)
  etc/ usr/ home/            arborescence cible
  inject.sh                  le script d'injection
  wcnss-dtb.sh               injection du nom de firmware dans le DTB
  outils/*.py                préparation du DTS et du DTB
outils/
  prepare-image-publique.sh  fabrique l'image publiable (+ contrôle de fuite)
  flash-userdata.sh          flashage vérifié par empreinte
```

Les images elles-mêmes ne sont pas dans le dépôt : elles sont dans les
**versions publiées** (release), à cause de leur taille.

---

## 3. Le noyau et le DTS

- Paquet : `linux-postmarketos-qcom-msm8226`, version **6.16.12**.
- Source : archive `v6.16.12-msm8226-u2` de
  <https://github.com/msm8226-mainline/linux> (branche de travail mainline pour
  ce SoC, cross-compilée en clang/LLVM).
- Config : `config-postmarketos-qcom-msm8226.armv7` (fournie ici comme
  référence ; c'est celle qui a produit l'image).
- Patch : `0001-ARM-dts-qcom-add-Samsung-Galaxy-Tab-Active-8.0-Wi-Fi.patch`
  (**558 lignes**) ajoute `qcom-apq8026-samsung-rubenswifi.dts` et sa
  description. Il déclare, entre autres :
  - la mémoire (1,5 Go, réserve pour le modem et l'Adreno) ;
  - le tactile **Synaptics S5707** en RMI4 sur `blsp1_i2c5` (0x20), IRQ `gpio 17` ;
  - l'accéléromètre **ST K2HH** (`st,lis2hh12`) sur `blsp1_i2c2` (0x1d),
    IRQ `gpio 54`, alimenté par `pm8226_l19` / `pm8226_lvs1`,
    `mount-matrix = "0","1","0", "-1","0","0", "0","0","-1"` ;
  - le capteur de luminosité **Capella CM3323** (0x10) sur le même bus ;
  - l'eMMC, la carte SD, les régulateurs RPM, l'USB en mode gadget ;
  - le panneau et le rétroéclairage, en `simple-framebuffer` (pas de KMS msm).

Les valeurs viennent du noyau Samsung 3.4 (`msm8226-sec-rubenswifieur-r04.dtsi`)
et de relevés sur la tablette. La révision matérielle est **r04** ; le dtsi
**r00** déclare en plus un capteur à effet Hall (`gpio 37`) que la r04 ne
possède pas — ne pas l'ajouter sans preuve matérielle.

### Modifier le DTS

```sh
cd pmaports/linux-postmarketos-qcom-msm8226
# le patch est appliqué par APKBUILD ; on le met à jour ainsi :
quilt pop -a 2>/dev/null || true
$EDITOR 0001-ARM-dts-qcom-add-Samsung-Galaxy-Tab-Active-8.0-Wi-Fi.patch
pmbootstrap checksum linux-postmarketos-qcom-msm8226
pmbootstrap build linux-postmarketos-qcom-msm8226 --arch armv7
```

> Un patch DTS se termine par un diff **sans** ligne `-- ` finale : certains
> éditeurs l'ajoutent et `git apply` échoue alors avec
> `corrupt patch at line …`. Vérifiez la dernière ligne du fichier.

---

## 4. Le paquet device

`device-samsung-rubenswifi/deviceinfo` — les lignes qui comptent :

```sh
deviceinfo_format_version="0"
deviceinfo_codename="samsung-rubenswifi"
deviceinfo_dtb="qcom-apq8026-samsung-rubenswifi"
deviceinfo_append_dtb="true"
deviceinfo_arch="armv7"
deviceinfo_flash_method="fastboot"
deviceinfo_generate_bootimg="true"
deviceinfo_generate_extlinux_config="true"
deviceinfo_partition_type="msdos"
```

- **`msdos`** et pas GPT : `lk2nd` ne gère pas encore les sous-partitions GPT, et
  le chargeur Samsung ne démarre pas depuis une clé USB.
- **`generate_extlinux_config`** : c'est `extlinux.conf` que `lk2nd` lit. Le
  `boot.img` est généré mais **inutilisable** ici (19 Mio pour une partition
  `BOOT` de 10 Mio) : il ne sert qu'à `pmbootstrap flasher`.
- **`append_dtb`** : le DTB est ajouté au noyau *et* déposé à part, parce que
  `lk2nd` charge le fichier indiqué par `fdt`.

`kernel-cmdline.conf` ajoute `msm.allow_vram_carveout=1 clk_ignore_unused
pd_ignore_unused` : sans ces options, le framebuffer légué par le chargeur n'est
pas conservé et `simpledrm` n'a rien à afficher.

---

## 5. Le firmware Wi-Fi (WCNSS)

C'est la partie la plus contre-intuitive du portage.

Le noyau cherche les firmwares dans `firmware_class.path`, positionné par
`msm-firmware-loader` sur `/run/msm-firmware-loader/target`. Or ce chargeur ne
fait que créer des **liens vers les partitions** de la tablette : il n'importe
pas `/usr/lib/firmware/postmarketos`.

D'où `usr/local/bin/load-wcnss-fw.sh`, qui, dans cet ordre :

1. copie la calibration du paquet `firmware-samsung-rubenswifi`
   (`WCNSS_qcom_wlan_nv.bin`, `WCNSS_qcom_cfg.ini`) vers
   `/usr/lib/firmware/postmarketos/wlan/prima/` ;
2. récolte `wcnss.mdt` et `wcnss.b*` sur les partitions montées par le chargeur
   (ils sont dans `APNHLOS`, la partition du firmware Samsung) ;
3. les installe **à la fois** dans `/lib/firmware/wlan/prima` et dans la cible du
   chargeur ;
4. `modprobe qcom_wcnss_pil` puis `wcn36xx`, avec une nouvelle tentative.

`etc/modprobe.d/zz-wcnss.conf` met `qcom_wcnss_pil` et `wcn36xx` en liste noire
pour que udev ne les charge pas trop tôt, avant que les fichiers soient en place.

Le message `qcom_wcnss_ctrl … expected cold boot completion` apparaît **même
quand le Wi-Fi fonctionne** : ce n'est pas une erreur bloquante.

> Les deux fichiers de calibration sont des extraits du firmware Samsung
> d'origine. Ils restent la propriété de Samsung ; ils sont là uniquement pour
> que l'image fonctionne sur le matériel d'origine. Si vous préférez ne pas les
> utiliser, supprimez-les du paquet et laissez `load-wcnss-fw.sh` récolter
> l'ensemble sur votre propre tablette.

---

## 6. L'affichage : le point le plus délicat

- Seul **`simpledrm`** fournit `/dev/dri/card0`. Il n'y a **aucun** moteur KMS
  `msm` pour l'APQ8026 en mainline, donc aucune accélération graphique.
- X11 utilise le pilote **`modesetting`** ; la sortie s'appelle **`None-1`**
  (elle n'a pas de nom de connecteur). `fbdev` **échoue** : `smem_len = 0`.
- `AddScreen/ScreenInit failed for driver 0` est un **symptôme**, pas une cause :
  il signifie que le pilote n'a pas pu ouvrir la sortie. Ne forcez jamais
  `DefaultDepth` avant de connaître le format réel du framebuffer — c'est le
  meilleur moyen de masquer le vrai problème.
- `xorg-modesetting.conf` ne déclare donc presque rien : `modesetting`, un
  écran, pas de profondeur imposée.
- `fbcon` et X cohabitent, mais le changement de mode est lent : d'où les délais
  dans `x11-run.sh` avant de lancer le serveur.

---

## 7. Tactile et rotation

Le tactile est en RMI4 : le noyau expose `/dev/input/event*`, X le voit comme un
périphérique absolu.

```sh
xrandr --output None-1 --rotate left     # paysage
xrandr --output None-1 --rotate normal   # portrait (repère natif)
xinput set-prop <id> 'Coordinate Transformation Matrix' 0 -1 1 1 0 0 0 0 1
```

La matrice ci-dessus est celle du **paysage** ; en portrait c'est l'identité.
`orientation.sh` fait les deux (xrandr puis matrice) et enregistre le choix dans
`/etc/nura/assistant.conf`, que relit `x11-run.sh` au démarrage suivant.

Sans la matrice, l'écran tourne mais le toucher reste dans l'ancien repère :
c'est le symptôme classique « le tactile est décalé ».

---

## 8. Le clavier virtuel

`matchbox-keyboard`, avec une disposition AZERTY (`fr`) générée par l'assistant.

Trois choses ont été nécessaires :

1. **Il ne s'affiche pas au-dessus d'un `xterm -fullscreen`.** La fenêtre est
   bien créée (1280 × 266 en y = 558) mais reste invisible. Solution : xterm en
   `-geometry 141x42+0+0`, ce qui donne un client de 1276 × 748 en (4, 24).
2. **Hauteur** : 42 % de l'écran. À un tiers, la rangée Ctrl/Alt/espace est
   coupée. Position : `y = hauteur − hauteur_clavier − 24` (les 24 px sont la
   barre de titre d'IceWM).
3. **L'assistant rétrécit sa propre fenêtre** quand le clavier apparaît
   (`hauteur − clavier − 56`) puis la rétablit : c'est ce qui garde les boutons
   OK/Annuler visibles.

Au démarrage, plus aucune recherche de clavier USB (≈ 6 s perdues et blocage
quand une station d'accueil est absente) : `dock-keyboard.sh` n'est plus lancé
par `x11-icewm.service`, et le clavier tactile s'affiche dans tous les cas.

---

## 9. Le réseau par câble USB

Le gadget s'appelle `g1` et ne déclare **que** `ncm.usb0` :

```sh
# état
cat /sys/class/net/usb0/carrier      # 1 = câble branché
systemctl status usb-gadget unudhcpd@usb0
```

- `unudhcpd@usb0` sert **172.16.42.1** à la tablette et **172.16.42.2** au PC.
- `usb0` reste `DOWN` avec `NO-CARRIER` **quand aucun câble n'est branché** :
  c'est normal, et `operstate` ne dit rien d'utile (il reste `down` même câble
  branché). Toujours lire `carrier`.
- **Ne pas** lancer `dnsmasq` en plus d'`unudhcpd` : deux serveurs DHCP sur la
  même interface se disputent les baux. `reseau-usb.sh` ne démarre `dnsmasq`
  qu'en repli, si `unudhcpd` est absent.
- Le gadget ne déclare pas de port série : `/dev/ttyGS0` **n'existe pas**, et
  `serial-getty@ttyGS0` ne sert à rien. C'est volontaire — le port série n'a
  jamais fonctionné sur cette tablette en mainline.

---

## 10. L'assistant de premier démarrage

`usr/local/bin/nura-assistant` (whiptail, ~700 lignes) s'exécute au premier
démarrage (`ASSISTANT_DONE=0`) et propose :

| Étape | Ce qu'elle fait |
|---|---|
| Clavier | disposition X (`fr`, `us`, `de`, `es`, `ar`) |
| Fuseau horaire | `timedatectl set-timezone` |
| Nom | `hostnamectl set-hostname` + `nura-config set NOM` |
| Compte | crée l'utilisateur si besoin, groupes, **mot de passe** (`chpasswd`), sudo |
| Wi-Fi | balayage (`wpa_cli scan_results`), choix du réseau, mot de passe, écriture du fichier wpa |
| Réseau USB | arme le gadget, explique qu'il s'active au branchement |
| Orientation | portrait ou paysage, avec la matrice appliquée |
| Résumé | relit les réglages et termine (`ASSISTANT_DONE=1`) |

Les réglages vont dans `/etc/nura/assistant.conf` (clé=valeur), lus et écrits par
`nura-config get|set|list`. Les réseaux mémorisés vont dans `/etc/nura/wifi/`.

Détails qui ont coûté du temps :

- dans `whiptail`, `0 0` donne une boîte trop courte : **toujours** des
  dimensions explicites ;
- le mot de passe Wi-Fi se stocke avec `wpa_passphrase`, dont la sortie contient
  une ligne `#psk="motdepasse"` **en clair** : elle est filtrée
  (`sed '/^[[:space:]]*#psk=/d'`) avant écriture ;
- `busybox awk` ne comprend pas `\t` dans un motif : le balayage Wi-Fi est écrit
  sans.

---

## 11. L'image et l'injection

`inject.sh` monte la **partition 2** de l'image (`/dev/loopXp2`) sur
`/mnt/t360root`, copie les fichiers, crée les comptes, active les unités, puis
démonte. Il faut être **root** (`wsl -d Ubuntu -u root -- bash inject.sh`) et
toujours démonter avant de rendre l'image.

`outils/prepare-image-publique.sh` prend une image de travail, la copie, monte la
partition 2, puis :

1. remplace le fichier Wi-Fi par un modèle vierge ;
2. retire le nom de réseau de la description du service ;
3. vide `/etc/nura/wifi` et `/var/lib/nura` ;
4. reprend **toute la charge utile du dépôt** (`inject/`) si on le lui donne en
   3ᵉ argument — l'image publiée et le dépôt sont alors identiques octet pour
   octet ;
5. remet les mots de passe à `147147` (comptes et VNC) ;
6. efface clés SSH, historiques, journaux, `.vnc`, `.Xauthority` ;
7. **vérifie** qu'aucun motif personnel ne subsiste et refuse d'écrire l'image
   dans le cas contraire.

```sh
sudo bash outils/prepare-image-publique.sh \
     ~/pmbootstrap/…/samsung-rubenswifi.img \
     samsung-rubenswifi-v1.0.img \
     inject
```

> **Monter une image ext4 en lecture-écriture change ses octets** (superbloc,
> journal) : une empreinte relevée après un montage `rw` ne correspond plus.
> Pour vérifier une image sans la modifier :
> `mount -o ro,noload /dev/loopXp2 /mnt`.

---

## 12. Reconstruire de zéro

```sh
# 1. outils
python3 -m venv ~/pmb-venv && . ~/pmb-venv/bin/activate
pip install pmbootstrap
pmbootstrap init          # canal systemd-edge, ui console, armv7, samsung-rubenswifi

# 2. pmaports du dépôt
git clone https://github.com/Najah69/nura-samsung-rubenswifi
cp -r nura-samsung-rubenswifi/pmaports/* ~/pmaports/device/testing/
#   (les paquets vont dans device/testing/ pour un appareil non encore accepté)
(cd ~/pmaports && git add -A && git commit -m "samsung-rubenswifi")

# 3. noyau + image
pmbootstrap checksum linux-postmarketos-qcom-msm8226
pmbootstrap build linux-postmarketos-qcom-msm8226 --arch armv7
pmbootstrap install

# 4. charge utile
wsl -d Ubuntu -u root -- bash inject/inject.sh

# 5. image publiable
sudo bash outils/prepare-image-publique.sh <image> <sortie> inject
```

L'image se trouve ensuite dans
`~/.local/var/pmbootstrap/chroot_native/home/pmos/rootfs/samsung-rubenswifi.img`.

---

## 13. Vérifications utiles

```sh
# sur la tablette
x11-diag.sh                       # X, sortie, rotation, tactile, VNC, clavier
wifi.sh debug                     # état du supplicant, réseaux vus
sudo load-wcnss-fw.sh             # journal du chargement des firmwares
systemctl --failed                # doit être vide
nura-config list

# dans l'image, sans la modifier
sudo losetup -fP --show image.img
sudo mount -o ro,noload /dev/loopXp2 /mnt
grep -rl 'motif' /mnt/etc /mnt/usr/local     # contrôle de fuite
sudo umount /mnt && sudo losetup -d /dev/loopX
```

---

## 14. Pièges déjà rencontrés

1. **`pmbootstrap install` efface les injections.** Refaire `inject.sh` après.
2. **`AddScreen/ScreenInit failed`** : symptôme, pas cause. Ne pas forcer
   `DefaultDepth`.
3. **`boot.img` inutilisable** : 19 Mio pour 10 Mio de partition `BOOT`. C'est
   `lk2nd` + extlinux qui amorcent.
4. **`operstate` ment** sur `usb0` : lire `carrier`.
5. **Deux DHCP** sur `usb0` = baux qui se croisent.
6. **`apk add sudo`** entre en conflit avec `postmarketos-base-sudo-rs` :
   utiliser `doas`/`sudo-rs` déjà présents, ou remplacer le paquet.
7. **`apk update`/`apk add` en root obligatoire**, sinon
   `ERROR: Unable to open log: Permission denied`.
8. **`wpa_supplicant -f` n'existe pas** (c'est une option de `hostapd`) : le
   supplicant affiche son usage et sort. Utiliser `-dd` et le journal.
9. **`wpa_passphrase` écrit le mot de passe en clair** dans un commentaire.
10. **Tester un binaire de la rootfs cible par son chemin réel**
    (`$M/usr/bin/bash`) : `$M/bin/bash` suit le lien absolu `/bin → usr/bin` et
    testerait l'hôte.
11. **Un montage `rw` change l'empreinte** de l'image.
12. **`matchbox-keyboard` invisible sur un xterm `-fullscreen`.**
13. **`docker`/`usbipd`** : rattacher la tablette après chaque rebranchement.
14. **Wi-Fi depuis WSL2** : WSL est en NAT, la tablette n'est joignable que depuis
    Windows. Tester avec `ssh` côté PowerShell, pas côté WSL.
15. **`ps w -C Xorg`** ne donne rien (busybox `ps` n'a pas `-C`) : `ps w | grep`.

---

## 15. Ce qui reste à faire

Contributions bienvenues, dans l'ordre d'utilité :

1. **Batterie et charge** : le chargeur est un **MAX77804K**, sans pilote
   mainline. Sans lui, aucun `/sys/class/power_supply`, donc pas d'indicateur ni
   de veille propre. Un pilote `power_supply` + `extcon` serait le plus gros
   apport possible.
2. **Audio** : haut-parleur, micros et prise casque passent par le codec
   **WCD9306** « Tapan » sur SLIMbus, sans pilote mainline. Le MAX98504 des
   sources Samsung est absent de cette tablette (bus I²C n° 6 sondé : aucune
   réponse). L'ADSP démarre déjà (firmware `modem:/image/adsp.mdt`, QDSP6/APR,
   `q6core` répond) : voir les « Pièges vérifiés » du README.
3. **GPU** : `msm`/freedreno 2D-3D sur APQ8026 demande le support DRM msm8226,
   absent. `simpledrm` + rendu logiciel restera la règle en attendant.
4. **Veille** : rien de sérieux sans `power_supply` ni gestion fine des
   régulateurs.
5. **Micro Bluetooth** : la lecture marche (A2DP, `maj-bluetooth.sh`), mais en
   mode mains libres la voix SCO est routée vers l'ADSP et n'arrive jamais par
   HCI (`btmon` : aucun paquet).
6. **Capteurs** : vérifier le signe de `in_accel_z` et l'existence du capteur de
   luminosité sur la révision r04.
7. **Portage amont** : proposer le paquet device à pmaports (voir
   `docs/CONNAISSANCES.md` pour les écarts avec `samsung-milletwifi`, le modèle
   le plus proche déjà accepté).
