# 0.04 - Erstes Härtungs-Playbook: SSH-Warnbanner

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 0 - Grundlagen | ★☆☆☆☆ | ~20 Min. | 1.6 Command line warning banners (L1) | `targets` |

**Konzepte:** `playbook`, `copy`, `mode/owner`, `idempotency`

## Ziel

Ersetze das Banner in `/etc/issue.net`, das aktuell OS-Details verrät, durch einen neutralen rechtlichen Hinweis.

## Hintergrund

Schau es dir zuerst an: `ansible targets -m ansible.builtin.command -a 'cat /etc/issue.net'`.
Es enthält den Distributionsnamen und die Escape-Sequenzen `\r` (Kernel-Release) und
`\m` (Architektur). Angreifer lieben kostenlose Aufklärung. CIS verlangt Banner, die vor
unbefugter Nutzung warnen und **keine** OS- oder Versionsinformationen enthalten.

## Anforderungen

- [ ] Schreibe `playbook.yml` für `targets` mit Rechteausweitung (become).
- [ ] `/etc/issue.net` enthält einen Hinweis mit dem Wort **authorized** (Groß-/Kleinschreibung egal).
- [ ] Keine OS-Information: kein `\m`, `\r`, `\s`, `\v` und kein Distributionsname.
- [ ] Eigentümer `root`, Gruppe `root`, Modus `0644`.
- [ ] Zweimal ausgeführt zeigt der zweite Lauf `changed=0`.

## Vorgehen

```bash
lab start 0.04            # legt /lab/work/0.04/ an
cd /lab/work/0.04
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 0.04            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 0.04 1` (sanft) ... `lab hint 0.04 3` (fast die Lösung).  
Bestanden? Lies `lab explain 0.04` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Führe vor dem Anwenden `--check --diff` aus. Was zeigt dir `--diff`?
- Setze dasselbe Banner auch in `/etc/issue` (lokale Konsolenanmeldung).
