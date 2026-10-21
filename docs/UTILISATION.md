# Utilisation au quotidien

Toutes les commandes de cette page se tapent **sur la tablette**, dans un
terminal (icône de la barre des tâches, ou `xterm`), ou à distance par SSH.

---

## Se connecter à la tablette

### Par le câble USB (le plus fiable)

Branchez le câble entre la tablette et l'ordinateur. Le réseau USB s'active tout
seul, sans rien configurer :

| | |
|---|---|
| Tablette | `172.16.42.1` |
| Ordinateur | `172.16.42.2` (DHCP) |

```sh
ssh najah@172.16.42.1
```

Sous Windows, `172.16.42.1` n'apparaît pas dans « Réseau » : c'est normal, c'est
une interface point à point. `ping 172.16.42.1` suffit à vérifier.

### Par le Wi-Fi

L'adresse est affichée par `nura-assistant --menu` → *État de la tablette*, ou
par :

```sh
ip -4 addr show wlan0 | grep inet
```

Puis `ssh najah@<adresse>`.

### Par VNC (l'écran de la tablette dans une fenêtre)

La tablette est le **serveur**, l'ordinateur le **client**. Aucun logiciel à
installer sur la tablette.

1. Connectez-vous en USB ou en Wi-Fi ;
2. ouvrez un client VNC — TightVNC ou RealVNC sous Windows, Remmina ou
   `vncviewer` sous Linux, « Écran partagé » sous macOS ;
3. serveur `172.16.42.1:5900` (USB) ou `<adresse Wi-Fi>:5900` ;
4. mot de passe VNC : `147147` par défaut.

Ce que vous faites dans la fenêtre VNC se voit sur l'écran de la tablette : les
deux sont le même écran, pas une session séparée.

```sh
sudo systemctl status x11vnc        # état
sudo systemctl restart x11vnc       # relancer
sudo x11vnc -storepasswd MONMOTDEPASSE /root/.vnc/passwd   # changer le mot de passe
```

> Le mot de passe VNC est régénéré à chaque démarrage à partir de la valeur
> inscrite dans `/etc/systemd/system/x11vnc.service`. Pour le changer
> durablement, modifiez la ligne `ExecStartPre=-/usr/bin/x11vnc -storepasswd …`.

---

## L'écran

### Retourner l'écran

```sh
orientation.sh paysage
orientation.sh portrait
orientation.sh etat
```

La commande tourne l'affichage **et** recale le tactile (matrice `xinput`). Le
choix est retenu pour le démarrage suivant.

