# 3.01 - Alles in eine Rolle überführen

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 3 - Mittelstufe | ★★★☆☆ | ~90 Min. | Sections 1, 2, 3, 5, 7 (L1) | `targets` |

**Konzepte:** `roles`, `defaults vs vars`, `include_vars + first_found`, `import_tasks`, `tags`, `ansible-lint`

## Ziel

Überführe die Playbooks der Stufen 0-2 in eine wiederverwendbare Rolle `cis`, die alle acht Hosts in einem Lauf härtet.

## Hintergrund

Zwölf einzelne Playbooks skalieren nicht. Eine Rolle bündelt Tasks, Defaults,
Variablen, Templates und Handler hinter einer klaren Schnittstelle: *Defaults* sind die
Stellschrauben für Nutzer, *vars* sind interne Plattformdaten. Mit Tags startest du
einen CIS-Abschnitt oder ein Thema (`--tags ssh`). Ab jetzt erweitert jede Aufgabe diese Rolle.

## Anforderungen

- [ ] Rolle unter `/lab/work/roles/cis` (der Pfad ist in `roles_path`) mit mindestens `tasks/`, `defaults/`, `vars/`, `handlers/`, `templates/`, `meta/`.
- [ ] `tasks/main.yml` lädt `vars/<os_family>.yml` (Fallback `vars/default.yml`) und importiert eine Task-Datei pro CIS-Abschnitt: `section1_initial_setup.yml`, `section2_services.yml`, `section3_network.yml`, `section5_access_control.yml`, `section7_maintenance.yml`.
- [ ] Jeder Import ist mit `section1` ... `section7` getaggt; Tasks tragen zusätzlich Themen-Tags (`ssh`, `sudo`, `cron`, `sysctl`, `modules`, `banners`, `packages`, `services`, `permissions`).
- [ ] Alle Stellschrauben stehen in `defaults/main.yml` mit dem Präfix `cis_` (ansible-lint erzwingt Rollenpräfixe). Plattformunterschiede (Dienstnamen, shadow-Gruppe/-Modus, cron.allow-Unterstützung) stehen in `vars/`.
- [ ] Playbook `/lab/work/3.01/site.yml` wendet die Rolle auf `targets` an.
- [ ] Die Rolle deckt die Aufgaben 0.04-2.06 ab; alle ihre Checks bestehen nach **einem** Lauf auf frisch zurückgesetzten Hosts (`./lab.sh reset all`, danach 0.02 für Alpine).
- [ ] `ansible-lint --offline /lab/work/roles/cis` besteht (Profil moderate oder besser).

## Vorgehen

```bash
lab start 3.01            # legt /lab/work/3.01/ an
cd /lab/work/3.01
# site.yml schreiben, dann ausführen:
ansible-playbook site.yml
lab check 3.01            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 3.01 1` (sanft) ... `lab hint 3.01 3` (fast die Lösung).  
Bestanden? Lies `lab explain 3.01` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- `ansible-galaxy role init --init-path /lab/work/roles cis` erzeugt das Gerüst - vergleiche mit dem, was du wirklich brauchst.
- Nur SSH ausführen: `ansible-playbook site.yml --tags ssh`. Alles auflisten: `--list-tags`, `--list-tasks`.
- Mach den Python-Bootstrap für Alpine (0.02) zu einem `pre_tasks`-Block in `site.yml` - warum nicht in der Rolle?
