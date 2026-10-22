# 3.01 - Alles in eine Rolle überführen: Erklärung

### Aufbau der Referenzrolle
```
roles/cis/
├── defaults/main.yml        # jede Stellschraube, Präfix cis_
├── vars/{Debian,RedHat,Suse,Archlinux,Alpine,default}.yml
├── tasks/main.yml           # include_vars + Import pro Abschnitt
├── tasks/section{1,2,3,5,7}_*.yml
├── handlers/main.yml        # Reload sshd
├── templates/{banner,sshd_cis.conf}.j2
└── meta/main.yml            # Plattformen, min_ansible_version
```

### defaults vs. vars
| | `defaults/` | `vars/` |
|---|---|---|
| Vorrang | niedrigster - alles überschreibt ihn | hoch - schlägt das Inventar |
| Zweck | Stellschrauben für Nutzer (`cis_level`, sshd-Werte) | Fakten über Plattformen |
Faustregel: Wenn ein Nutzer einen anderen Wert wollen könnte, ist es ein Default.

### import vs. include
- `import_tasks` - statisch, beim Parsen aufgelöst; tags/when werden auf jeden Task
  kopiert; `--list-tasks` zeigt alles.
- `include_tasks` - dynamisch, zur Laufzeit aufgelöst; Tags gelten nur für das Include
  (außer mit `apply:`); nötig, wenn der Dateiname aus einer Variable kommt.
Abschnitte sind fest → `import_tasks`.

### Warum `always` an include_vars
Mit `--tags ssh` überspringt Ansible ungetaggte Tasks. Ohne die Plattform-vars kennt
der Handler `cis_sshd_service` nicht - `always` hält die Rolle bei jeder Tag-Auswahl konsistent.

### Das Refactoring testen
Die Checks von 0.04-2.06 *sind* deine Regressionstests: alle Hosts zurücksetzen, einmal
laufen lassen, alle Checks ausführen. Bestehen sie, hat das Refactoring das Verhalten
erhalten. Genau so werden größere Härtungsrollen entwickelt (Molecule automatisiert
dieselbe Idee).

### ansible-lint
Findet Module ohne FQCN, Modi ohne Anführungszeichen, fehlendes `changed_when`,
unbenannte Tasks, Rollenvariablen ohne Rollenpräfix - alles Dinge, die später beißen.

## Musterlösung

Anzeigen mit `lab solution 3.01`, anwenden mit `lab solve 3.01`.
