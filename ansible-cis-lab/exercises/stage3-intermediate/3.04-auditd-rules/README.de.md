# 3.04 - auditd: Regeln und Log-Aufbewahrung (Level 2)

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 3 - Mittelstufe | ★★★☆☆ | ~50 Min. | 6.3 Configure auditd (L2) | `targets` |

**Konzepte:** `dict of lists → files`, `template loop`, `lineinfile on key=value`, `host-global kernel features`

## Ziel

Installiere auditd, rolle die CIS-Audit-Regeln als getrennte Regeldateien aus und konfiguriere die Log-Aufbewahrung - ohne etwas in den gemeinsamen Kernel zu laden.

## Hintergrund

**Level 2.** In aktuellen CIS-Benchmarks gehört der auditd-Abschnitt zum Profil
Level 2 (mehr Schutz, mehr Betriebsaufwand: Platten, CPU, Alarmbearbeitung). Er ist im
Lab, weil er eine der wertvollsten Kontrollen für Incident Response ist - und weil er
eine sehr wichtige Lektion über Container lehrt.

Das Audit-Subsystem des Kernels ist **nicht namespaced**. Regeln laden
(`augenrules --load`, `auditctl`) oder `auditd` in einem privilegierten Container zu
starten, betrifft deinen *Host* und alle anderen Container. Im Lab *konfigurierst* du
daher nur; der Dienst bleibt aus (Schutz: `lab_in_container`). Auf einer VM oder
Hardware würde dieselbe Rolle den Dienst auch aktivieren und starten.

Regeln (eine Datei pro Thema in `/etc/audit/rules.d/50-cis-<thema>.rules`):
scope (sudoers), user_emulation (sudo/su als anderer Benutzer), sudo_log, time_change,
identity (Kontodateien, PAM, nsswitch), logins - plus `99-cis-finalize.rules` mit
`-e 2` (Regeln werden bis zum Neustart unveränderlich).

## Anforderungen

- [ ] Paket je Familie: Debian `auditd`, alle anderen `audit`.
- [ ] Die Regeln stammen aus **einer** Dict-Variable (Thema → Liste von Regelzeilen); ein templatebasierter Task mit Schleife schreibt `50-cis-<thema>.rules` (`root:root`, `0640`). Kopiere die Regelliste aus `lab solution 3.04`, wenn du sie nicht abtippen willst - es geht um die Struktur.
- [ ] `99-cis-finalize.rules` enthält genau `-e 2`.
- [ ] `/etc/audit/auditd.conf`: `max_log_file_action = keep_logs`, `space_left_action = email`, `action_mail_acct = root`, `admin_space_left_action = single`.
- [ ] Der Dienst wird **nur** bei `not lab_in_container` aktiviert/gestartet.
- [ ] Zweiter Lauf: `changed=0`. In die Rolle als `section6_logging.yml` (Tag `auditd`) aufnehmen, geschützt durch `cis_level >= 2`.

## Vorgehen

```bash
lab start 3.04            # legt /lab/work/3.04/ an
cd /lab/work/3.04
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 3.04            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 3.04 1` (sanft) ... `lab hint 3.04 3` (fast die Lösung).  
Bestanden? Lies `lab explain 3.04` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- `augenrules --check` vergleicht rules.d mit den geladenen Regeln. Warum ist das hier sinnlos?
- Ergänze die `perm_mod`-Regeln (chmod/chown/setxattr-Familie mit `-F auid>=1000`). Warum `auid` und nicht `uid`?
- Ist `-F arch=b64` auf aarch64-Hosts (Apple Silicon) noch richtig? Und `b32`?
