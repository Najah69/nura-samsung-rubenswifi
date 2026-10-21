#!/bin/sh
# Attend que wpa_supplicant (service wpa-wlan0) ait associe wlan0 au reseau
# enregistre dans /etc/wpa_supplicant/wpa_supplicant-wlan0.conf, puis demande un
# bail DHCP avec udhcpc. Le supplicant est un service a part : ici on ne fait que
# surveiller son etat, donc rien ne le tue quand ce script sort.
# Journal : /run/wifi-direct.log (affiche par x11-diag.sh au demarrage).
set -u

IF=wlan0
LOG=/run/wifi-direct.log
CTRL=/run/wpa_supplicant
DHCP=/usr/share/udhcpc/default.script

log() { printf '%s\n' "$*" >>"$LOG"; printf '%s\n' "$*"; }
wpa_state() { wpa_cli -p "$CTRL" -i "$IF" status 2>/dev/null | sed -n 's/^wpa_state=//p'; }

: >"$LOG"
log "=== wifi-dhcp : demarrage $(date -u '+%Y-%m-%d %H:%M:%S') UTC ==="

# 1. Attendre la carte.
i=0
while [ "$i" -lt 60 ] && [ ! -e "/sys/class/net/$IF" ]; do
	sleep 2
	i=$((i + 1))
done
if [ ! -e "/sys/class/net/$IF" ]; then
	log "[ECHEC] $IF absent apres 120 s - voir /run/wcnss-fw.log"
	exit 1
fi
log "[ok] $IF present, adresse $(cat "/sys/class/net/$IF/address" 2>/dev/null)"

# 2. Attendre l'association (3 min au plus). Etat note toutes les 30 s.
i=0
state=""
while [ "$i" -lt 90 ]; do
	state=$(wpa_state)
	[ "$state" = "COMPLETED" ] && break
	i=$((i + 5))
	if [ $((i % 30)) -eq 0 ]; then
		log "  attente... wpa_state=${state:-<pas de reponse>}"
	fi
	sleep 5
done
log "association : wpa_state=${state:-<pas de reponse>} $(wpa_cli -p "$CTRL" -i "$IF" status 2>/dev/null |
	sed -n 's/^\(ssid\|key_mgmt\|freq\)=/\1=/p' | tr '\n' ' ')"

if [ "$state" != "COMPLETED" ]; then
	log "[ECHEC] pas d'association au reseau enregistre. Diagnostic :"
	log "  service wpa-wlan0 : $(systemctl is-active wpa-wlan0 2>/dev/null)"
	log "  socket de controle : [$(ls "$CTRL" 2>/dev/null | tr '\n' ' ')]"
	log "  supplicants : $(ps 2>/dev/null | grep -c '[w]pa_supplicant')"
	wpa_cli -p "$CTRL" -i "$IF" scan >/dev/null 2>&1
	sleep 4
	log "  reseaux vus : [$(wpa_cli -p "$CTRL" -i "$IF" scan_results 2>/dev/null |
		sed -n '2,7p' | awk -F'\t' '{print $5}' | tr '\n' ' ')]"
	log "  trace du supplicant (journal) :"
	journalctl -u wpa-wlan0 -n 10 -o cat 2>/dev/null | cut -c1-96 |
		while IFS= read -r l; do
			log "    $l"
		done
	exit 1
fi

# 3. Bail DHCP (udhcpc reste en tache de fond pour renouveler).
udhcpc -i "$IF" -b -s "$DHCP" -p "/run/udhcpc-$IF.pid" >>"$LOG" 2>&1
i=0
addr=""
while [ "$i" -lt 15 ]; do
	addr=$(ip -4 -o addr show "$IF" 2>/dev/null | awk '{print $4}')
	[ -n "$addr" ] && break
	sleep 2
	i=$((i + 1))
done
if [ -n "$addr" ]; then
	log "[ok] adresse $addr - sshd port 22, x11vnc port 5900"
else
	log "[ECHEC] association OK mais aucun bail DHCP apres 30 s"
fi
log "=== wifi-dhcp : fin ==="
