# 5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus: Erklärung

### Was der Check prüft
`lab check 5.01` führt `check.sh` aus, das voraussetzt, dass du die Rolle schon im Enforce-Modus
ausgeführt hast:

- `ansible-lint --offline --profile production` auf die Rolle;
- die Checks von 0.04, 1.01-1.05, 2.01-2.06, 3.02, 3.03 und 3.05; 3.04 nur mit
  `-e cis_level=2` (ein Level in `-e @file` wird nicht gesehen);
- einen Audit-Lauf (`-e cis_mode=audit` plus deine zusätzlichen Argumente): Er muss mit
  `changed=0` auf jedem Target durchlaufen, und `compliance.json` muss acht Hosts abdecken, jeder
  mit `mode: audit`, `level`, `counts`, mindestens 14 `findings` und keinem `fail`.

Danach läuft `site.yml` noch einmal mit `--check` (Enforce-Modus) und muss `changed=0` melden. Die
Berichts-Tasks laufen dabei mit, nach `lab check 5.01` steht im Bericht also `mode: enforce`
(gemessen).

Nicht geprüft: das erste Audit auf frischen Hosts, `fixed`, Ausnahmen, `compliance.md`, ein
Level-2-Audit auf frischen Hosts und der zweite Enforce-Lauf (nur sein Ersatz mit `--check`). Die
Abfolge der README wurde gemessen, siehe unten.

### So funktioniert es

#### Check-Modus als Audit-Engine
Ein idempotentes Modul weiß, ob der Sollzustand erreicht ist; im Check-Modus beantwortet es das,
ohne zu handeln. Der Code zur Behebung ist damit der Audit-Code:

| Task im Check-Modus | Ergebnis | Erfasst als |
|---|---|---|
| `file`, `copy`, `template`, `lineinfile`, `package`, `service`, `sysctl` | `changed: true`, wenn es handeln würde | Befund |
| `command` (hier `useradd -D -f`, `pam-auth-update`) | übersprungen, `changed: false`, msg "Command would have run if not in check mode" | Befund (die `msg`) |
| `slurp`, `stat`, `package_facts`; `command` mit `check_mode: false` (`useradd -D`) | liest wirklich | Daten, nicht erfasst |

Gemessen: `changed_when: true` wird auf den übersprungenen `command` nicht angewendet, `control.yml`
muss also die `msg` ansehen. Beide Kommandos der Rolle laufen nur, wenn ein Leser eine Abweichung
gefunden hat (`when`); ein Kommando ohne Bedingung wäre bei jedem Audit ein Befund.

#### `apply: check_mode` und die Falle beim Probelauf
`include_tasks` nimmt `check_mode:` selbst nicht an; `apply:` gibt das Schlüsselwort an jeden Task
der eingebundenen Datei weiter, und ein eigenes `check_mode: false` am Task gewinnt trotzdem. Der
Ausdruck ist `ansible_check_mode or cis_mode == 'audit'`. Das einfache
`"{{ cis_mode == 'audit' }}"` ist im Enforce-Modus `false` und überstimmt `--check`: Damit hat
`ansible-playbook site.yml --check` Dateien auf den Targets geschrieben (gemessen). `cis_status`
nutzt dieselbe Bedingung, ein Probelauf im Enforce-Modus erfasst eine Abweichung also als `fail`,
nicht als `fixed`, während der Bericht `mode: enforce` sagt. Im Include ist `ansible_check_mode`
nur der Kommandozeilen-Schalter (L10), teste dort also die Modus-Variable.

#### Registry, Entscheidung, Erfassung
`vars/main.yml` listet 16 Kontrollen (id, level, file, optional `requires`). `control.yml`
entscheidet (`excepted`, `out-of-profile`, `not-applicable`, sonst `active`), bindet die Datei
einer aktiven Kontrolle ein und erfasst sie: nicht konform, wenn irgendein registriertes Ergebnis -
Schleifen-Einträge eingeschlossen - `changed` ist oder "would have run" meldet. Jede Datei
registriert `cis_r_<n>` und setzt `cis_control_results`. Gemessen: 5.3.3 ist auf opensuse, arch
und alpine `not-applicable` (kein Feature `pwquality`).

