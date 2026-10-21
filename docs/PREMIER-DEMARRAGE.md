# Le premier démarrage

Au tout premier démarrage, la tablette ouvre **elle-même** un assistant : pas de
ligne de commande à taper, tout se fait au doigt.

```
Assistant Nura
Configuration de la tablette
```

Onze étapes, dans cet ordre. Vous pouvez revenir en arrière à tout moment en
relançant `nura-assistant --menu`.

---

## 1. Bienvenue

Un écran de présentation rappelle ce qui est configuré et pourquoi. Il propose de
commencer.

## 2. Clavier et langue

```
Disposition du clavier
  fr   Français (AZERTY)
  us   Anglais (QWERTY)
  de   Allemand (QWERTZ)
  es   Espagnol
  ar   Arabe
```

Choisissez `fr` si vous utilisez un clavier AZERTY. Le choix s'applique
immédiatement, y compris au clavier tactile, et il est enregistré : il sera
rechargé au démarrage suivant.

## 3. Fuseau horaire

Une liste des fuseaux les plus courants (`Europe/Paris`, `Europe/London`,
`America/Montreal`, `Africa/Casablanca`, …). L'horloge de la tablette est ensuite
à la bonne heure, ce qui compte pour le Wi-Fi (WPA2 refuse un certificat
d'horloge absurde) et pour les fichiers.

## 4. Nom de la tablette

C'est le nom qu'elle porte sur le réseau (`rubenswifi` par défaut, mais aussi
`GalaxiTab` ou ce que vous voulez). Lettres, chiffres et tirets uniquement.

## 5. Compte et mot de passe

```
Nom du compte utilisateur (minuscules)   : najah
Mot de passe de najah                    : ••••••
Répétez le mot de passe                  : ••••••
```

C'est le compte que vous utiliserez pour `ssh`, pour `sudo` et pour installer
des paquets. Il est créé s'il n'existe pas, ajouté aux groupes `wheel`, `audio`,
`video`, `netdev` et `plugdev`, et autorisé à utiliser `sudo` sans mot de passe
(comme sur postmarketOS).

> **Choisissez un mot de passe maintenant.** L'image publiée a `147147` partout
> (comptes et VNC) : c'est la convention postmarketOS, elle a l'avantage d'être
> annoncée et d'être la même pour tout le monde, donc de ne tromper personne.

Le clavier tactile s'affiche pendant la saisie et l'assistant **rétrécit sa
propre fenêtre** pour que les boutons restent visibles.

## 6. Wi-Fi

La tablette balaie les réseaux, puis affiche :

```
Choisissez votre reseau Wi-Fi (7 detectes)
  MON-RESEAU        58 %  WPA2
  Livebox-4F21      41 %  WPA2
  FREEBOX_1234      22 %  WPA2
  (autre reseau…)
```

Choisissez votre réseau, puis donnez le mot de passe. Il est enregistré
**haché** (`wpa_passphrase`), jamais en clair, et la connexion est lancée
immédiatement. Si le réseau est masqué, l'entrée *autre réseau* permet de taper
son nom.

En cas d'échec, l'assistant explique quoi vérifier (`wifi.sh scan`,
`wifi.sh debug`).

## 7. Réseau par câble USB

Rien à configurer : l'assistant vérifie que le gadget est armé et explique que le
réseau s'active **tout seul** dès que le câble est branché. Le PC reçoit
l'adresse `172.16.42.2` et joint la tablette en `172.16.42.1`.

C'est le filet de sécurité : même sans Wi-Fi, on peut se connecter.

## 8. Cartes SD et clés USB

Rappel du montage automatique (dans `/media`) et du fait que les clés sont
retirées proprement. Rien à faire.

## 9. Clavier tactile

Active ou désactive le clavier à l'écran **au démarrage**. Utile si vous utilisez
un clavier physique ou si le clavier vous gêne : `keyboard.sh on|off` fait la
même chose à tout moment.

## 10. Orientation et tactile

```
Orientation de l'ecran
  Portrait   (repere natif de la dalle, tactile sans correction)
  Paysage    (comme la coque de la tablette, tactile recale)
```

Le **portrait** est proposé en premier parce que c'est le repère natif : le
tactile est juste sans aucune correction, donc rien ne peut se passer mal. Le
**paysage** applique la rotation de l'écran *et* la matrice du tactile ; c'est le
mode naturel quand la tablette est dans sa coque.

Vous pouvez changer d'avis à tout moment avec `orientation.sh paysage`.

## 11. Résumé

L'assistant relit les choix et affiche de quoi se connecter :

```
Compte        : najah
Wi-Fi         : MON-RESEAU (192.168.1.42)
Reseau USB    : 172.16.42.1
Depuis l'ordinateur  : ssh najah@172.16.42.1
VNC                  : 172.16.42.1:5900
```

Il termine en écrivant `/var/lib/nura/assistant.done` : c'est ce fichier qui
empêche l'assistant de se relancer au démarrage suivant.

---

## Revenir sur un réglage

```sh
nura-assistant --menu      # menu des onze réglages
nura-assistant --reset     # tout reprendre depuis le début
nura-assistant --scan      # liste les réseaux Wi-Fi vus (diagnostic)
```

Le menu permet de modifier un seul réglage : clavier, fuseau, nom, compte,
Wi-Fi, réseau USB, montage, clavier tactile, orientation, tout reconfigurer, ou
afficher l'**état de la tablette** (nom, modèle, noyau, adresse Wi-Fi, écran,
batterie, assistant).

## En ligne de commande

Les mêmes réglages, sans interface :

```sh
nura-config list                     # tous les réglages
nura-config get ORIENTATION          # une valeur
nura-config set NOM matablette       # changer une valeur
```

Fichiers :

| | |
|---|---|
| `/etc/nura/assistant.conf` | les réglages (clé=valeur) |
| `/etc/nura/wifi/` | les réseaux Wi-Fi mémorisés par l'assistant |
| `/var/lib/nura/assistant.done` | l'assistant a été terminé (date) |
| `/var/log/nura-assistant.log` | journal de l'assistant |
| `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf` | le fichier lu par `wpa_supplicant` |
