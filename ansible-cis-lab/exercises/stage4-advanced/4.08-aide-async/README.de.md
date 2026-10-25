# 4.08 - Dateiintegrität mit AIDE - lang laufende Tasks

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★☆ | ~60 Min. | 6.1 Filesystem integrity checking (L1) | `debian_family:redhat_family` |

**Konzepte:** `async / poll / async_status`, `creates for idempotency`, `systemd timers via templates`

## Ziel

Installiere AIDE, erstelle die Initialdatenbank auf fünf Hosts parallel, ohne Ansible minutenlang zu blockieren, und plane eine tägliche Integritätsprüfung mit einem systemd-Timer.

## Hintergrund

AIDE erfasst Hashes und Attribute von Systemdateien; spätere Prüfungen decken
Änderungen auf (Rootkits, unautorisierte Bearbeitungen). Die erste Datenbank scannt das
gesamte Dateisystem - Minuten pro Host. Ein normaler Task hielte die SSH-Verbindung die
ganze Zeit (und liefe ggf. in Timeouts). `async` + `poll: 0` startet den Job im
Hintergrund; `async_status` holt die Ergebnisse später ab.

| Familie | Pakete | Konfiguration | Init | Datenbank |
|---|---|---|---|---|
| Debian | `aide`, `aide-common` | `/etc/aide/aide.conf` | `aideinit -y -f` | `/var/lib/aide/aide.db` |
| RedHat | `aide` | `/etc/aide.conf` | `aide --init` + `aide.db.new.gz` → `aide.db.gz` verschieben | `/var/lib/aide/aide.db.gz` |

## Anforderungen

- [ ] Pakete pro Familie installieren (Dict).
- [ ] Die Datenbank mit `async` (z. B. 1800 s) und `poll: 0` initialisieren, dann mit `ansible.builtin.async_status` warten (`until`-Schleife). Die Initialisierung muss übersprungen werden, wenn die Datenbank existiert (`creates:`).
- [ ] Templatebasierte Units `cis-aidecheck.service` (oneshot, führt `aide --check` mit der Konfiguration der Familie aus) und `cis-aidecheck.timer` (täglich, `Persistent=true`); Timer aktiviert und gestartet; `daemon_reload`, wenn sich Units ändern.
- [ ] Zweiter Lauf: `changed=0` und kein zweiter Scan.

## Vorgehen

```bash
lab start 4.08            # legt /lab/work/4.08/ an
cd /lab/work/4.08
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 4.08            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.08 1` (sanft) ... `lab hint 4.08 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.08` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Debian liefert einen eigenen `dailyaidecheck.timer`. Würdest du ihn stattdessen nutzen? Was müsstest du prüfen?
- Flüchtige Pfade (`/var/log`, `/var/cache`) per Drop-in ausschließen statt die Hauptkonfiguration zu bearbeiten.
- Was passiert mit der AIDE-Baseline nach jedem Patchlauf? Wie baust du `aide --update` in dein Patch-Playbook ein?
