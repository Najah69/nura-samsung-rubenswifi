# Connaissances acquises — portage postmarketOS « Nura » sur Samsung Galaxy Tab
# Active 8.0 Wi-Fi (SM-T360, `samsung-rubenswifi`, APQ8026 / msm8226)

Document de reprise : tout ce qu'il faut savoir pour reconstruire, réparer ou
faire évoluer l'image sans refaire les mêmes erreurs. Écrit le 21/10/2026.

---

## 1. La machine

| | |
|---|---|
| Modèle | Samsung Galaxy Tab Active 8.0 Wi-Fi, **SM-T360** |
| Nom de code Samsung | `rubenswifi` (châssis `rubens`, révision **r04**) |
| SoC | Qualcomm **APQ8026** (msm8226), 4× Cortex-A7 plafonnés à **787 MHz** |
| RAM | **1,5 Go** (1 412 Mo visibles), **32 bits** → `armv7` |
| Écran | 800 × 1280 (natif portrait), dalle paysage par construction |
| Tactile | Synaptics **S5707**, RMI4, i2c BLSP1 QUP5 (0x20), IRQ gpio 17 |
| Wi-Fi | WCNSS + wcn36xx, calibrations propriétaires Samsung |
| PMIC | PM8226 (régulateurs RPM) ; chargeur/MUIC **MAX77804K** (aucun pilote mainline) |
| GPU | Adreno 305 — **non piloté** en mainline msm8226 |
| Stockage | eMMC 16 Go, partitions **msdos** (pas de GPT), 11,1 Go pour `/` |

**Il n'y a ni GPU, ni moteur KMS `msm`, ni `power_supply`, ni audio, ni
Bluetooth, ni GPS, ni caméra, ni NFC fonctionnels.** Tout ce qui suit en tient compte.

## 2. La chaîne de fabrication

```
pmaports (patch DTS + config noyau)
        │  pmbootstrap build
        ▼
paquets .apk (armv7)  ──►  pmbootstrap install  ──►  samsung-rubenswifi.img
                                                         │
                            inject.sh (montage loop de la p2, copie des scripts)
                                                         │
                                                    flash (Heimdall ou fastboot)
                                                         ▼
                                                    lk2nd → extlinux → noyau + dtb + initramfs
```

- `pmbootstrap` tourne dans un venv : `~/pmb-venv/bin/activate`
- dépôt : `~/pmaports` (gitlab.postmarketos.org, branche `main`, commit `f3f9269`)
- espace de travail : `~/.local/var/pmbootstrap`
- canal **`systemd-edge`**, UI **`postmarketos-ui-console`**, locale `fr_FR.UTF-8`,
  hostname `rubenswifi`
- noyau : `linux-postmarketos-qcom-msm8226`, **6.16.12**, `_tag=v6.16.12-msm8226-u2`
  (github.com/msm8226-mainline/linux), cross-compilé **clang/LLVM**
- amorçage : **lk2nd 23.1** → `extlinux/extlinux.conf` → `vmlinuz` +
  `qcom-apq8026-samsung-rubenswifi.dtb` + `initramfs`

### ⚠ Ordre des opérations — à ne pas inverser

1. `pmbootstrap install`
2. `inject.sh` (scripts, services, comptes)
3. flash

`pmbootstrap install` **écrase** l'image : il efface les scripts injectés. Un
changement de script ne demande donc **que** `inject.sh` ; un changement de
noyau, de DTS ou de paquet demande un `install` complet puis `inject.sh`.

### Firmware Wi-Fi

Le noyau cherche les blobs via `firmware_class.path=/run/msm-firmware-loader/target`
(positionné par `msm-firmware-loader`), mais **retombe sur `/lib/firmware`**
(`/lib` → `usr/lib`, usr-merge). `msm-firmware-loader.sh` ne fait que créer des
liens depuis **les partitions** : il n'importe pas `/usr/lib/firmware/postmarketos`.

→ D'où `load-wcnss-fw.sh`, qui, dans cet ordre :

0. copie la calibration du **paquet** `firmware-samsung-rubenswifi-wcnss-nv`
   (`/usr/lib/firmware/postmarketos/wlan/prima/`) ;
