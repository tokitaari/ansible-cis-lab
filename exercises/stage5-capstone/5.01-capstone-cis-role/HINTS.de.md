# 5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus

## Hinweis 1

Starte von deiner 4.03-Rolle. Verschiebe die Tasks jedes Abschnitts in kleine Dateien unter `tasks/controls/`, eine pro Kontroll-ID, und leg die Registry-Liste an. Alles, was keine Kontrolle ist (vars laden, Vorabprüfung, Bericht), bleibt in `main.yml`.

## Hinweis 2

`include_tasks` + `apply: {check_mode: "{{ ansible_check_mode or cis_mode == 'audit' }}"}` führt eine ganze Datei im Check-Modus aus. Das `or` zählt: `"{{ cis_mode == 'audit' }}"` allein ist beim Enforce `false`, und `false` überschreibt `--check` - der Trockenlauf würde die Ziele ändern (siehe L10). Ein Trockenlauf im Enforce-Modus meldet eine Abweichung als `fail`, nicht als `fixed`. Lesende Tasks behalten `check_mode: false` - Task-Keywords schlagen geerbte. Ein Befund ist ein registriertes Ergebnis mit `changed: true` oder (bei `command`) `msg` 'Command would have run if not in check mode'. Handler brauchen `when: cis_mode == 'enforce'`.

## Hinweis 3

Die `tasks/control.yml` der Rolle, die `tasks/main.yml` einmal je Registry-Eintrag ausführt
(`include_tasks` mit `loop: "{{ cis_controls }}"` und `loop_var: cis_control`):

```yaml
- name: "Decide whether the control applies | {{ cis_control.id }}"
  ansible.builtin.set_fact:
    cis_control_state: "..."      # excepted / out-of-profile / not-applicable / active
    cis_control_results: []

- name: "Execute control | {{ cis_control.id }}"
  ansible.builtin.include_tasks:
    file: "..."                   # controls/<file> aus dem Registry-Eintrag
    apply:
      check_mode: "..."           # Probelauf im Audit-Modus und bei --check
  when: "..."                     # nur aktive Kontrollen

- name: "Record the result | {{ cis_control.id }}"
  vars:
    cis_noncompliant: "..."       # ein Ergebnis oder Schleifen-Eintrag changed oder 'would have run'
    cis_status: "..."             # der Zustand, sonst fail / fixed / pass
  ansible.builtin.set_fact:
    cis_findings: "..."           # cis_findings + ein Dict: id, level, title, status, reason
```

Bericht: auf `localhost` mit `run_once` + `delegate_to: localhost`, `check_mode: false` und `changed_when: false`; sammle jeden Host, der ein `cis_summary` hat: `groups['all'] | map('extract', hostvars) | selectattr('cis_summary', 'defined') | map(attribute='inventory_hostname')` - nicht `ansible_play_hosts`, das unter `serial` (5.02) auch Hosts enthält, die noch nicht gelaufen sind. Die vollständige Referenz: `lab solution 5.01` - vergleiche *nachdem* du deine eigene Version hast.
