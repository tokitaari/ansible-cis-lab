# 1.03 - SSH: Root-Login und leere Passwörter verbieten

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 1 - Einsteiger | ★★☆☆☆ | ~35 Min. | 5.1 SSH server (L1) | `targets` |

**Konzepte:** `copy`, `validate`, `handlers`, `notify`, `sshd drop-ins`

## Ziel

Bringe sshd dazu, Root-Logins und leere Passwörter abzulehnen - sicher, ohne dich auszusperren.

## Hintergrund

Ein früherer Admin hat `/etc/ssh/sshd_config.d/10-lab-legacy.conf` mit
`PermitRootLogin yes` und `PermitEmptyPasswords yes` hinterlassen. Zusammen mit einem
Konto mit leerem Passwort (gibt es auf zwei Hosts...) kann sich jeder anmelden.

Wichtige sshd-Regel: **der erste gefundene Wert gewinnt**. `sshd_config` bindet
`sshd_config.d/*.conf` ganz oben ein, die Dateien werden lexikalisch sortiert gelesen.
Prüfe die *wirksame* Konfiguration mit `sshd -T` (als root), nicht die Datei.

Kaputte sshd-Konfiguration + Neustart = ausgesperrt. Zwei Ansible-Funktionen verhindern
das: `validate` (Datei testen, bevor sie an ihren Platz kommt) und Handler (nur bei
Änderung neu laden).

## Anforderungen

- [ ] Lege `/etc/ssh/sshd_config.d/00-cis-hardening.conf` mit `PermitRootLogin no` und `PermitEmptyPasswords no` an.
- [ ] Eigentümer `root:root`, Modus `0600`.
- [ ] Validiere die Datei mit `sshd -t`, bevor sie installiert wird.
- [ ] Lade sshd über einen **Handler** neu, nur wenn sich die Datei geändert hat. Dienstname: `ssh` in der Debian-Familie, sonst `sshd`.
- [ ] `sshd -T` meldet auf allen Hosts `permitrootlogin no` und `permitemptypasswords no`.
- [ ] Die Legacy-Datei **nicht** löschen - sorge dafür, dass deine gewinnt.

## Vorgehen

```bash
lab start 1.03            # legt /lab/work/1.03/ an
cd /lab/work/1.03
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 1.03            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 1.03 1` (sanft) ... `lab hint 1.03 3` (fast die Lösung).  
Bestanden? Lies `lab explain 1.03` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Warum `00-` und nicht `99-`? Benenne deine Datei auf einem Host in `99-cis-hardening.conf` um und schau dir `sshd -T` an.
- Warum `reloaded` statt `restarted`? Was passiert jeweils mit bestehenden Sitzungen?