1. récolte les blobs des partitions montées par le chargeur ;
2. les installe dans `/lib/firmware/wlan/prima` **et** dans la cible du chargeur ;
3. `modprobe qcom_wcnss_pil` puis `wcn36xx`, avec une nouvelle tentative.

Le message `qcom_wcnss_ctrl … expected cold boot completion` apparaît **même
quand le Wi-Fi fonctionne** : ce n'est pas une erreur bloquante.

## 3. Ce qui marche, ce qui ne marche pas

**Marche** (vérifié sur la tablette, image v2.4) : démarrage lk2nd/extlinux,
Wi-Fi (`MON-RESEAU`, WPA2/SAE, 5 GHz, DHCP), SSH (mot de passe), X11 + IceWM, rotation
paysage/portrait (bouton + icône) avec tactile recalé, clavier virtuel
`matchbox-keyboard` (AZERTY, toutes les rangées), VNC `x11vnc` sur 5900 (mot de
passe `147147` par défaut, régénéré à chaque démarrage, port ouvert par
`/etc/nftables.d/50_vnc.nft`), montage automatique des clés USB, **réseau par
câble USB** (voir §7), assistant d'installation `nura-assistant`, bash + nano +
mc + chaîne de compilation.

**Ne marche pas / absent** : audio (`/dev/snd` ne contient que `timer`), Bluetooth,
GPS, caméra, NFC, **batterie** (aucun `/sys/class/power_supply`), charge pilotée,
accélération graphique, accéléromètre (voir §6), capteur de luminosité (module
compilé, à vérifier), veille/suspend, HDMI/MHL, **port série USB** (pas de
`/dev/ttyGS0` : le gadget ne déclare que `ncm.usb0`, voir §7).

## 4. Affichage : le point le plus délicat

- Seul **`simpledrm`** fournit `/dev/dri/card0`. **Aucun** moteur KMS `msm`,
  aucune accélération.
- X11 utilise le pilote **`modesetting`** ; la sortie s'appelle **`None-1`**
  (pas de nom de connecteur). `fbdev` **échoue** : `smem_len = 0`.
- `AddScreen/ScreenInit failed for driver 0` est un **symptôme**, pas une cause :
  ne jamais forcer `DefaultDepth` avant de connaître le format du framebuffer.
- Rotation : `xrandr --output None-1 --rotate left|normal`, puis matrices
  `xinput` pour le tactile (sinon le toucher reste dans l'ancien repère).
- `fbcon` + `simpledrm` : console et X cohabitent, mais le changement de mode est
  lent ; d'où les délais dans `x11-run.sh`.

## 5. Clavier virtuel : la mécanique qui a fini par marcher

- `matchbox-keyboard` **ne s'affiche pas au-dessus d'un xterm `-fullscreen`** :
  la fenêtre est créée (1280×266 en y=558) mais reste invisible.
  → xterm en **`-geometry 141x42+0+0`**, qui donne un client respecté de
  **1276×748** en (4, 24).
- Le clavier occupe **42 % de la hauteur d'écran** (un tiers coupait la rangée
  Ctrl/Alt/espace), et se place à `y = hauteur_écran − hauteur_clavier − 24`
  (les 24 px sont la barre de titre IceWM).
- L'assistant (`nura-assistant`) **rétrécit sa propre fenêtre** quand le clavier
  apparaît (`hauteur − clavier − 56`) et la rétablit ensuite : c'est ce qui garde
  les boutons OK/Annuler visibles.
- `0 0` dans un `whiptail` donne une boîte trop courte : toujours des dimensions
  explicites.
- **Ne plus chercher de clavier USB au démarrage** (≈6 s perdues + attente du
  dock) : le clavier virtuel s'affiche dans tous les cas.

## 6. Capteurs (v2)

- **Accéléromètre ST K2HH** = compatible mainline **`st,lis2hh12`**. D'après le
  noyau Samsung 3.4 (`msm8226-sec-rubenswifieur-r04.dtsi`, lignes 104-126) :
  i2c **BLSP1 QUP2**, adresse **0x1d**, IRQ **gpio 54**, `vdd = pm8226_l19`,
  `vddio = pm8226_lvs1`, `axis_map 1/0/2`, `negate_y = 1`, `negate_z = 1`
  → `mount-matrix = "0","1","0", "-1","0","0", "0","0","-1"`.
  **À confirmer** : à plat, écran vers le haut, `in_accel_z` doit être **positif**
  (sinon inverser la dernière ligne de la matrice).
