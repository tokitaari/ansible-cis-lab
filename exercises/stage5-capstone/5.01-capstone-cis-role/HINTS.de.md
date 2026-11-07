# 5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus

## Hinweis 1

Starte von deiner 4.03-Rolle. Verschiebe die Tasks jedes Abschnitts in kleine Dateien unter `tasks/controls/`, eine pro Kontroll-ID, und leg die Registry-Liste an. Alles, was keine Kontrolle ist (vars laden, Vorabprüfung, Bericht), bleibt in `main.yml`.

## Hinweis 2

`include_tasks` + `apply: {check_mode: "{{ ansible_check_mode or cis_mode == 'audit' }}"}` führt eine ganze Datei im Check-Modus aus. Das `or` zählt: `"{{ cis_mode == 'audit' }}"` allein ist beim Enforce `false`, und `false` überschreibt `--check` - der Trockenlauf würde die Ziele ändern (siehe L10). Ein Trockenlauf im Enforce-Modus meldet eine Abweichung als `fail`, nicht als `fixed`. Lesende Tasks behalten `check_mode: false` - Task-Keywords schlagen geerbte. Ein Befund ist ein registriertes Ergebnis mit `changed: true` oder (bei `command`) `msg` 'Command would have run if not in check mode'. Handler brauchen `when: cis_mode == 'enforce'`.

## Hinweis 3

Bericht: auf `localhost` mit `run_once` + `delegate_to: localhost`, `check_mode: false`; sammle jeden Host, der ein `cis_summary` hat: `groups['all'] | map('extract', hostvars) | selectattr('cis_summary', 'defined') | map(attribute='inventory_hostname')` - nicht `ansible_play_hosts`, das unter `serial` (5.02) auch Hosts enthält, die noch nicht gelaufen sind. Die vollständige Referenz: `lab solution 5.01` - vergleiche *nachdem* du deine eigene Version hast.