#### Den wirksamen Zustand prüfen
Eine Datei kann stimmen und trotzdem nicht wirken: kmod liest mehrere Verzeichnisse, und die erste
Datei, die ein Modul nennt, gewinnt (2.03). Die beiden Modul-Kontrollen enden darum mit einem
lesenden Task, `modprobe --show-depends <modul>` (`check_mode: false`, `failed_when: false`,
`changed`, wenn die Antwort nicht mit `install /bin/false` beginnt), übergeben in einer zweiten
Liste, `cis_control_verify`. Ein `changed` dort ist in beiden Modi `fail`: Die Tasks der Kontrolle
sind gelaufen und der Host ist trotzdem nicht im Sollzustand, `fixed` wäre falsch. Gemessen mit
`00-aaa-cramfs.conf` (`install cramfs /bin/true`) auf debian und opensuse: 1.1.1 ist im Audit und
im Enforce-Lauf `fail`, bei jedem Lauf mit `changed=1`; ohne den Task meldete die Rolle `pass`.
BusyBox-`modprobe` kann nicht antworten, der Task braucht darum das Feature `kmod` (nicht auf
alpine).

#### Probeläufe in fehlenden Zustand
Auf einem frischen Host prüft ein Audit Tasks, deren Eingabe ein früherer Task erst anlegen würde.
Gemessen im Check-Modus: `copy` und `template` in ein fehlendes Verzeichnis melden `changed`;
`lineinfile` ohne `create` auf eine fehlende Datei scheitert. 6.3 bearbeitet
`/etc/audit/auditd.conf`, die erst das Paket `auditd` mitbringt, darum trägt dieser Task
`when: not ((ansible_check_mode or cis_mode == 'audit') and cis_r_1 is changed)`: Im Dry-Run ist
die anstehende Paketinstallation schon der Befund. Wo die Datei existiert (arch), vergleicht der
Task die Werte. Gemessen: Ein **Level-2-Audit auf frischen Hosts** endet auf allen acht mit
`failed=0` und 6.3 ist `fail`, nach dem Enforce-Lauf `fixed`, danach `pass`; ohne den Guard
scheiterten sieben Hosts und der Bericht enthielt nur arch. Die `cis_r_0`-Tasks schützen fehlende
Verzeichnisse auf dieselbe Weise.

#### Handler
`Reload sshd` hat `when: cis_mode == 'enforce'`: Ein Handler erbt das Schlüsselwort nicht, und L10
hat einen gemessen, der wirklich lief, nachdem ein geprüfter Task ihn benachrichtigt hatte. Ein
globales `--check` erreicht ihn dagegen.

#### Der Bericht
Die Berichts-Tasks nutzen `run_once`, `delegate_to: localhost`, `check_mode: false` und
`changed_when: false`. So ein Task zählt beim ersten Target-Host, ohne das Letzte könnte das
Audit-Recap also nicht `changed=0` zeigen. Die Hostliste sind alle Hosts mit `cis_summary`, nicht
`ansible_play_hosts` (5.02 läuft mit `serial`). Gemessen: Ein gescheiterter Host fehlt im Bericht;
scheitern alle Hosts (eine abgelaufene Ausnahme lässt die Vorabprüfung überall scheitern), wird
nichts geschrieben, und der vorige Bericht bleibt stehen.

#### Tags und Teilmengen
Die Kontrollen tragen keine Tags; nur `include_vars` und der apt-Index-Task haben `always`.
Gemessen: `--tags sysctl` - wie jede andere `--tags`-Auswahl - endet auf allen acht Hosts mit
`failed=0` und `changed=0` und schreibt keinen Bericht, weil nur die `always`-Tasks laufen.
Kontrollen wählst du mit `-e '{"cis_controls_only": ["5.2"]}'`; der Bericht listet dann nur diese. Übergib Booleans als
JSON: `-e cis_apt_cache_refresh=false` ist der String `"false"`, und das `when` lehnt ihn ab
(gemessen).

### Hinweise je Familie
Gemessen auf frisch zurückgesetzten Hosts (nach 0.02), Level 1:

