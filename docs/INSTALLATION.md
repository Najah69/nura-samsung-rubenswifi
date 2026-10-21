# Installation pas à pas

Cette page détaille le flashage, avec les erreurs courantes et leur solution.
Si vous ne lisez qu'une page, lisez plutôt le [README](../README.md) : la
procédure y tient en cinq étapes.

> **Ce que vous risquez.** Flasher une tablette efface tout ce qu'elle contient
> et peut la rendre inutilisable. Sauvegardez vos photos avant. Le portage n'est
> ni édité ni soutenu par Samsung, postmarketOS ou Nura.

---

## 1. Ce qu'il faut

| | |
|---|---|
| La tablette | Samsung Galaxy Tab Active 8.0 **Wi-Fi**, modèle **SM-T360** (au dos, à côté du numéro de série) |
| Un ordinateur | Windows 10/11, Linux ou macOS, avec un port USB |
| Un câble USB | **de données** — beaucoup de câbles ne font que charger et ne détectent jamais la tablette |
| L'image | `samsung-rubenswifi-v1.0.1.img.xz` (~349 Mo compressés, 1,84 Gio une fois décompressé) |
| `lk2nd` | `lk2nd-rubens.img` (300 Ko), le micro-chargeur d'amorçage — **une seule fois** |
| De quoi vérifier | les empreintes SHA-256 sont dans les notes de la version |

**Modèles voisins qui ne conviennent pas** : SM-T365 (version LTE, modem
différent), SM-T360 *sans* « Wi-Fi » n'existe pas, SM-T230/T231 (Tab 4 7.0),
SM-T530 (Tab 4 10.1). Seul le **SM-T360** est concerné.

---

## 2. Décompresser l'image

