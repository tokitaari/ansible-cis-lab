# 4.01 - Reiner Audit-Lauf mit Compliance-Bericht

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★☆ | ~75 Min. | cross-section (L1) | `targets` |

**Konzepte:** `read-only plays`, `check_mode: false on readers`, `hostvars aggregation`, `to_nice_json`

## Ziel

Schreibe ein Playbook, das auf den Targets *nichts* ändert, zehn Kontrollen pro Host bewertet und einen JSON- und Markdown-Compliance-Bericht auf dem Control Node erzeugt.

## Hintergrund

Bevor du Produktionssysteme korrigierst, misst du sie. Auditoren wollen Nachweise,
Change Manager wollen den Wirkungsradius kennen. Ein gutes Audit-Play:
- nutzt nur lesende Module (`stat`, `slurp`, `package_facts`, `service_facts`,
  lesendes `command` mit `changed_when: false`),
- bricht nie mittendrin ab, weil eine Kontrolle scheitert - es notiert `fail` und macht weiter,
- liefert maschinenlesbare Ausgabe (JSON) plus etwas für Menschen (Markdown).

Probiere es auf einem frisch zurückgesetzten Host (`./lab.sh reset debian`) und auf einem gehärteten.

## Anforderungen

- [ ] Playbook `/lab/work/4.01/playbook.yml`. Auf den Targets muss es `changed=0` melden - im Normalmodus und mit `--check`.
- [ ] Mindestens diese zehn Kontrollen pro Host, jeweils mit `id`, `title`, `status` (`pass`/`fail`/`n/a`):
  2.2 telnet nicht installiert · 2.1 vsftpd läuft nicht/nicht aktiviert · 7.1 /etc/passwd 0644 root:root · 7.1 shadow nicht für andere lesbar · 5.1 PermitRootLogin no (wirksam) · 5.1 MaxAuthTries ≤ 4 · 5.2 sudo `use_pty` konfiguriert · 3.3 `net.ipv4.ip_forward` = 0 · 2.4 `/etc/cron.allow` existiert (n/a auf Alpine) · 5.4.2 root ist das einzige UID-0-Konto
- [ ] `/lab/work/4.01/report.json`: ein Objekt mit dem Hostnamen als Schlüssel, jeder Wert mit `score` (Prozent `pass` unter pass+fail) und `results` (Liste).
- [ ] `/lab/work/4.01/report.md`: eine Tabellenzeile pro Host mit Score, plus eine Liste aller Fehler.
- [ ] Nirgends `ignore_errors: true`.

## Vorgehen

```bash
lab start 4.01            # legt /lab/work/4.01/ an
cd /lab/work/4.01
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 4.01            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.01 1` (sanft) ... `lab hint 4.01 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.01` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Füge einen Zeitstempel in den Bericht ein. Was macht das mit der Idempotenz der Berichtsdatei - und spielt das eine Rolle?
- Mach die Kontrollen zu *Daten*: eine Liste von `{id, title, expr}`, wobei `expr` ein pro Host ausgewerteter Jinja-Ausdruck ist. Elegant oder zu clever?
