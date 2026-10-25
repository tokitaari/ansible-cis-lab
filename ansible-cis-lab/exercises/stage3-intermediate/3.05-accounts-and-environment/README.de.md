# 3.05 - Konten-Audit: UID 0, leere Passwörter, umask, TMOUT

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 3 - Mittelstufe | ★★★☆☆ | ~50 Min. | 5.4.2 / 5.4.3 User accounts and environment (L1) | `targets` |

**Konzepte:** `parsing files into facts`, `selectattr on lists`, `user module`, `profile.d`

## Ziel

Finde und behebe gefährliche Konten (ein zweites UID-0-Konto, Konten mit leerem Passwort) und setze eine sichere Standard-Shell-Umgebung.

## Hintergrund

Diese Aufgabe beginnt mit *Aufklärung*. Zwei Hosts haben ein zusätzliches Konto mit
UID 0 (`toor`), zwei Hosts haben ein Konto ohne Passwort (`guest`). Welche, wird dir
nicht verraten - dein Playbook muss sie finden.

CIS 5.4.2: root muss das einzige UID-0-Konto sein; kein Konto darf ein leeres
Passwortfeld haben. CIS 5.4.3: Standard-`umask` 027 (neue Dateien für "andere" nicht
lesbar), Shell-Timeout `TMOUT` ≤ 900 Sekunden, `readonly`, damit Benutzer ihn nicht
entfernen können.

Ein UID-0-Konto zu entfernen hat eine Falle: `userdel toor` verweigert ("user is
currently used by process 1"), weil *roots* Prozesse auch UID 0 haben.

## Anforderungen

- [ ] Lies `/etc/passwd` und `/etc/shadow` per `slurp` und berechne zwei Listen: UID-0-Konten außer root, und Konten mit leerem Passwortfeld.
- [ ] Entferne die zusätzlichen UID-0-Konten (`ansible.builtin.user`, denk an `force`), sperre die Konten mit leerem Passwort (`password_lock: true`).
- [ ] Gib aus, was gefunden wurde (`debug`) - die Nachvollziehbarkeit zählt.
- [ ] `/etc/profile.d/50-cis-umask.sh` setzt `umask 027`; `/etc/profile.d/50-cis-tmout.sh` setzt `TMOUT=900`, `readonly TMOUT`, `export TMOUT`. Beide `0644 root:root`.
- [ ] Zweiter Lauf: `changed=0`. In die Rolle als `section5_accounts.yml` (Tag `accounts`) aufnehmen.

## Vorgehen

```bash
lab start 3.05            # legt /lab/work/3.05/ an
cd /lab/work/3.05
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 3.05            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 3.05 1` (sanft) ... `lab hint 3.05 3` (fast die Lösung).  
Bestanden? Lies `lab explain 3.05` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Warum funktioniert `force: true`, und warum wäre `remove: true` bei einem UID-0-Konto mit Home `/root` gefährlich?
- CIS will außerdem roots `PATH` ohne `.` oder leere Einträge und jedes Home-Verzeichnis mit `0750` oder strenger. Ergänze eins davon.
