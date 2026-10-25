# 1.02 - Rechte auf /etc/passwd und /etc/group

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 1 - Einsteiger | ★☆☆☆☆ | ~20 Min. | 7.1 System file permissions (L1) | `targets` |

**Konzepte:** `file`, `mode`, `owner`, `octal pitfalls`

## Ziel

Korrigiere die gruppenbeschreibbaren Dateien `/etc/passwd` und `/etc/group` auf jedem Target.

## Hintergrund

Jemand hat beide Dateien auf `0664` gesetzt. Ein gruppenbeschreibbares `/etc/passwd`
erlaubt Mitgliedern dieser Gruppe, ein UID-0-Konto anzulegen - Spiel vorbei. CIS
verlangt `0644` (oder strenger), Eigentümer `root`, Gruppe `root`. Prüfe zuerst den
Ist-Zustand: `ansible targets -m ansible.builtin.stat -a path=/etc/passwd | grep '"mode"'`

## Anforderungen

- [ ] `/etc/passwd` und `/etc/group`: Modus `0644`, Eigentümer `root`, Gruppe `root`.
- [ ] Nutze `ansible.builtin.file` (ein Task pro Datei ist ok - Schleifen kommen in Stufe 2).
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 1.02            # legt /lab/work/1.02/ an
cd /lab/work/1.02
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 1.02            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 1.02 1` (sanft) ... `lab hint 1.02 3` (fast die Lösung).  
Bestanden? Lies `lab explain 1.02` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Was passiert bei `mode: 644` (ohne Anführungszeichen, ohne führende Null)? Probiere es auf einem Host (`-l debian`), sieh dir das Ergebnis mit `stat` an und korrigiere es. Notfalls `./lab.sh reset debian`.
- CIS umfasst auch die Sicherungen `/etc/passwd-` und `/etc/group-`. Nimm sie dazu - sie existieren aber nicht überall. Wie gehst du damit um?
