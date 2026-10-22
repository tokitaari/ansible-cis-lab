# 1.01 - Unsichere Client-Pakete entfernen

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 1 - Einsteiger | ★☆☆☆☆ | ~20 Min. | 2.2 Client services (L1) | `targets` |

**Konzepte:** `package`, `state: absent`, `package_facts`, `--check --diff`

## Ziel

Entferne den `telnet`-Client von jedem Target, auf dem er installiert ist.

## Hintergrund

Telnet überträgt alles - auch Passwörter - im Klartext. CIS führt eine Reihe
veralteter Clients (telnet, rsh, talk, ftp, NIS), die nicht installiert sein sollen.
Das generische Modul `ansible.builtin.package` wählt den passenden Paketmanager
(`apt`, `dnf`, `zypper`, `pacman`, `apk`) selbst.

## Anforderungen

- [ ] Ein Play für `targets` mit `become: true`.
- [ ] Das Paket `telnet` ist auf allen Hosts entfernt.
- [ ] Nutze `ansible.builtin.package` - nicht `apt`/`dnf`/`shell`.
- [ ] Hosts, die nie telnet hatten, dürfen nicht fehlschlagen.
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 1.01            # legt /lab/work/1.01/ an
cd /lab/work/1.01
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 1.01            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 1.01 1` (sanft) ... `lab hint 1.01 3` (fast die Lösung).  
Bestanden? Lies `lab explain 1.01` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Vor dem Ausführen: `ansible-playbook playbook.yml --check --diff`. Welche Hosts *würden* sich ändern?
- Auf Debian/Ubuntu ist `telnet` evtl. nur ein Übergangspaket. Ist `/usr/bin/telnet` wirklich weg? (`ansible debian_family -m ansible.builtin.command -a 'which telnet'`) Was müsstest du noch entfernen?
- Erweitere um `rsh-client`, `talk`, `ftp`. Was passiert, wenn ein Name auf einer Distribution nicht existiert?
