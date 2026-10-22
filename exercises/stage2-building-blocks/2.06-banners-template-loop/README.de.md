# 2.06 - Alle Login-Banner aus einem Template

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 2 - Bausteine | ★★☆☆☆ | ~25 Min. | 1.6 Command line warning banners (L1) | `targets` |

**Konzepte:** `template in a loop`, `inventory variables`, `--diff`

## Ziel

Verwalte `/etc/motd`, `/etc/issue` und `/etc/issue.net` aus einem einzigen Template, das den Organisationsnamen aus dem Inventar nimmt.

## Hintergrund

0.04 hat eine Datei mit festem String korrigiert. Echte Umgebungen haben drei
Banner-Dateien (Message of the Day, lokale Konsole, Remote-Login) und einen Rechtstext,
der von jemand anderem kommt. Das Inventar definiert bereits `lab_org_name` in
`group_vars/all.yml` - dein Template soll ihn nutzen.

## Anforderungen

- [ ] Ein Template `templates/banner.j2`, das `{{ lab_org_name }}` und das Wort *authorized* enthält.
- [ ] Ein Task mit `loop` rollt es nach `/etc/motd`, `/etc/issue`, `/etc/issue.net` aus - `root:root`, `0644`.
- [ ] Keine OS-Information in einer der Dateien (kein `\m \r \s \v`, kein Distributionsname).
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 2.06            # legt /lab/work/2.06/ an
cd /lab/work/2.06
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 2.06            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 2.06 1` (sanft) ... `lab hint 2.06 3` (fast die Lösung).  
Bestanden? Lies `lab explain 2.06` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Überschreibe `lab_org_name` nur für einen Host mit `-e` oder in `host_vars`, starte mit `--diff -l alpine`.
- Auf manchen Distributionen wird `/etc/motd` dynamisch erzeugt (`/etc/update-motd.d` auf Ubuntu, `/etc/motd.d` auf Fedora). Gibt es diese Verzeichnisse hier? Was würdest du damit tun?
