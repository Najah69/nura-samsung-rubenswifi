# État final de la v2 — Galaxy Tab Active 8.0 Wi-Fi (SM-T360)

Écrit le 21/10/2026. Remplace, pour la v2, l'`ETAT-FINAL.md` de `v1-2026-10-21/docs/`.

Ce document dit **ce qui a été mesuré sur la tablette**, pas ce qui était prévu.
Quand quelque chose ne marche pas, c'est écrit.

---

## 1. Résumé en une phrase

La tablette tourne sous Nura (postmarketOS) avec X11 + IceWM, Wi-Fi, clavier
virtuel, rotation paysage avec tactile recalé, VNC et réseau par câble USB.
Elle est utilisable tous les jours **comme serveur VNC piloté depuis le PC**, ce
qui était l'objectif. Elle n'est **pas** un portage complet : ni audio, ni
batterie, ni Bluetooth, ni caméra, ni accélération graphique.

## 2. Images

Toutes font **1 872 756 736 octets** et se flashent dans la partition
`USERDATA` (`mmcblk0p26`). Le dossier `image/` contient une empreinte SHA-256 par
version.

| Version | SHA-256 | Ce qu'elle vaut |
|---|---|---|
| v2.1 | `519576eb…0d1b068` | **à jeter** : Wi-Fi mort (DTB sans WCNSS) + boucle de redimensionnement de l'assistant |
| v2.2 | `510e080b…54aed57` | **flashée le 21/10** ; Wi-Fi et tactile paysage réparés, VNC et assistant encore fautifs |
| v2.3 | `d1817466…5b939959` | corrections VNC et assistant ; texte USB erroné, second serveur DHCP |
| **v2.4** | **`c82cdccb…27872c19`** | **version de référence** : tout ce qui suit a été vérifié avec ces scripts |

L'image v2.4 et la tablette portent **les mêmes scripts**. La différence est dans
`/var/lib/nura` : la tablette a déjà passé l'assistant (nom `ruGalaxiTab`,
mot de passe choisi, orientation paysage mémorisée), l'image repart neuve.

## 3. Ce qui marche, avec la preuve

| Fonction | Preuve relevée sur la tablette |
|---|---|
| Démarrage | lk2nd → extlinux → noyau 6.16.12-r4 → X11 ; aucun service en échec |
| Wi-Fi | `MON-RESEAU` sur **5640 MHz** (5 GHz), −48 dBm, 150 Mbit/s, `192.168.1.xx/24`, ping passerelle 0 % |
| Pilote Wi-Fi | `remoteproc0` *running*, `wcn36xx`, MAC `02:00:00:00:00:00`, API firmware 1.5.1.2 |
| Affichage | `1280 × 800`, sortie `None-1` en `left`, profondeur 24/32 |
| Tactile | Synaptics S5707 (id 7), matrice `0 -1 1 1 0 0 0 0 1` appliquée dans le repère paysage |
| Clavier virtuel | `matchbox-keyboard` AZERTY, 42 % de la hauteur, toutes les rangées |
| VNC | `x11vnc` sur 5900, `fb_depth/fb_bpp/fb_Bpl 24/32/3200`, accès avec le mot de passe le mot de passe VNC (147147 par defaut) |
| Réseau USB | gadget `g1` / `ncm.usb0` lié à `ci_hcrc.0`, `unudhcpd@usb0` actif, tablette `172.16.42.1`, PC `172.16.42.2` |
| Assistant | terminé le 21/10 à 05:04:12 (`/var/lib/nura/assistant.done`), relancé une fois à la main vers 05:05 pour vérifier le tactile, une seule mise en place de l'écran, pas de boucle |
| Montage USB | clés et cartes montées dans `/media` (`automount.sh`) |
| Outils | bash, nano, mc, git, curl, build-base, netsurf, firefox |

Mémoire : 1412 Mo au total, dont 1061 Mo libres au repos.

## 4. Ce qui ne marche pas

| Absent | Raison |
|---|---|
| Audio | aucun pilote mainline (MAX98504) ; `/dev/snd` ne contient que `timer` |
| Batterie / charge | jauge et chargeur MAX77804K sans pilote ; pas de `/sys/class/power_supply` |
| Accéléromètre | `st,lis2hh12` déclaré en DTS, mais **non testé** (voir §6) |
| Luminosité | `CONFIG_CM3323=m` compilé, **non testé** |
| Bluetooth, GPS, caméra, NFC | aucun pilote |
| Accélération graphique | `simpledrm` seulement, rendu logiciel |
| Veille / suspend | refusée : sans `power_supply` ni gestion des régulateurs, ce serait pire que rien |
| **Port série USB** | le gadget ne déclare que `ncm.usb0` ; pas de `/dev/ttyGS0` |
| HDMI / MHL | non pris en charge |

