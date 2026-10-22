# 5.02 - Rollout-Strategie: Vorabprüfung, Canary, Wellen

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 5 - Abschlussprojekt | ★★★★★ | ~90 Min. | (operations) (-) | `targets` |

**Konzepte:** `any_errors_fatal`, `serial`, `max_fail_percentage`, `explicit confirmation`, `post-checks`

## Ziel

Verpacke deine Abschlussrolle in ein Rollout-Playbook, das auf 2.000 Servern sicher wäre: globale Vorabprüfung, eine Canary-Gruppe, wachsende Wellen, die beim ersten Fehler stoppen, und Verifikation nach jeder Welle.

## Hintergrund

Auch eine korrekte Rolle kann einen Ausfall verursachen, wenn sie alle Hosts gleichzeitig
trifft (denk an eine Firewallregel, die nur auf einer OS-Version falsch ist). Eine
Rollout-Strategie begrenzt den Schadensradius:

| Phase | Ansible-Funktion |
|---|---|
| Vorabprüfung auf *allen* Hosts, bei jedem Fehler alles abbrechen | `any_errors_fatal: true` |
| ausdrückliche Bestätigung durch den Operator | Pflicht-Extra-Var, `assert` |
| zuerst Canary | eigenes Play für eine kleine Gruppe |
| wachsende Wellen | `serial: [1, "30%", "100%"]` |
| beim ersten Fehler stoppen | `max_fail_percentage: 0` |
| Gesundheit nach jeder Welle belegen | Post-Tasks im selben Play (`wait_for_connection`, Checks) |

## Anforderungen

- [ ] Playbook `/lab/work/5.02/rollout.yml`.
- [ ] Play 1 (alle Targets, `any_errors_fatal: true`): erreichbar, Python vorhanden, `sshd -t` OK, `visudo -c` OK, mindestens 200 MB frei auf `/`, und `cis_rollout_confirm` ist `true` (per `-e` übergeben).
- [ ] Play 2: Canary-Hosts `debian` und `rocky` (konfigurierbar über `cis_canary`) bekommen die Rolle im Enforce-Modus, danach eine Nachprüfung.
- [ ] Play 3: alle übrigen Targets, `serial: [1, "30%", "100%"]`, `max_fail_percentage: 0`, Rolle + Nachprüfung pro Welle.
- [ ] Nachprüfung: eine **neue** SSH-Verbindung funktioniert (`meta: reset_connection` + `wait_for_connection`) und `sshd -T` meldet weiterhin `permitrootlogin no`.
- [ ] Ohne `-e cis_rollout_confirm=true` muss das Playbook in Play 1 scheitern - auch mit `--check`.

## Vorgehen

```bash
lab start 5.02            # legt /lab/work/5.02/ an
cd /lab/work/5.02
# rollout.yml schreiben, dann ausführen:
ansible-playbook rollout.yml
lab check 5.02            # prüft den Zustand
```

Festgefahren? `lab hint 5.02 1` (sanft) ... `lab hint 5.02 3` (fast die Lösung).  
Bestanden? Lies `lab explain 5.02` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Ergänze eine Wartungsfenster-Sperre: Abbruch, wenn die aktuelle Stunde (`now().hour`) außerhalb eines konfigurierten Fensters liegt.
- Benachrichtige pro Welle einen Chat-Kanal (`community.general.slack`/`mattermost`/Teams?). Welche Daten gehören in die Nachricht?
- Wie sähe das in AWX/AAP aus (Workflow-Template mit Genehmigungsknoten)?