**Windows** : installez [7-Zip](https://www.7-zip.org/), clic droit sur le
fichier `.img.xz`, *Extraire ici*. Vous obtenez `samsung-rubenswifi-v1.0.1.img`.

**Linux / macOS** :

```sh
unxz samsung-rubenswifi-v1.0.1.img.xz
```

Vérifiez ensuite l'empreinte (facultatif mais recommandé) :

```sh
sha256sum samsung-rubenswifi-v1.0.1.img      # Linux
shasum -a 256 samsung-rubenswifi-v1.0.1.img  # macOS
```

```powershell
Get-FileHash .\samsung-rubenswifi-v1.0.1.img -Algorithm SHA256   # Windows
```

---

## 3. Installer Heimdall

Heimdall est l'outil libre qui parle le protocole du mode download Samsung.
C'est le seul moyen d'écrire sur la tablette : elle n'a pas de fastboot
utilisable avant que `lk2nd` soit en place.

### Linux

```sh
sudo apt install heimdall-flash     # Debian, Ubuntu, Mint
sudo dnf install heimdall           # Fedora
sudo pacman -S heimdall             # Arch
```

### Windows, méthode simple : WSL2

1. Installez WSL2 et Ubuntu (`wsl --install -d Ubuntu`), puis dans Ubuntu :
   `sudo apt install heimdall-flash usbipd`.
2. Installez [usbipd-win](https://github.com/dorssel/usbipd-win/releases) côté
   Windows, puis dans PowerShell **administrateur**, tablette branchée en mode
   download :

   ```powershell
   usbipd list                       # repérer le busid de "Samsung ... 04e8:685d"
   usbipd bind   --busid 4-2
   usbipd attach --wsl --busid 4-2
   ```

3. Dans Ubuntu, `heimdall detect` doit alors répondre `Device detected`.

### Windows, méthode directe : pilote WinUSB

1. Téléchargez Heimdall 1.4.2 pour Windows et [Zadig](https://zadig.akeo.ie/).
2. Tablette en mode download, lancez Zadig, *Options → List All Devices*,
   choisissez `Samsung USB Composite Device` (ou `Gadget Serial`), sélectionnez
   **WinUSB** et cliquez *Install Driver*.
3. `heimdall.exe detect` doit répondre `Device detected`.

> Le pilote Samsung officiel (Kies / Smart Switch) **empêche** Heimdall de
> fonctionner : désinstallez-le si `heimdall detect` échoue avec un appareil
> pourtant visible dans le gestionnaire de périphériques.

---

## 4. Mettre la tablette en mode download

1. Éteignez complètement la tablette.
2. Maintenez **Volume bas + Home + Power** jusqu'à l'apparition d'un écran
   d'avertissement.
3. Appuyez sur **Volume haut** pour confirmer : l'écran « Downloading… » apparaît
   (fond bleu-vert, triangle Android).

Branchez le câble. `heimdall detect` doit voir la tablette.

---

## 5. Flasher `lk2nd` (une seule fois par tablette)

```sh
heimdall flash --BOOT lk2nd-rubens.img --no-reboot
```

`lk2nd` est un chargeur d'amorçage minimal qui remplace celui de Samsung dans la
partition `BOOT`. Il sait lire `extlinux.conf` sur la partition système, ce que
le chargeur d'origine ne sait pas faire — sans lui, aucun noyau Linux moderne ne
démarrerait sur cette tablette.

> **Pourquoi `BOOT` et pas un `boot.img` ?** La partition `BOOT` du SM-T360 fait
> **10 Mio** : elle est trop petite pour un `boot.img` complet (19 Mio avec
> l'initramfs). D'où le couple `lk2nd` (300 Ko dans `BOOT`) + noyau, DTB et
> initramfs rangés dans `/boot` de la partition système.

Si la tablette a déjà `lk2nd` (mise à jour d'une image précédente), **sautez
cette étape**.

---

## 6. Flasher le système

```sh
heimdall flash --USERDATA samsung-rubenswifi-v1.0.1.img --no-reboot
```

L'écriture dure 1 à 3 minutes (1,74 Gio). Ne débranchez pas.

Puis redémarrez :

```sh
heimdall close-pc-screen --resume
```

La tablette redémarre. Si elle reste sur l'écran « Downloading… », maintenez
**Power** 10 secondes, puis rallumez.

> **L'image va dans `USERDATA`**, la partition des données (11,1 Gio sur cette
> tablette). Au premier démarrage, le système agrandit automatiquement sa
> partition racine pour occuper tout l'espace libre : l'image fait 1,74 Gio, le
> système en occupe 11.

---

## 7. Premier démarrage

Comptez **1 à 3 minutes** : le noyau démarre, l'initramfs cherche la partition
racine, puis X et IceWM se lancent.

Vous verrez, dans l'ordre : le logo Samsung, un écran noir (normal), puis un
bureau gris clair avec une barre des tâches en bas et **le clavier tactile**.

Si l'écran reste noir plus de 5 minutes, voir la section suivante.

Au tout premier démarrage, un **assistant** s'ouvre et vous guide : langue du
clavier, fuseau horaire, nom de la tablette, compte et mot de passe, Wi-Fi,
réseau USB, orientation. Voir [PREMIER-DEMARRAGE.md](PREMIER-DEMARRAGE.md).

---

## 8. Quand ça ne marche pas

### `heimdall detect` ne voit rien

| Cause | Solution |
|---|---|
| Câble de charge seule | essayez un autre câble, de préférence celui d'origine |
| Pilote Samsung installé (Windows) | désinstallez Kies/Smart Switch, réinstallez WinUSB avec Zadig |
| Port USB 3 / hub | branchez directement sur un port USB 2 du PC |
| Tablette pas en mode download | recommencez Volume bas + Home + Power, puis Volume haut |
| Sous WSL, `usbipd attach` fait | relancez `usbipd attach --wsl --busid <n>` après chaque rebranchement |

### `ERROR: Failed to receive PIT file`

Le protocole n'a pas démarré : la tablette n'est pas réellement en mode
download, ou le câble ne transporte pas de données. Rebranchez, relancez
`heimdall detect`, puis réessayez.

### `libusb error -7` / `Claiming interface failed` / `Timeout`

Un autre programme utilise la tablette (Kies, Odin, un navigateur, `adb`).
Fermez-les. Sous Windows, débranchez/rebranchez. Sous WSL, refaites
`usbipd detach` puis `attach`.

### `Heimdall` échoue à 90 % ou l'écriture s'arrête

L'image est peut-être corrompue : revérifiez son SHA-256. Sinon, le câble ou le
port sont en cause ; réessayez sur un autre port. Un échec en cours d'écriture
n'abîme rien de définitif : la tablette reste en mode download, il suffit de
recommencer.

### La tablette démarre mais l'écran reste noir

1. Attendez 5 minutes (le premier démarrage écrit beaucoup sur l'eMMC, qui est
   lente).
2. Branchez le câble USB et essayez `ssh najah@172.16.42.1` (mot de passe
   `147147`) : si vous entrez, le système tourne et c'est l'affichage qui coince.
   Lancez alors `sudo x11-diag.sh` et lisez la sortie.
3. Touchez l'écran : s'il réagit (le clavier apparaît), X tourne et c'est le
   rétroéclairage qui est resté au minimum. Le portage ne pilote pas encore la
   luminosité (voir les limites dans le README).

### Le tactile est décalé

Il suit la rotation : `orientation.sh paysage` (ou `portrait`) réapplique la
matrice. Voir [UTILISATION.md](UTILISATION.md).

### Le Wi-Fi ne trouve aucun réseau

```sh
sudo load-wcnss-fw.sh      # réinstalle les firmwares WCNSS depuis les partitions
wifi.sh scan               # nouvelle recherche
```

Le message `qcom_wcnss_ctrl … expected cold boot completion` dans le journal est
normal : il apparaît même quand le Wi-Fi fonctionne.

---

## 9. Mettre à jour sans tout réinstaller

Une nouvelle version se flashe **dans `USERDATA` uniquement**, sans toucher à
`lk2nd` :

```sh
heimdall flash --USERDATA samsung-rubenswifi-v1.1.img --no-reboot
heimdall close-pc-screen --resume
```

Cela efface les données de la tablette (photos, réglages, paquets installés).
Pour ne pas perdre vos fichiers, sauvegardez-les avant sur une carte SD ou par
SSH (`scp`).

---

## 10. Revenir à Android

Il faut reflasher un firmware Samsung d'origine pour le SM-T360 avec **Odin**
(Windows) et le fichier `.tar.md5` correspondant, trouvé chez Samsung ou chez un
hébergeur de firmwares. L'opération remet la tablette dans son état d'usine, y
compris le chargeur d'amorçage. Elle n'est pas décrite ici : elle dépend
entièrement du firmware que vous téléchargez.
