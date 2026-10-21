#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Configure le sous-systeme Wi-Fi (WCNSS / pronto) du DTB rubenswifi comme le
fait la Galaxy Tab 4 (matisse), meme SoC APQ8026 et meme puce WCN3660A :

  vddmx  <- pm8226_l3     vddpx  <- pm8226_l6
  iris : vddxo <- l10, vddrfa <- l24, vddpa <- l16, vdddig <- l24
  pinctrl wcnss_pin_a : gpio40..44, fonction "wlan"

Objectif : le 20/10/2026 le noyau chargeait bien wcnss.mdt mais le coeur ne
signalait jamais "ready" (qcom-wcnss-pil: start timed out, -110). Les alimentations
etaient de faux regulator-fixed et le pinctrl WLAN absent.

Entree/sortie : DTS texte produit par dtc.
"""
import re
import sys

PH = re.compile(r'phandle = <(0x[0-9a-fA-F]+)>')


def load(path):
    with open(path, encoding='utf-8') as f:
        return f.read().split('\n')


def save(path, lines):
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


def used_phandles(lines):
    out = set()
    for line in lines:
        m = PH.search(line)
        if m:
            out.add(int(m.group(1), 16))
    return out


def find_block(lines, name, start=0, end=None):
    """(open_idx, close_idx, indent) du noeud `name` ; None si absent."""
    if end is None:
        end = len(lines)
    pat = re.compile(r'^(\t*)' + re.escape(name) + r' \{$')
    for i in range(start, end):
        m = pat.match(lines[i])
        if m:
            indent = m.group(1)
            closing = indent + '};'
            for j in range(i + 1, end):
                if lines[j] == closing:
                    return i, j, indent
            return None
    return None


def prop(lines, open_idx, close_idx, name):
    """valeur de la propriete, ou None."""
    pat = re.compile(r'^\t+' + re.escape(name) + r' = (.*);$')
    for i in range(open_idx + 1, close_idx):
        m = pat.match(lines[i])
        if m:
            return m.group(1)
    return None


def drop_props(lines, open_idx, close_idx, names):
    pat = re.compile(r'^\t+(' + '|'.join(re.escape(n) for n in names) + r') = ')
    keep = []
    removed = []
    for i, line in enumerate(lines):
        if open_idx < i < close_idx and pat.match(line):
            removed.append(line.strip())
            continue
        keep.append(line)
    return keep, removed


def insert_after(lines, index, indent, props):
    """Insere des proprietes juste apres la ligne `index`."""
    block = ['%s%s = %s;' % (indent, k, v) for k, v in props]
    return lines[:index + 1] + block + lines[index + 1:]


def give_phandle(lines, node_name, number, where):
    """Ajoute phandle = <number> au noeud node_name (children de `where`)."""
    found = find_block(lines, node_name, where[0], where[1])
    if not found:
        return lines, None
    o, c, indent = found
    current = prop(lines, o, c, 'phandle')
    if current is not None:
        return lines, int(current.strip('<> '), 16)
    child = indent + '\t'
    lines = lines[:c] + ['%sphandle = <0x%x>;' % (child, number)] + lines[c:]
    return lines, number


def main():
    src, dst = sys.argv[1], sys.argv[2]
    lines = load(src)
    report = []

    # ---------------------------------------------------------------- remoteproc
    rp = find_block(lines, 'remoteproc@fb204000')
    if not rp:
        sys.exit('remoteproc@fb204000 introuvable')
    rp_o, rp_c, rp_ind = rp
    rp_child = rp_ind + '\t'

    # ------- alimentations reelles : on lit les phandles des noeuds pm8226
    regs = find_block(lines, 'regulators')
    if not regs:
        sys.exit('noeud regulators introuvable')
    reg_o, reg_c, _ = regs

    need = 0x6e
    used = used_phandles(lines)

    def next_ph():
        nonlocal need
        while need in used:
            need += 1
        used.add(need)
        return need

    ph_l3 = next_ph()
    ph_l16 = next_ph()
    ph_pin = next_ph()
    ph_l24 = next_ph()

    lines, got_l3 = give_phandle(lines, 'l3', ph_l3, (reg_o, reg_c))
    # le decalage a change : on recalcule les bornes
    regs = find_block(lines, 'regulators')
    reg_o, reg_c, _ = regs
    lines, got_l16 = give_phandle(lines, 'l16', ph_l16, (reg_o, reg_c))
    regs = find_block(lines, 'regulators')
    reg_o, reg_c, _ = regs
    lines, got_l24 = give_phandle(lines, 'l24', ph_l24, (reg_o, reg_c))

    # l6 / l10 ont deja un phandle (utilises par sdhc1 / usb)
    regs = find_block(lines, 'regulators')
    reg_o, reg_c, _ = regs
    f = find_block(lines, 'l6', reg_o, reg_c)
    ph_l6 = prop(lines, f[0], f[1], 'phandle') if f else None
    f = find_block(lines, 'l10', reg_o, reg_c)
    ph_l10 = prop(lines, f[0], f[1], 'phandle') if f else None
    if not ph_l6 or not ph_l10:
        sys.exit('phandle l6/l10 introuvable')
    ph_l6 = int(ph_l6.strip('<> '), 16)
    ph_l10 = int(ph_l10.strip('<> '), 16)
    report.append('l3=0x%x l6=0x%x l10=0x%x l16=0x%x l24=0x%x pin=0x%x'
                  % (got_l3 or 0, ph_l6, ph_l10, got_l16 or 0, got_l24 or 0, ph_pin))

    # ------- on repart des bornes a jour
    rp = find_block(lines, 'remoteproc@fb204000')
    rp_o, rp_c, rp_ind = rp
    rp_child = rp_ind + '\t'

    lines, drop1 = drop_props(lines, rp_o, rp_c,
                              ['vddmx-supply', 'vddpx-supply',
                               'pinctrl-names', 'pinctrl-0'])
    if drop1:
        report.append('anciennes proprietes retirees : %s' % ', '.join(drop1))

    rp = find_block(lines, 'remoteproc@fb204000')
    rp_o, rp_c, rp_ind = rp
    rp_child = rp_ind + '\t'
    anchor = None
    for i in range(rp_o + 1, rp_c):
        if lines[i].strip() == 'power-domain-names = "cx";':
            anchor = i
            break
    if anchor is None:
        anchor = rp_o  # a defaut : debut du noeud
    lines = insert_after(lines, anchor, rp_child, [
        ('vddmx-supply', '<0x%x>' % (got_l3 or 0)),
        ('vddpx-supply', '<0x%x>' % ph_l6),
        ('pinctrl-names', '"default"'),
        ('pinctrl-0', '<0x%x>' % ph_pin),
    ])
    report.append('pronto : vddmx<-l3, vddpx<-l6, pinctrl-0<-wcnss-pin-a')

    # ------- iris : alimentations RF
    rp = find_block(lines, 'remoteproc@fb204000')
    rp_o, rp_c, _ = rp
    iris = find_block(lines, 'iris', rp_o, rp_c)
    if not iris:
        sys.exit('noeud iris introuvable')
    ir_o, ir_c, ir_ind = iris
    lines, drop2 = drop_props(lines, ir_o, ir_c,
                              ['vddxo-supply', 'vddrfa-supply',
                               'vddpa-supply', 'vdddig-supply'])
    if drop2:
        report.append('iris : anciennes proprietes retirees : %s' % ', '.join(drop2))
    iris = find_block(lines, 'iris', rp_o, rp_c)
    ir_o, ir_c, ir_ind = iris
    anchor = None
    for i in range(ir_o + 1, ir_c):
        if lines[i].strip() == 'clock-names = "xo";':
            anchor = i
            break
    if anchor is None:
        anchor = ir_o
    lines = insert_after(lines, anchor, ir_ind + '\t', [
        ('vddxo-supply', '<0x%x>' % ph_l10),
        ('vddrfa-supply', '<0x%x>' % (got_l24 or 0)),
        ('vddpa-supply', '<0x%x>' % (got_l16 or 0)),
        ('vdddig-supply', '<0x%x>' % (got_l24 or 0)),
    ])
    report.append('iris : vddxo<-l10, vddrfa<-l24, vddpa<-l16, vdddig<-l24')

    # ------- pinctrl WLAN (gpio40..44) sous pinctrl@fd510000
    tl = find_block(lines, 'pinctrl@fd510000')
    if not tl:
        sys.exit('pinctrl@fd510000 introuvable')
    tl_o, tl_c, tl_ind = tl
    if find_block(lines, 'wcnss-pin-a', tl_o, tl_c):
        report.append('wcnss-pin-a deja present')
    else:
        child = tl_ind + '\t'
        block = [
            child + 'wcnss-pin-a {',
            child + '\tphandle = <0x%x>;' % ph_pin,
            child + '\tpins = "gpio40", "gpio41", "gpio42", "gpio43", "gpio44";',
            child + '\tfunction = "wlan";',
            child + '\tdrive-strength = <6>;',
            child + '\tbias-pull-down;',
            child + '};',
        ]
        # insere avant la fermeture du controleur de pinctrl
        lines = lines[:tl_c] + block + lines[tl_c:]
        report.append('wcnss-pin-a ajoute (gpio40..44, fonction wlan)')

    # ------- on supprime les faux regulateurs fixes (plus referencer)
    for stub in ('wcnss-vddmx', 'wcnss-vddpx'):
        b = find_block(lines, stub)
        if b:
            o, c, _ = b
            del lines[o:c + 1]
            report.append('noeud factice supprime : %s' % stub)

    save(dst, lines)
    print('\n'.join('  ' + r for r in report))


if __name__ == '__main__':
    main()
