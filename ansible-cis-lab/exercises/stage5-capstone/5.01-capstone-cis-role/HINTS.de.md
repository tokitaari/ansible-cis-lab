# 5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus

## Hinweis 1

Starte von deiner 4.03-Rolle. Verschiebe die Tasks jedes Abschnitts in kleine Dateien unter `tasks/controls/`, eine pro Kontroll-ID, und leg die Registry-Liste an. Alles, was keine Kontrolle ist (vars laden, Vorabprüfung, Bericht), bleibt in `main.yml`.

## Hinweis 2

`include_tasks` + `apply: {check_mode: "{{ cis_mode == 'audit' }}"}` führt eine ganze Datei im Check-Modus aus. Lesende Tasks behalten `check_mode: false` - Task-Keywords schlagen geerbte. Ein Befund ist ein registriertes Ergebnis mit `changed: true` oder (bei `command`) `msg` 'Command would have run if not in check mode'. Handler brauchen `when: cis_mode == 'enforce'`.

## Hinweis 3

Bericht: auf `localhost` mit `run_once` + `delegate_to: localhost`, `check_mode: false`; sammle `ansible_play_hosts | map('extract', hostvars, 'cis_summary')`. Die vollständige Referenz: `lab solution 5.01` - vergleiche *nachdem* du deine eigene Version hast.