- **Capteur de luminosité Capella CM3323** en 0x10 sur le même bus, `pm8226_l19`.
  Le module n'était pas compilé (`# CONFIG_CM3323 is not set`) ; la v2 passe à
  `CONFIG_CM3323=m`. `st_accel{,_i2c,_spi}.ko` étaient déjà présents.
- **Capteur à effet Hall** : présent seulement dans le dtsi **r00**
  (`hall,irq-gpio = <&msmgpio 37>`, label `hall_flip`). La révision **r04** — la
  nôtre — ne le déclare pas : ne pas l'ajouter sans preuve matérielle.
- **Batterie / charge** : le PM8226 expose bien un `charger@1000` (`&smbb`) mais
  il est désactivé, et le vrai chargeur est un **MAX77804K sans pilote mainline**,
  tout comme la jauge (`sec-fuelgauge` côté Samsung). Rien à espérer côté noyau
  sans écrire un pilote.

## 7. Réseau et outillage embarqué

- `wpa_supplicant` + `wpa_cli` + `wpa_passphrase` ; mot de passe stocké **haché**
  (`wpa_passphrase SSID pwd`), jamais en clair dans un fichier de config.
- `nftables` : `/etc/nftables.nft` inclut `/etc/nftables.d/*.nft` — c'est là que
  va `50_vnc.nft` (chaîne `input`, port 5900).
- **Réseau par câble USB** : c'est `postmarketos-base` qui fait tout, il n'y a
  rien à écrire. Le gadget `g1` porte la fonction **`ncm.usb0`** (NCM ; Windows 10/11
  a le pilote d'origine), et **`unudhcpd@usb0`** (actif au démarrage) sert
  **172.16.42.1 au serveur, 172.16.42.2 au PC**. `usb0` est `DOWN` tant qu'aucun
  ordinateur n'est branché : c'est le `carrier` qui le dit, pas `operstate`.
  Vérification : `reseau-usb.sh etat` → `cable : branche`.
  Pièges appris ici :
  - `ci_hcrc.0 … not attached` ne veut pas dire « gadget cassé » mais « pas de
    câble » : conclure trop vite a déjà coûté une fausse impasse.
  - **Ne jamais lancer un second serveur DHCP** sur `usb0` : `reseau-usb.sh` a
    longtemps démarré `dnsmasq` en plus d'`unudhcpd`. Il ne le fait plus qu'en
    secours, si le service est absent.
  - `usb-gadget.sh` ne crée le gadget que si `g1` n'existe pas ; comme
    postmarketOS l'a déjà créé (avec `ncm` seul), `rndis` et `acm` ne sont jamais
    ajoutés — d'où l'absence de port série. Ajouter `acm.GS0` exigerait de
    recréer le gadget et de relier l'UDC : à faire seulement si le série devient
    nécessaire.
- `dnsmasq` reste installé, mais seulement en secours du DHCP USB.
- Paquets ajoutés à l'image : `bash`, `bash-completion`, `nano`, `mc`,
  `build-base`, `git`, `curl`, `wget`, `ca-certificates`, `tar`, `unzip`, `xz`,
  `zstd`, `patch`, `pkgconf`, `ripgrep`, `fd`.
- **bash comme shell de connexion** pour `root`, `najah`, `dsh` ; **`/bin/sh` reste
  busybox** (les scripts `#!/bin/sh` de pmOS en dépendent).
- Piège `sudo` : sur pmOS, `sudo` vient de `postmarketos-base-sudo-rs`
  (`/usr/sbin/sudo`) et **entre en conflit** avec le paquet `sudo`. Ne pas
  l'ajouter à une liste de paquets.
- **Comptes** : `najah` (uid 10000, groupes `wheel`, `audio`, `video`, `netdev`,
  `plugdev`) et `dsh` (uid 1001) — les deux ont `NOPASSWD: ALL`
  (`/etc/sudoers.d/10-wheel` et `dsh`). Root est verrouillé (`!`).
  Conséquence utile : `sudo -n` marche partout, aucun mot de passe à demander.
- **X tourne en root** (`Xorg :0`, `icewm-session`, `matchbox-keyboard`, `x11vnc`
  sont tous root, lancés par `x11-icewm.service`). Les entrées de menu IceWM
  héritent donc des droits root : un script d'administration n'a pas besoin
  d'élévation. `najah` n'a ni session X ni `.xinitrc` actif — le fichier existe
  pour un usage manuel.
- **X et son cookie** : Xorg est lancé par `xinit` avec `-auth /root/.serverauth.<pid>`.
  Tout client qui se connecte à `:0` doit réutiliser **ce** fichier, pas
  `/root/.Xauthority`. `x11vnc-start.sh` le lit dans `/proc/<pid>/cmdline`.

## 8. Pièges de l'atelier (Windows / WSL)

- **PowerShell mange `$`, `${}`, `(`, `|`, `<`, `>` et les guillemets** : cela a
  produit des boucles vides, des `bash: /usr/lib/firmware: Is a directory`, des
  `syntax error: unexpected "do"` et un job ssh bloqué.
  → **Toujours écrire un fichier `.sh` (ou `.ps1`), puis l'exécuter.**
- PowerShell 5.1 n'a **ni `head` ni `tail`** (utiliser `Select-Object -First/-Last`),
  ni `&&`/`||`.
- Un `.ps1` refuse de s'exécuter (stratégie d'exécution) → `powershell -NoProfile
  -ExecutionPolicy Bypass -File …`. Écrire les `.ps1` en **UTF-8 avec BOM**.
