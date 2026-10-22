# 4.05 - Custom Facts: Hosts beschreiben ihre eigene Härtung

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★☆☆ | ~45 Min. | (operations) (-) | `targets` |

**Konzepte:** `facts.d`, `static vs executable facts`, `ansible_local`, `no timestamps in managed files`

## Ziel

Lass jeden Host Facts über seine Härtung tragen (statisch: Name/Version/Level der Baseline; dynamisch: aktuelle Sicherheitsindikatoren), die jedes spätere Play - oder ein AWX/AAP-Inventar - per `ansible_local` lesen kann.

## Hintergrund

Dateien in `/etc/ansible/facts.d/*.fact` werden beim Sammeln der Facts eingelesen:
- **statisch**: JSON- oder INI-Inhalt → `ansible_local.<name>`,
- **ausführbar** (Modus 0755): wird beim Sammeln ausgeführt, muss JSON ausgeben.
Statische Facts halten fest, *was angewendet wurde*; ausführbare messen, *was jetzt gilt*.

## Anforderungen

- [ ] `/etc/ansible/facts.d/cis.fact` (`0644`): JSON mit `baseline` (`lab-cis`), `version` (`1.0.0`), `level` (`1`), `managed_by` (`ansible`).
- [ ] `/etc/ansible/facts.d/cis_live.fact` (`0755`, POSIX-`sh`, läuft auch unter busybox): gibt JSON mit `uid0_accounts` (Zahl) und `permit_root_login` (String aus `sshd -T`) aus.
- [ ] Nach dem Ausrollen die Facts im selben Play neu sammeln (`ansible.builtin.setup` mit `filter: ansible_local`).
- [ ] Ein zweites Play auf `localhost` schreibt `/lab/work/4.05/inventory.md`: eine Zeile pro Host mit Baseline-Version, Level, uid0_accounts, permit_root_login.
- [ ] Zweiter Lauf: `changed=0` auf den Targets - also **kein Zeitstempel** in `cis.fact`.

## Vorgehen

```bash
lab start 4.05            # legt /lab/work/4.05/ an
cd /lab/work/4.05
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 4.05            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.05 1` (sanft) ... `lab hint 4.05 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.05` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Wo tauchen diese Facts in AWX/AAP auf (Host-Details), und wie könnte ein Smart-Inventory-Filter sie nutzen?
- Ein ausführbarer Fact, der 10 Sekunden braucht, bremst *jedes* Play auf diesem Host. Wie schützt du dich davor?
