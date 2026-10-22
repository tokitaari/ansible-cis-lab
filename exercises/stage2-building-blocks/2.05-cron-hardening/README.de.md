# 2.05 - Job-Scheduler: cron-Rechte und Zugriff

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 2 - Bausteine | ★★★☆☆ | ~45 Min. | 2.4 Job schedulers (L1) | `targets` |

**Konzepte:** `per-family service names`, `stat loops`, `conditional resources`, `N/A handling`

## Ziel

Härte cron auf allen acht Hosts - mit drei verschiedenen cron-Implementierungen und vier verschiedenen Dienstnamen.

## Hintergrund

Cron führt Befehle zeitgesteuert als root aus. Beschreibbare cron-Dateien = dauerhafter
root-Zugang für Angreifer. CIS verlangt:

- der cron-Daemon ist aktiviert und läuft (geplante Wartung muss funktionieren),
- `/etc/crontab` hat `0600 root:root`,
- `/etc/cron.hourly`, `cron.daily`, `cron.weekly`, `cron.monthly`, `cron.d` haben `0700 root:root`,
- `/etc/cron.allow` existiert (`0640 root:root`) - nur gelistete Benutzer dürfen `crontab` nutzen.

Realitätscheck:

| Familie | Implementierung | Dienst |
|---|---|---|
| Debian | Vixie/Debian cron | `cron` |
| RedHat | cronie | `crond` |
| Suse | cronie | `cron` |
| Archlinux | cronie | `cronie` |
| Alpine | busybox crond | `crond` |

Alpine hat kein `/etc/crontab` und keine `cron.*`-Verzeichnisse (es nutzt `/etc/crontabs/`
und `/etc/periodic/`), und busybox-`crontab` ignoriert `cron.allow`.

## Anforderungen

- [ ] Ein Dict bildet `os_family` → cron-Dienstname ab; der Dienst ist `started` und `enabled`.
- [ ] Für jeden Pfad der Liste, der **existiert**, die CIS-Rechte setzen (Datei `0600`, Verzeichnisse `0700`, `root:root`).
- [ ] `/etc/cron.allow` anlegen (`0640 root:root`, Inhalt `root`) auf allen Familien außer Alpine.
- [ ] Auf Alpine dieselbe Absicht umsetzen: `/etc/crontabs` `0700 root:root`.
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 2.05            # legt /lab/work/2.05/ an
cd /lab/work/2.05
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 2.05            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 2.05 1` (sanft) ... `lab hint 2.05 3` (fast die Lösung).  
Bestanden? Lies `lab explain 2.05` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- CIS erwähnt auch `/etc/cron.deny`. Wenn `cron.allow` existiert, wird `cron.deny` ignoriert - entferne es, um Verwirrung zu vermeiden.
- `at` ist ein weiterer Scheduler (`/etc/at.allow`). Auf welchen Hosts ist er installiert?
