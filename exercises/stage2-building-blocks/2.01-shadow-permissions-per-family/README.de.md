# 2.01 - /etc/shadow: richtige Rechte je OS-Familie

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 2 - Bausteine | ★★☆☆☆ | ~35 Min. | 7.1 System file permissions (L1) | `targets` |

**Konzepte:** `vars`, `dict lookup by fact`, `stat + register`, `loop over results`

## Ziel

Korrigiere das für alle lesbare `/etc/shadow` (und `/etc/gshadow`, wo vorhanden) - nach der Konvention der jeweiligen Distribution.

## Hintergrund

Jemand hat `/etc/shadow` auf `0644` gesetzt: jeder Benutzer kann alle Passwort-Hashes
lesen und offline knacken. Die Korrektur wirkt trivial, aber die Distributionen sind
sich über den *richtigen* Wert uneinig:

| Familie | Eigentümer:Gruppe | Modus |
|---|---|---|
| Debian, Suse, Alpine | `root:shadow` | `0640` |
| RedHat | `root:root` | `0000` |
| Archlinux | `root:root` | `0600` |

Die Gruppe `shadow` existiert, damit Helfer wie `unix_chkpwd` Passwörter ohne root
prüfen können. Gruppe `root` auf Debian macht Bildschirmsperren kaputt. CIS akzeptiert
"Eigentümer root, Gruppe root **oder shadow**, Modus 0640 oder strenger" - die richtige
Antwort ist also: Konvention der Familie beibehalten.

## Anforderungen

- [ ] Definiere eine Variable (Dict), die `ansible_facts.os_family` auf Gruppe und Modus abbildet.
- [ ] Wende sie auf `/etc/shadow` und auf `/etc/gshadow` an, **falls vorhanden** (nicht überall).
- [ ] Nutze `ansible.builtin.stat` + `register` + eine Schleife über die Ergebnisse.
- [ ] Keine `when: ansible_facts.os_family == ...`-Ketten - eine Datenstruktur, ein Task.
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 2.01            # legt /lab/work/2.01/ an
cd /lab/work/2.01
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 2.01            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 2.01 1` (sanft) ... `lab hint 2.01 3` (fast die Lösung).  
Bestanden? Lies `lab explain 2.01` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Nimm die Sicherungen `/etc/shadow-` und `/etc/gshadow-` in die Liste auf. Wie viel Code hat das gekostet?
- Das Dict nach `/lab/work/2.01/group_vars/...` verschieben? Vorsicht - group_vars neben einem *Playbook* wirken nur für Gruppen. Welche Gruppennamen bräuchtest du?