- Ne pas passer un chemin Windows à un binaire WSL : préfixer par `/mnt/c/…`.
- Un `ssh` qui écrit un heredoc depuis PowerShell est une source d'erreurs : `scp`
  le script puis `sh /tmp/script.sh`.
- Côté WSL, un processus lancé en arrière-plan meurt avec `wsl.exe` :
  `setsid nohup … < /dev/null &`.

## 9. Pièges du portage lui-même

- **Pas de GPT** : partitions **msdos**, et le chargeur Samsung ne démarre pas
  depuis une clé USB → aucun « live USB » possible. Tout passe par l'image et le
  mode download.
- Flash initial : **Heimdall**, tablette en mode download par
  **Vol Bas + Home + Power**, puis **Vol Haut** quand l'avertissement s'affiche ;
  côté Windows `usbipd attach --wsl -b <busid>`. `deviceinfo_flash_method` est
  passé à `fastboot` pour la suite (lk2nd sait le faire), mais les toutes
  premières images ont été écrites avec Heimdall.
- `inject.sh` monte la **partition 2** (`/dev/loopXp2`) sur `/mnt/t360root` :
  toujours `umount` avant de rendre l'image.
- Dans `inject.sh`, tester un binaire de la rootfs cible par son **chemin réel**
  (`$M/usr/bin/bash`) : `$M/bin/bash` suit le lien absolu `/bin → usr/bin` et
  testerait **l'hôte**.
