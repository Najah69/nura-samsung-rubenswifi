#!/usr/bin/env python3
# Fixe explicitement le nom du firmware WCNSS dans le noeud remoteproc.
#
# qcom_wcnss.c fait :
#     ret = of_property_read_string(node, "firmware-name", &fw_name);
#     rproc = devm_rproc_alloc(dev, pdev->name, ops, fw_name, ...);
# Quand la propriete est absente, le nom du firmware retombe sur le nom de la
# plateforme (du genre "fb204000.remoteproc") : le noyau cherche alors un blob
# portant ce nom-la et tous les wcnss.bXX a cote, qui n'existent pas.
# En ecrivant "wcnss.mdt", on impose le nom reel des blobs Samsung.
#
# Entree : $1 DTS   Sortie : $2 DTS modifie
import sys

src, dst = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8").read().split("\n")

start = None
for i, l in enumerate(lines):
    if "remoteproc@fb204000 {" in l:
        start = i
        break
if start is None:
    sys.exit("noeud remoteproc@fb204000 introuvable")

depth, end = 0, None
for i in range(start, len(lines)):
    depth += lines[i].count("{") - lines[i].count("}")
    if depth == 0 and i > start:
        end = i
        break
if end is None:
    sys.exit("fin du noeud introuvable")

body = lines[start:end + 1]
if any("firmware-name" in l for l in body):
    print("  firmware-name deja present : rien a faire")
else:
    anchor = None
    for j, l in enumerate(body):
        if l.strip().startswith("reg-names =") and "pmu" in l:
            anchor = j
            break
    if anchor is None:
        sys.exit('reg-names = "ccu", "dxe", "pmu" introuvable')
    indent = body[anchor][:len(body[anchor]) - len(body[anchor].lstrip())]
    body[anchor + 1:anchor + 1] = [f'{indent}firmware-name = "wcnss.mdt";']
    print(f"  firmware-name insere apres la ligne {start + anchor + 2}")
    lines[start:end + 1] = body

open(dst, "w", encoding="utf-8").write("\n".join(lines))
print(f"  ecrit {dst}")