Il y a aussi :
- un **bouton** dans la barre des tâches (icône d'écran qui pivote) ;
- une entrée dans le **menu** IceWM ;
- `nura-assistant --menu` → *Orientation et tactile*.

### Régler la netteté du texte

Le menu IceWM → *Settings* → *Preferences* permet de changer la police. Pour un
affichage plus lisible sur 800 × 1280 :

```sh
setxkbmap fr            # au cas où
xrandr --output None-1 --rotate left    # 1280 × 800
```

### Faire une capture d'écran

```sh
scrot /tmp/ecran.png
```

Puis récupérez-la depuis l'ordinateur :

```sh
scp najah@172.16.42.1:/tmp/ecran.png .
```

---

## Le clavier tactile

```sh
keyboard.sh on        # afficher
keyboard.sh off       # cacher
keyboard.sh etat      # état
```

Le clavier occupe 42 % de la hauteur de l'écran et se place en bas. Il s'affiche
au démarrage si `CLAVIER=on` dans `/etc/nura/assistant.conf`.

**Le clavier cache un bouton ?** Cachez-le le temps de cliquer :
`keyboard.sh off`, clic, `keyboard.sh on`.

**Vous branchez un clavier USB ?** Il est reconnu automatiquement ; le clavier
tactile ne gêne pas, mais vous pouvez le cacher.

---

## Le Wi-Fi

```sh
wifi.sh scan                          # lister les réseaux
wifi.sh connect MON-RESEAU monmotdepasse   # se connecter
wifi.sh status                        # état de la connexion
wifi.sh debug                         # diagnostic complet
```

Détail de `wifi.sh status` : adresse, passerelle, débit, signal.

La configuration est dans `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`
(mot de passe haché). Le service `wpa-wlan0` maintient la connexion et
`wifi-dhcp` demande le bail.

**Le Wi-Fi ne monte pas ?**

```sh
sudo load-wcnss-fw.sh      # réinstalle les firmwares depuis les partitions
sudo systemctl restart wpa-wlan0 wifi-dhcp
```

Le message `expected cold boot completion` est normal, même quand tout marche.

---

## Les clés USB et cartes SD

Le montage est automatique, dans `/media`. Les systèmes de fichiers courants
(vfat, exfat, ntfs, ext4) sont reconnus.

```sh
automount.sh etat          # ce qui est monté
automount.sh tout          # tout monter maintenant
```

Pour retirer une clé, démontez-la d'abord (ou éteignez la tablette).

---

## Les logiciels

```sh
sudo apk update
sudo apk search <mot>
sudo apk add htop
sudo apk del htop
sudo apk upgrade
```

Les dépôts sont ceux de postmarketOS/Nura (`armv7`, canal `systemd-edge`).

Déjà installés, entre autres : `bash`, `nano`, `mc` (Midnight Commander), `git`,
`gcc`, `make`, `python3`, `openssh`, `wpa_cli`, `iw`, `xinput`, `xrandr`,
`scrot`, `netsurf`, `firefox`, `apk`, `whiptail`, `htop`.

### Naviguer sur le Web

- **Netsurf** (menu → *Web* → *Netsurf*) : très léger, pour les sites simples ;
- **Firefox** (menu → *Web* → *Firefox*) : pour les sites modernes, plus lent et
  gourmand en mémoire (1,5 Go seulement).

---

## Diagnostiquer

```sh
x11-diag.sh                 # tout l'affichage : X, sortie, rotation, tactile,
                            # clavier, VNC, réseau
systemctl --failed          # unités en échec (doit être vide)
journalctl -b -p err        # erreurs depuis le démarrage
dmesg | tail -50            # messages du noyau
wifi.sh debug               # Wi-Fi
cat /run/wcnss-fw.log       # chargement des firmwares Wi-Fi
```

### Relancer le bureau

```sh
sudo systemctl restart x11-icewm     # relance X et IceWM
```

Cela ferme les fenêtres ouvertes (rien n'est enregistré automatiquement).

### Éteindre et redémarrer

```sh
sudo poweroff
sudo reboot
```

### Connaître le niveau de la batterie

```sh
batterie.sh          # détail : charge estimée, tension, courant
batterie.sh court    # juste « ≈ 78 % (3.92 V) »
```

La charge n'est **pas pilotée** (le chargeur MAX77804K n'a pas de pilote
mainline) : le pourcentage est **estimé à partir de la tension** lue par le
PM8226. Il est donc approximatif, et pessimiste quand la tablette travaille, car
la tension s'écroule sous charge puis remonte au repos. Il n'y a pas de veille
automatique : la tablette s'éteint d'un coup quand la batterie est vraiment vide.
Pour les longues sessions, gardez le câble branché.

---

## Les fichiers de la tablette

| Chemin | Contenu |
|---|---|
| `/etc/nura/assistant.conf` | réglages de la tablette |
| `/etc/nura/wifi/` | réseaux Wi-Fi mémorisés par l'assistant |
| `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf` | configuration Wi-Fi (mot de passe haché) |
| `/etc/systemd/system/` | unités fournies par le portage |
| `/usr/local/bin/` | les scripts du portage (`orientation.sh`, `wifi.sh`, …) |
| `/home/najah` | votre dossier personnel |
| `/media` | clés USB et cartes SD montées |
| `/boot` | noyau, DTB, initramfs, `extlinux.conf` (partition 1) |

Sauvegarder ses fichiers avant une mise à jour :

```sh
scp -r najah@172.16.42.1:/home/najah/mes-documents .
```
