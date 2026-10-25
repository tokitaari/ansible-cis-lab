# 5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 5 - Abschlussprojekt | ★★★★★ | ~240 Min. | Sections 1-7 (L1 + L2 switch) | `targets` |

**Konzepte:** `control registry`, `check_mode as audit engine`, `dynamic includes with apply`, `reporting`, `ansible-lint production`

## Ziel

Mach aus deiner Rolle eine produktionsreife CIS-Baseline: ein Codepfad, der **auditieren** (nichts ändern, berichten) oder **durchsetzen** (beheben, berichten) kann - mit Profilen, dokumentierten Ausnahmen und Compliance-Bericht für alle acht Plattformen.

## Hintergrund

Echte Härtungsrollen laufen auf zwei Arten: durch Auditoren/Scheduler im Lesemodus und
in Change-Fenstern im Enforce-Modus. Zwei Codebasen (Audit + Behebung) zu pflegen
verdoppelt die Fehler. Der elegante Weg: jede Kontrolle für Audits im **Check-Modus**
ausführen - ein Task, der etwas ändern *würde*, ist ein Befund.

Architektur der Referenzlösung (du darfst eine andere wählen):
```
vars/main.yml        Registry cis_controls: id, level, title, Task-Datei, requires
tasks/main.yml       Plattform-vars laden → Vorabprüfung → Schleife über Registry → Bericht
tasks/control.yml    entscheiden (active / excepted / out-of-profile / not-applicable)
                     → controls/<datei> mit apply: check_mode einbinden
                     → pass / fail / fixed festhalten
tasks/controls/*.yml eine Datei pro Kontrolle, registriert cis_r_<n>
tasks/report.yml     JSON + Markdown auf dem Control Node
```

## Anforderungen

- [ ] Rolle `/lab/work/roles/cis`, Playbook `/lab/work/5.01/site.yml` (Alpine-Bootstrap-Play + Rolle).
- [ ] `cis_mode: enforce|audit` (Default `enforce`). Im `audit`-Modus meldet ein Lauf gegen frisch zurückgesetzte Hosts Befunde und ändert **nichts** auf den Targets (Handler eingeschlossen!).
- [ ] `cis_level` 1|2 und `cis_exceptions` (validiert: bekannte ID, Begründung, zukünftiges `expires`) - der Mechanismus aus 4.02, jetzt für alle Kontrollen.
- [ ] Kontrollen: alles von 0.04 bis 3.05 (3.04 auditd als Level 2).
- [ ] Bericht `/lab/work/5.01/reports/compliance.json` (pro Host: Modus, Level, Plattform, Zähler, Befunde mit id/title/status/reason) und `compliance.md`.
- [ ] Status: `pass`, `fail` (Audit), `fixed` (Enforce), `excepted`, `out-of-profile`, `not-applicable`.
- [ ] Abnahme: `./lab.sh reset all` → Audit-Lauf (nur `fail`, keine Änderungen) → Enforce-Lauf → Audit-Lauf (kein `fail` mehr). Zweiter Enforce-Lauf: `changed=0`.
- [ ] `ansible-lint --offline --profile production` besteht auf der Rolle.

## Vorgehen

```bash
lab start 5.01            # legt /lab/work/5.01/ an
cd /lab/work/5.01
# site.yml schreiben, dann ausführen:
ansible-playbook site.yml
lab check 5.01            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 5.01 1` (sanft) ... `lab hint 5.01 3` (fast die Lösung).  
Bestanden? Lies `lab explain 5.01` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Ergänze 4.06 (faillock), 4.07 (nftables) und 4.08 (AIDE) als Kontrollen - nftables braucht im Audit-Modus besondere Sorgfalt (der Totmannschalter darf nicht laufen).
- Lass den Bericht für fehlschlagende Kontrollen den *Diff* zeigen (die `--diff`-Ausgabe steckt in den registrierten Ergebnissen).
- Veröffentliche die Rolle als Collection (`ansible-galaxy collection init lab.cis`) mit `README`, `meta/runtime.yml` und Beispiel-Playbook.