## 5. Accès à la tablette

| Voie | Comment |
|---|---|
| Wi-Fi (fonctionne) | `ssh dsh@192.168.1.xx` (mot de passe `MOTDEPASSE`) ou `ssh najah@…` (le mot de passe VNC (147147 par defaut)), VNC `192.168.1.xx:5900` |
| Câble USB (fonctionne) | brancher, puis `ssh dsh@172.16.42.1`, VNC `172.16.42.1:5900` |
| Écran tactile | IceWM + `matchbox-keyboard` |
| Série USB | **non disponible** |

Comptes : `najah` (uid 10000, `wheel`) et `dsh` (uid 1001), tous deux avec
`NOPASSWD: ALL` ; root verrouillé. VNC : le mot de passe VNC (147147 par defaut). **X tourne en root**, donc les
entrées de menu IceWM ont les droits d'administration.

Nom retenu par l'assistant : **`GalaxiTab`** (`/etc/hostname`). Le nom en cours
d'exécution reste `ruGalaxiTab` jusqu'au prochain démarrage : c'est normal,
l'assistant écrit le fichier sans renommer la machine à chaud (le faire casse
l'authentification de VNC).

## 6. À vérifier au prochain allumage

1. **Accéléromètre** : à plat, écran vers le haut, `in_accel_z` doit être positif
   (`/sys/bus/iio/devices/iio:device*/in_accel_z_raw`). Sinon inverser la 3ᵉ ligne
   de `mount-matrix` dans le DTS et reconstruire le noyau.
2. **Luminosité** : `in_illuminance_raw` doit varier quand on couvre la dalle.
3. **Clé USB** : montage automatique, ouverture par le menu Nura → Fichiers.
4. **Reboot à froid** : Wi-Fi, paysage, tactile, clavier et VNC doivent revenir
   sans aucune manipulation.

## 7. Reflasher

```powershell
# 1. tablette en mode download : Vol Bas + Home + Power, puis Vol Haut
# 2. attacher le peripherique a WSL (cote Windows)
usbipd attach --wsl -b 4-2
# 3. flasher la version voulue (empreinte verifiee avant l'envoi)
wsl -d Ubuntu -u root -- bash /mnt/c/Users/Najah/CraftMCP/rubens-pmOS/v2-2026-10-21/outils/flash-userdata.sh v2.4
```

Le script vérifie d'abord l'empreinte SHA-256 contre `SHA256SUMS-v2.4.txt`,
appelle `heimdall flash --USERDATA … --no-reboot`, puis
`heimdall close-pc-screen --resume`. Le transfert prend environ deux minutes et
**efface tout** : l'assistant redemandera nom, mot de passe, orientation, Wi-Fi.
Sans argument, le script flashe l'image de travail de `pmbootstrap`.

## 8. Dossier

```
v2-2026-10-21/
├── ETAT-FINAL.md          ce document
├── pmaports/              les trois paquets (device, firmware, noyau)
├── inject/                tout ce qui est copié dans l'image (scripts, units, config)
├── outils/                vérifications (prep-dts.py, verif-wcnss.py, add-wcnss-fname.py…)
└── image/                 les images et leurs empreintes
```

`inject.sh` fait tout : il installe les fichiers, réécrit le DTB pour le Wi-Fi,
vérifie, et refuse d'écrire si un contrôle échoue.

> **Attention à l'espace disque** : quatre images de 1,87 Go = 7,5 Go. Seules
> **v2.2** (ce qui a été flashé) et **v2.4** (référence) méritent d'être gardées.

## 9. Pièges à ne pas réapprendre

- `ci_hcrc.0 … not attached` = **pas de câble**, pas un gadget cassé.
- Ne jamais lancer `dnsmasq` en plus d'`unudhcpd@usb0` : deux serveurs DHCP sur
  la même interface. `reseau-usb.sh` ne le fait plus qu'en secours.
- Xorg garde son cookie dans `/root/.serverauth.<pid>` (lu dans `/proc`), **pas**
  dans `/root/.Xauthority`.
- Changer le nom d'hôte à chaud périme l'entrée `nom/unix:0` du cookie et casse
  VNC : l'assistant écrit `/etc/hostname` **sans** appeler `hostname`.
- Une seule mise en place de l'écran par l'assistant, sinon boucle de
  redimensionnement avec le clavier.
- `wcnss-dtb.sh` est idempotent : le relancer ne casse rien, et il refuse
  d'écrire si un des contrôles WCNSS échoue.
