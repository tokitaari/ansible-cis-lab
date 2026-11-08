# 3.01 - Alles in eine Rolle überführen: Erklärung

### Was der Check prüft
`lab check 3.01` führt `check.sh` in vier Schritten aus, danach läuft dein `site.yml` noch einmal
mit `--check` und muss `changed=0` melden:

- **Struktur:** In `/lab/work/roles/cis` müssen neun Dateien existieren (`tasks/main.yml`, die fünf
  Abschnittsdateien, `defaults/main.yml`, `handlers/main.yml`, `meta/main.yml`), dazu mindestens
  eine `vars/*.yml` und `/lab/work/3.01/site.yml`. `templates/` ist nicht Pflicht.
- **Tags:** `ansible-playbook site.yml --list-tags` muss `section1`, `section2`, `section3`,
  `section5`, `section7`, `ssh`, `sudo`, `cron` und `sysctl` nennen. Die übrigen Themen-Tags der
  README (`modules`, `banners`, `packages`, `services`, `permissions`) werden nicht geprüft, auch
  nicht, welcher Task ein Tag trägt.
- **Lint:** `ansible-lint --offline --profile moderate` auf die Rolle.
- **Zustand:** die Checks von 0.04, 1.01-1.05 und 2.01-2.06.

Er prüft die Hosts, nicht, woher ihr Zustand stammt: Hosts, die noch die Ergebnisse deiner früheren
Playbooks tragen, bestehen auch dann, wenn die Rolle wenig tut. Der eigentliche Test ist der aus der
README, "ein Lauf auf frisch zurückgesetzten Hosts" - führe vorher `./lab.sh reset all` und 0.02
aus. Gemessen mit der Referenzrolle auf frisch zurückgesetzten Hosts: Alle zwölf Checks `ok` nach
einem Lauf, der zweite Lauf `changed=0`, `lab check 3.01` bestanden. Die Grenzen der einzelnen
Checks bleiben (siehe die EXPLANATIONs von 0.04-2.06); die Rolle schreibt wie 2.03
`cis-<modul>.conf`, also gewinnen auch hier die Vendor-Regeln von openSUSE.

### So funktioniert es

#### Aufbau der Referenzrolle
```
roles/cis/
├── defaults/main.yml        # jeder Regler, Präfix cis_
├── vars/{Debian,RedHat,Suse,Archlinux,Alpine,default}.yml
├── tasks/main.yml           # include_vars + Import pro Abschnitt
├── tasks/section{1,2,3,5,7}_*.yml
├── handlers/main.yml        # Reload sshd
├── templates/{banner,sshd_cis.conf}.j2
└── meta/main.yml            # Plattformen, min_ansible_version
```
Ansible lädt `tasks/main.yml`, `defaults/main.yml`, `vars/main.yml`, `handlers/main.yml` und
`meta/main.yml` von selbst (L07). Die Referenzrolle hat keine `vars/main.yml`: Ein Task lädt ihre
Plattformdateien.

#### defaults, vars und `include_vars`
Die Defaults sind die Schnittstelle (`cis_level`, die sshd-Werte, die Modulliste) und verlieren
gegen jede andere Ebene. Die Plattformdaten (Dienstnamen, Gruppe und Modus von shadow,
`cron.allow`-Unterstützung) lädt `include_vars` + `first_found` (`<os_family>.yml`, danach
`default.yml`), und diese Ebene verhält sich anders als die `vars/main.yml` einer Rolle. Gemessen
mit einer kleinen Testrolle (ansible-core 2.21.6):

| Ebene | Schlägt | Im nächsten Play noch gesetzt |
|---|---|---|
| `defaults/main.yml` | nichts | nein |
| `vars/main.yml` | Inventory, `vars:` des Plays | nein |
| `include_vars` | Inventory, `vars:` des Plays | **ja** (für diesen Host, für den Rest des Laufs) |
| Rollenparameter (`- role: cis` + `cis_x: ...`) | `include_vars`, nur innerhalb der Rolle | nein |
| `-e` | alles | ja |

`cis_sshd_service` und die anderen Plattformwerte existieren also in jedem späteren Play desselben
`ansible-playbook`-Laufs - ein Grund mehr für das Präfix `cis_`.

#### `import_tasks`, Tags und `always`
`import_tasks` ist statisch: Die Tags des Imports werden an jeden Task darin kopiert, also zeigt
`--list-tasks --tags ssh` den `always`-Task und die beiden `ssh`-Tasks aus Abschnitt 5 (gemessen).

Der `include_vars`-Task trägt `always`, weil spätere Tasks und der Handler seine Werte brauchen.
Ohne das Tag schreibt `--tags ssh` das Drop-in (`changed`), dann scheitert der Handler mit
`'cis_sshd_service' is undefined` - die Datei ist neu, sshd läuft weiter mit der alten
Konfiguration (Test in der Session). `--skip-tags always` ist schlimmer: Auch Ansibles impliziter
Handler-Flush trägt das Tag `always` (Quelltext von ansible-core), auf debian änderte sich also das
Drop-in (`changed=1`), kein Handler lief und nichts scheiterte (gemessen).