- Le Wi-Fi depuis WSL : WSL2 est en NAT, la tablette n'est joignable que depuis
  **Windows** (d'où `ssh` côté PowerShell, pas côté WSL).
- `apk update` et `apk add` doivent tourner en **root** (sinon
  `ERROR: Unable to open log: Permission denied`).
- `busybox awk` ne comprend pas `\t` dans un motif : le scan Wi-Fi a dû être
  réécrit sans.

## 10. État mesuré (21/10/2026)

```
RAM       1412 Mo au total, 145 Mo utilisés, 851 Mo disponibles, 2118 Mo de swap
/         /dev/loop0p2, 11,1 Go, ~10 Go libres
apk       656 Mio dans 530 paquets (594 Mio avant les outils, +238 Mio)
versions  bash 5.3.9, gcc 15.2.0, git 2.56.0, ripgrep 15.2.0, fd 10.5.0, make 4.4.1
shells    root:najah:dsh = /bin/bash ; /bin/sh = busybox ; 131 complétions bash
wlan0     02:00:00:00:00:00
```

Coût simulé de quelques ajouts (à ne pas dépasser sans réfléchir, on a 1,5 Go de
RAM et ~5 Go utiles sur `/`) :

| Paquet | Taille | Total image |
|---|---|---|
| `netsurf` | 3,1 Mio | 661 Mio (+5) |
| `dillo` | 3,3 Mio | 658 Mio (+2) |
| `epiphany` | 50,6 Mio | 901 Mio (+246) |
| `firefox` | 154 Mio | 932 Mio (+276) |
| `xfce4` | 907 Mio | +251 (*) |

(*) `xfce4` tiré avec toutes ses dépendances : 251 Mio **en plus** des 656.
`lxqt`, `lxde`, `mate` et `falkon` sont **absents** des dépôts armv7.
`xfce4 4.20`, `xfwm4 4.20.0`, `thunar 4.20.8` sont disponibles.

## 11. Ce que « Nura » change (et ne change pas)

Nura **est** postmarketOS renommé (septembre 2026) : mêmes dépôts, mêmes paquets,
même pmbootstrap. Le wiki Nura documente le Galaxy **Tab 4 8.0 Wi-Fi**
(`samsung-milletwifi`) — même APQ8026, donc la meilleure référence possible.

Écarts avec `milletwifi` :

| Sujet | milletwifi (Nura officiel) | Notre rubenswifi v1 | v2 |
|---|---|---|---|
| Paquet device | `pkgver=6`, mainteneur réel, `msm-modem` | `pkgver=1`, mainteneur placeholders | mainteneur + `pkgver` propres |
| Firmware WCNSS | paquet `firmware-samsung-milletwifi` (blobs en git) | blobs extraits à la main des partitions | **paquet `firmware-samsung-rubenswifi`** |
| Installation | `pmbootstrap flasher flash_kernel` (fastboot) | Heimdall pour la première image | fastboot |
| Noyau | même dépôt `msm8226-mainline` | idem | idem + accéléromètre + CM3323 |
| Interface | SXMO / Phosh selon l'image | X11 + IceWM + VNC (imposé par l'usage) | conservé |
| Batterie | également absente (même PMIC) | absente | absente, documentée |

**L'installeur « OS_Installer » de Nura n'est pas réutilisable** : il ne vise que
le x86_64 depuis une clé USB live GNOME (16 Go, Internet requis, utilisateur
`user`/`147147`), avec LUKS et choix du bureau. Sur une tablette armv7 sans
démarrage USB, l'équivalent, c'est **notre assistant au premier démarrage** —
dont les étapes sont alignées sur les leurs : Localisation, Utilisateur, Résumé,
Installation.

## 12. Commandes utiles

```sh
# Construire et installer
. ~/pmb-venv/bin/activate
pmbootstrap build linux-postmarketos-qcom-msm8226 --arch armv7
pmbootstrap checksum <paquet>          # après avoir touché un APKBUILD
pmbootstrap install                     # image complète (efface les injections)
pmbootstrap flasher flash_kernel        # lk2nd/fastboot

# Injecter les scripts dans l'image (WSL, en root)
wsl -d Ubuntu -u root -- bash ~/rubens-inject/inject.sh

# Sur la tablette
sudo load-wcnss-fw.sh          # (re)charger les firmwares Wi-Fi
keyboard.sh on|off|etat        # clavier virtuel
orientation.sh paysage|portrait
x11-diag.sh                    # diagnostic affichage/X
nura-assistant                 # assistant (aussi au premier démarrage)
nura-config get|set <clé>      # réglages persistants

# Depuis Windows
ssh dsh@192.168.1.xx                     # clé ed25519, sans mot de passe
ssh dsh@192.168.1.xx "scrot /tmp/x.png" && scp dsh@192.168.1.xx:/tmp/x.png .
```

## 13. Pour la suite

1. Vérifier le signe de `in_accel_z` et le capteur de luminosité après flash.
2. Audio : la carte `msm8226` existe en mainline, mais l'ampli est un **MAX98504**
   et le routage est propre à Samsung — travail de DTS + `qcom-cdc` non trivial.
3. Batterie : sans pilote MAX77804K, aucune information d'énergie ; un
   `power_supply` factice serait mensonger, mieux vaut l'assumer.
4. GPU : `msm` (freedreno) 2D/3D sur APQ8026 demande le support DRM msm8226,
   absent ; `simpledrm` + logiciel restera la règle.
5. Veille : rien à faire sans `power_supply` ni gestion des régulateurs avancée.
