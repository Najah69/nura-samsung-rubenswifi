#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verifie, dans un DTS, que le sous-systeme Wi-Fi est bien active.

    usage : verif-wcnss.py fichier.dts     (code retour 0 si tout est bon)

Verification par NOM de noeud, jamais par nombre de noeuds actives : elle est
donc valable aussi bien sur un DTB fraichement corrige que sur un DTB deja
corrige (le script de correction est rejoue a chaque image).
"""
import re
import sys


def block(lines, name, start=0, end=None):
    if end is None:
        end = len(lines)
    pat = re.compile(r'^(\t*)' + re.escape(name) + r' \{$')
    for i in range(start, end):
        m = pat.match(lines[i])
        if m:
            depth = 0
            for j in range(i, end):
                depth += lines[j].count('{') - lines[j].count('}')
                if depth == 0:
                    return i, j
            return None
    return None


def has(lines, opened, closed, needle):
    return any(needle in lines[i] for i in range(opened + 1, closed))


def main():
    if len(sys.argv) != 2:
        sys.exit('usage : verif-wcnss.py fichier.dts')
    lines = open(sys.argv[1], encoding='utf-8').read().split('\n')
    fails = []

    rp = block(lines, 'remoteproc@fb204000')
    if not rp:
        sys.exit('  [!!] remoteproc@fb204000 introuvable')

    checks = [
        (rp, 'status = "okay"', 'remoteproc actif'),
        (rp, 'firmware-name = "wcnss.mdt"', 'firmware wcnss.mdt'),
        (rp, 'vddmx-supply', 'alimentation vddmx'),
        (rp, 'vddpx-supply', 'alimentation vddpx'),
        (rp, 'pinctrl-0', 'pinctrl-0'),
    ]
    for (o, c), needle, label in checks:
        if has(lines, o, c, needle):
            print('  [ok]   %s' % label)
        else:
            print('  [!!]   manquant : %s' % label)
            fails.append(label)

    smd = block(lines, 'smd-edge', rp[0], rp[1])
    wc = block(lines, 'wcnss', smd[0], smd[1]) if smd else None
    if not wc:
        print('  [!!]   noeud wcnss introuvable')
        fails.append('wcnss')
    else:
        if has(lines, wc[0], wc[1], 'status = "okay"'):
            print('  [ok]   wcnss actif')
        else:
            print('  [!!]   wcnss inactif')
            fails.append('wcnss')
        if has(lines, wc[0], wc[1], 'qcom,wcnss-wlan'):
            print('  [ok]   interface wlan declaree')
        else:
            print('  [!!]   interface wlan absente')
            fails.append('wlan')

    iris = block(lines, 'iris', rp[0], rp[1])
    if iris:
        for needle, label in [('vddxo-supply', 'iris vddxo'),
                              ('vddrfa-supply', 'iris vddrfa'),
                              ('vddpa-supply', 'iris vddpa'),
                              ('vdddig-supply', 'iris vdddig')]:
            if has(lines, iris[0], iris[1], needle):
                print('  [ok]   %s' % label)
            else:
                print('  [!!]   manquant : %s' % label)
                fails.append(label)
    else:
        print('  [!!]   noeud iris introuvable')
        fails.append('iris')

    if any('reset-names = "phy", "por"' in l for l in lines):
        print('  [!!]   reset "por" du PHY USB encore present')
        fails.append('usb-reset')
    else:
        print('  [ok]   reset "por" du PHY USB absent')

    if not any('function = "wlan"' in l for l in lines):
        print('  [!!]   pinctrl WLAN absent')
        fails.append('pinctrl')
    else:
        print('  [ok]   pinctrl WLAN present')

    if fails:
        print('  ==> %d verification(s) en echec' % len(fails))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