Tags überspringen auch Hilfs-Tasks. In der Referenzrolle trägt `Ensure /etc/sysctl.d exists` nur
`section3`; `ansible-playbook site.yml --tags sysctl` endet auf frisch zurückgesetzten rocky und
alma, die kein `/etc/sysctl.d` haben, mit `failed=1` (gemessen): `ansible.posix.sysctl` legt das
Verzeichnis nicht an (`No such file or directory`, Test in der Session). Gib Hilfs-Tasks auch das
Themen-Tag, oder `always`. `Ensure /etc/modprobe.d exists` (nur `section1`) schadet im Lab nicht:
Das Verzeichnis gibt es auf allen acht Hosts (2.03).

#### Was `ansible-lint --profile moderate` findet
Gemessen, indem jeweils eine Sache in der Referenzrolle geändert wurde (ansible-lint 26.10.1):

- gefunden ab `basic`: ein Default, eine `vars/`-Datei oder ein `register` ohne Präfix `cis_`
  (`var-naming[no-role-prefix]`), ein Modus ohne Anführungszeichen (`yaml[octal-values]`), ein
  Task ohne Namen (`name[missing]`);
- erst von `production` gefunden: ein Modul ohne FQCN (`fqcn[action-core]`) und ein `command` ohne
  `changed_when` (`no-changed-when`, aus `shared`).

Die Präfix-Regel greift nur, wenn die Rolle in einem Verzeichnis namens `roles/` liegt. Das Gate des
Repositorys lintet die Musterlösungen mit `production`.

#### Das Refactoring testen
Die Checks von 0.04-2.06 sind deine Regressionstests: zurücksetzen, die Rolle einmal laufen lassen,
die Checks ausführen, noch einmal laufen lassen (`changed=0`). Molecule automatisiert dieselbe
Schleife.

### Hinweise je Familie
| os_family | Plattformdatei (sshd- / cron-Dienst, `cron.allow`, shadow) | Lauf 1 auf frischen Hosts | Hinweis |
|---|---|---|---|
| Debian | `ssh` / `cron`, ja, `shadow` `0640` | `changed=13` | - |
| RedHat | `sshd` / `crond`, ja, `root` `0000` | `changed=15` (rocky, alma), `14` (fedora) | rocky, alma: `--tags sysctl` scheitert auf frischen Hosts |
| Suse | `sshd` / `cron`, ja, `shadow` `0640` | `changed=14` | Vendor-Regeln für modprobe gewinnen (2.03) |
| Alpine | `sshd` / `crond`, nein (stattdessen das Spool `/etc/crontabs`), `shadow` `0640` | `changed=11`, `skipped=3` | braucht vorher 0.02 |
| Archlinux | `sshd` / `cronie`, ja, `root` `0600` | `changed=13` | - |

Zweiter Lauf: `changed=0` auf allen acht (gemessen).

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| `'cis_sshd_service' is undefined` im Handler unter `--tags ssh` | `include_vars`-Task nicht mit `always` getaggt | mit `always` taggen |
| Drop-in geändert, kein Handler lief, kein Fehler | `--skip-tags always` überspringt auch den impliziten Handler-Flush | `always` nicht überspringen |
| `--tags sysctl` scheitert auf rocky/alma: `No such file or directory` | der Verzeichnis-Task hat kein Tag `sysctl` | Themen-Tag (oder `always`) an Hilfs-Tasks |
| Eine Play-Variable oder ein Inventory-Wert wirkt nicht | der Wert kommt aus `include_vars` oder `vars/` | Regler gehören in `defaults/` |
| Ein späteres Play sieht `cis_*`-Werte | `include_vars` setzt Host-Variablen für den Rest des Laufs | alles mit Präfix |
| Lint besteht, aber `production` meldet `fqcn` | `moderate` enthält die Regel nicht | vor dem Teilen mit `production` linten |
| Rolle in `/lab` gefunden, nicht in `roles_path` | das Arbeitsverzeichnis wird mit durchsucht (L07) | aus `/lab/work/3.01` starten |

### Praxis-Hinweise
- Tagge jeden Task, der etwas vorbereitet (Verzeichnisse, Fakten, vars), mit dem Themen-Tag oder
  `always`, und teste die Tags, die du anbietest: `--tags <tag>` auf einem frischen Host.
- Den Python-Bootstrap (Bonus 3) ins Play legen, nicht in die Rolle. Fakten werden vor den
  `pre_tasks` gesammelt (Test in der Session: `Gathering Facts` scheiterte vor dem ersten Task der
  `pre_tasks`), das Play braucht also `gather_facts: false`, den `raw`-Bootstrap und danach
  `ansible.builtin.setup`. Die Rolle selbst hängt an Fakten (`ansible_facts.os_family`) und kann
  deren Fehlen nicht reparieren.
- Prüfe `defaults/main.yml` wie eine Richtlinie: Jeder Wert ist eine Entscheidung für jeden Host.

### Weiterführend
- Lektion [L07 - Rollen, Tags und Projektstruktur](../../../docs/lessons/L07-roles-tags-project-structure.de.md): Aufbau, Präzedenz, Importe, Tags, Lint-Profile, Links zur Ansible-Dokumentation.
- Übung [2.03 - Unnötige Kernelmodule deaktivieren](../../stage2-building-blocks/2.03-disable-kernel-modules/README.de.md)
- Übung [2.04 - Kernelparameter: Netzwerk-Härtung per sysctl](../../stage2-building-blocks/2.04-sysctl-network/README.de.md)
- Übung [4.03 - Datengetriebene Rolle für alle Plattformen (inkl. Alpine)](../../stage4-advanced/4.03-data-driven-multi-platform-role/README.de.md)

## Musterlösung

Anzeigen mit `lab solution 3.01`, anwenden mit `lab solve 3.01`.
