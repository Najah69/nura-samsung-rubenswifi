#!/usr/bin/env python3
# genere-theme-nura.py : dessine le theme IceWM « Nura » (boutons de fenetre
# grands et contrastes, pour le doigt) dans inject/usr/share/icewm/themes/Nura.
#
#     python3 outils/genere-theme-nura.py [hauteur]     (40 px par defaut)
#
# Chaque bouton est une image XPM de L x 2H : en haut l'etat normal, en bas
# l'etat appuye (convention des themes IceWM). Aucune dependance : le dessin
# est fait pixel par pixel.
import os
import sys

H = int(sys.argv[1]) if len(sys.argv) > 1 else 40
L = H
ICI = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(ICI, "..", "inject", "usr", "share", "icewm", "themes", "Nura")

# Couleurs : (fond normal, fond appuye, symbole) pour la fenetre active (A) et inactive (I).
BLEU_A, BLEU_A2 = "#2f5583", "#1d3657"
GRIS_I, GRIS_I2 = "#6b7380", "#4b525c"
ROUGE_A, ROUGE_A2 = "#c62828", "#8e1b1b"
ROUGE_I, ROUGE_I2 = "#8a5a5a", "#6a4444"
BLANC, BLANC_I = "#ffffff", "#e4e6ea"
TITRE_A, TITRE_I = "#1e3a5f", "#5a6270"   # barres de titre (voir default.theme)


def toile(fond):
	return [[fond] * L for _ in range(H)]


def rect(t, x0, y0, x1, y1, c):
	for y in range(max(0, y0), min(H, y1)):
		for x in range(max(0, x0), min(L, x1)):
			t[y][x] = c


def cadre(t, x0, y0, x1, y1, ep, c):
	rect(t, x0, y0, x1, y0 + ep, c)
	rect(t, x0, y1 - ep, x1, y1, c)
	rect(t, x0, y0, x0 + ep, y1, c)
	rect(t, x1 - ep, y0, x1, y1, c)


def croix(t, marge, ep, c):
	n = H - 2 * marge
	for y in range(H):
		for x in range(L):
			u, v = x - marge, y - marge
			if 0 <= u < n and 0 <= v < n and (abs(u - v) * 0.7071 <= ep / 2 or abs(u + v - (n - 1)) * 0.7071 <= ep / 2):
				t[y][x] = c


def coins(t, fond_titre):
	# Coins arrondis (2 px) pour adoucir le carre sur la barre de titre.
	for (x, y) in ((0, 0), (1, 0), (0, 1), (L - 1, 0), (L - 2, 0), (L - 1, 1),
			(0, H - 1), (1, H - 1), (0, H - 2), (L - 1, H - 1), (L - 2, H - 1), (L - 1, H - 2)):
		t[y][x] = fond_titre


def bouton(forme, fond, symbole, fond_titre):
	t = toile(fond)
	m = H // 4                    # marge du symbole
	ep = max(3, H // 9)           # epaisseur du trait
	if forme == "close":
		croix(t, m + 1, ep + 1, symbole)
	elif forme == "maximize":
		cadre(t, m, m, L - m, H - m, ep, symbole)
	elif forme == "restore":
		d = H // 8
		cadre(t, m + d, m, L - m, H - m - d, ep - 1, symbole)
		rect(t, m, m + d, L - m - d, H - m, fond)
		cadre(t, m, m + d, L - m - d, H - m, ep - 1, symbole)
	elif forme == "minimize":
		rect(t, m, H - m - ep, L - m, H - m, symbole)
	coins(t, fond_titre)
	return t


def xpm(nom, haut, bas):
	pixels = haut + bas
	couleurs = sorted({c for ligne in pixels for c in ligne})
	codes = {c: chr(ord("a") + i) for i, c in enumerate(couleurs)}
	lignes = ['"%d %d %d 1",' % (L, 2 * H, len(couleurs))]
	lignes += ['"%s c %s",' % (codes[c], c) for c in couleurs]
	lignes += ['"%s",' % "".join(codes[c] for c in ligne) for ligne in pixels]
	lignes[-1] = lignes[-1].rstrip(",")
	with open(os.path.join(DEST, nom + ".xpm"), "w", newline="\n") as f:
		f.write("/* XPM */\nstatic char * %s_xpm[] = {\n%s\n};\n" % (nom, "\n".join(lignes)))


os.makedirs(DEST, exist_ok=True)
for forme in ("close", "maximize", "restore", "minimize"):
	if forme == "close":
		a, a2, i, i2 = ROUGE_A, ROUGE_A2, ROUGE_I, ROUGE_I2
	else:
		a, a2, i, i2 = BLEU_A, BLEU_A2, GRIS_I, GRIS_I2
	xpm(forme + "A", bouton(forme, a, BLANC, TITRE_A), bouton(forme, a2, BLANC, TITRE_A))
	xpm(forme + "I", bouton(forme, i, BLANC_I, TITRE_I), bouton(forme, i2, BLANC_I, TITRE_I))
print("theme Nura : boutons %dx%d ecrits dans %s" % (L, H, os.path.normpath(DEST)))
