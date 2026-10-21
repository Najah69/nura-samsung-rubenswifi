#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Prepare le DTS du DTB rubenswifi : reset USB et activation du coeur WCNSS.

    entree : $1 DTS        sortie : $2 DTS

Trois corrections, ciblees par NOM de noeud et jamais par numero de phandle
(les phandles changent d'une compilation a l'autre) :

  1. PHY USB. Le noeud declare

         resets = <&gcc 0x0a 0x31 0x00>;
         reset-names = "phy", "por";

     mais ce controleur n'a que deux resets : le "por" en trop fait echouer
     l'attachement du PHY (constat v1 : "ci_hdrc.0 not attached"). On garde
     "phy" seul et on ramene `resets` a ses deux premieres cellules.

  2. remoteproc@fb204000 (coeur WCNSS / pronto) : status "disabled" -> "okay".

  3. le noeud `wcnss` imbrique dans son `smd-edge` (canal SMD + wifi) :
     meme passage a "okay".
"""
import re
import sys


def load(path):
    with open(path, encoding='utf-8') as f:
        return f.read().split('\n')


def save(path, lines):
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


def block(lines, name, start=0, end=None):
    """(ouverture, fermeture, indentation) du noeud `name`, ou None."""
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
                    return i, j, m.group(1)
            return None
    return None


def set_prop(lines, opened, closed, name, value):
    """Remplace la propriete dans [opened, closed], sinon l'insere au debut."""
    pat = re.compile(r'^(\t+)' + re.escape(name) + r' = .*;$')
    for i in range(opened + 1, closed):
        m = pat.match(lines[i])
        if m:
            lines[i] = '%s%s = %s;' % (m.group(1), name, value)
            return 'remplace (ligne %d)' % (i + 1)
    indent = re.match(r'^(\t*)', lines[opened]).group(1) + '\t'
    lines.insert(opened + 1, '%s%s = %s;' % (indent, name, value))
    return 'insere'


def main():
    if len(sys.argv) != 3:
        sys.exit('usage : prep-dts.py entree.dts sortie.dts')
    src, dst = sys.argv[1], sys.argv[2]
    lines = load(src)
    report = []

    # ------------------------------------------------------------- 1. PHY USB
    at = None
    for i, line in enumerate(lines):
        if 'reset-names = "phy", "por";' in line:
            at = i
            break
    if at is None:
        report.append('USB : "phy", "por" absent (deja corrige ?)')
    else:
        for j in range(at - 1, max(at - 12, -1), -1):
            m = re.match(r'^(\t*)resets = <(.*)>;$', lines[j])
            if not m:
                continue
            cells = m.group(2).split()
            if len(cells) > 2:
                lines[j] = '%sresets = <%s>;' % (m.group(1), ' '.join(cells[:2]))
                report.append('USB : resets ramene de %d a 2 cellules (ligne %d)'
                              % (len(cells), j + 1))
            else:
                report.append('USB : resets deja a %d cellules' % len(cells))
            break
        lines[at] = lines[at].replace('reset-names = "phy", "por";',
                                      'reset-names = "phy";')
        report.append('USB : reset-names = "phy" seul')

    # ------------------------------------------------- 2. coeur WCNSS (pronto)
    rp = block(lines, 'remoteproc@fb204000')
    if not rp:
        sys.exit('remoteproc@fb204000 introuvable')
    report.append('remoteproc : status %s'
                  % set_prop(lines, rp[0], rp[1], 'status', '"okay"'))

    # ------------------------------------------------ 3. canal SMD et wlan
    rp = block(lines, 'remoteproc@fb204000')
    smd = block(lines, 'smd-edge', rp[0], rp[1])
    if not smd:
        sys.exit('smd-edge introuvable dans remoteproc')
    wc = block(lines, 'wcnss', smd[0], smd[1])
    if not wc:
        sys.exit('noeud wcnss introuvable dans smd-edge')
    report.append('wcnss : status %s'
                  % set_prop(lines, wc[0], wc[1], 'status', '"okay"'))

    save(dst, lines)
    print('\n'.join('  ' + r for r in report))


if __name__ == '__main__':
    main()