| Host | Erstes Audit: `fail` | Zu Beginn nicht `fail` | Recap `changed`, audit / enforce |
|---|---|---|---|
| debian | 14 | - | 20 / 21 |
| ubuntu | 14 | - | 20 / 21 |
| rocky | 14 | - | 19 / 21 |
| alma | 13 | 5.4.2 | 18 / 20 |
| fedora | 14 | - | 19 / 20 |
| opensuse | 12 | 5.4.2; 5.3.3 `not-applicable` | 17 / 18 |
| arch | 11 | 2.2, 5.4.2; 5.3.3 `not-applicable` | 16 / 17 |
| alpine | 11 | 2.2, 5.4.2; 5.3.3 `not-applicable` | 14 / 16 |

Auf Level 1 sind `1.1.1-L2` und `6.3` überall `out-of-profile`. Nach dem ersten Audit war keine
Datei unter `/etc` oder `/usr` geändert; debian und ubuntu hatten ihren apt-Index geladen (0 -> 3
und 13 Dateien). Enforce machte aus jedem `fail` ein `fixed`; das nächste Audit, der zweite
Enforce-Lauf und `--check` meldeten `changed=0`. Level 2 obendrauf änderte 5 Tasks je Host;
`lab check 5.01` bestand mit und ohne `-e cis_level=2`. Anders als in 4.01 sperrt 5.4.2 auch Konten
mit leerem Passwort, daher scheitern ubuntu und fedora (`guest`, 3.05) hier ebenfalls.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| `--check` im Enforce-Modus hat die Targets geändert | `check_mode: "{{ cis_mode == 'audit' }}"` ist `false` und schlägt `--check` | `ansible_check_mode or cis_mode == 'audit'` |
| Das Audit-Recap zeigt `changed=14`-`20` | Der Check-Modus meldet eine mögliche Änderung als `changed` | Auf frischen Hosts erwartet; den Bericht lesen |
| 1.1.1 bleibt nach einem Enforce-Lauf `fail`, bei jedem Lauf `changed=1` | eine andere Datei in einem `modprobe.d`-Verzeichnis sortiert vor `00-cis-<modul>.conf` und gewinnt | diese Datei entfernen oder umbenennen; `modprobe --show-depends <modul>` zeigt die wirksame Regel |
| `--tags ...` wählt nichts aus | die Kontrollen tragen keine Tags, nur die `always`-Tasks laufen | `cis_controls_only` |
| Der Bericht zeigt alte Daten | Ein gescheiterter Lauf schreibt keinen Bericht | Recap und Dateizeit prüfen |
| Nach `lab check 5.01` sagt der Bericht `enforce` | Der Lauf mit `--check` schreibt ihn neu | Für den Nachweis das Audit erneut ausführen |

### Praxis-Hinweise
Der Audit-Modus ändert keine Konfiguration, ist aber nicht berührungsfrei: Auf Debian/Ubuntu
aktualisiert er den apt-Index (`check_mode: false`, ein Cache). Führe die Rolle so ein wie die
Abfolge der README: Audit, enforce im Wartungsfenster, erneutes Audit als Nachweis, danach Audits
nach Zeitplan. Ausnahmen laufen absichtlich ab - der nächste Lauf scheitert, bis jemand sie
verlängert oder entfernt.

### Weiterführend
- Lektion [L10 - Compliance-Berichte: Audit-Modus, Enforce-Modus und Custom Facts](../../../docs/lessons/L10-compliance-reporting.de.md): Check-Modus als Audit-Engine, `apply:`, Handler, der Schalter.
- Lektion [L11 - Profile, Ausnahmen und datengetriebene Rollen: eine Rolle, viele Adressaten](../../../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.de.md)
- Übung [4.01 - Reiner Audit-Lauf mit Compliance-Bericht](../../stage4-advanced/4.01-audit-only-report/README.de.md)
- Übung [4.02 - Profile (Level 1/2) und dokumentierte Ausnahmen](../../stage4-advanced/4.02-profiles-and-exceptions/README.de.md)
- Übung [4.03 - Datengetriebene Rolle für alle Plattformen (inkl. Alpine)](../../stage4-advanced/4.03-data-driven-multi-platform-role/README.de.md)
- Übung [5.02 - Rollout-Strategie: Vorabprüfung, Canary, Wellen](../5.02-rollout-strategy/README.de.md)

## Musterlösung

Anzeigen mit `lab solution 5.01`, anwenden mit `lab solve 5.01` (der Bericht liegt dann in
`/lab/work/5.01/reports`).
