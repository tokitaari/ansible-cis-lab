# 4.02 - Profile (Level 1/2) und dokumentierte Ausnahmen: Erklärung

### Das Muster
```yaml
- name: L2-modules | Level 2 kernel modules
  when:
    - cis_level | int >= 2
    - "'l2-modules' not in cis_exception_ids"
  block:
    - name: L2-modules | Disable squashfs and udf
      ansible.builtin.copy: ...
```
`when` an einem Block wird an jeden Task vererbt → übersprungene Tasks erscheinen als
*skipped* in der Ausgabe und im JSON-Callback, genau das prüft der Check.

### Eingaben validieren, bevor etwas angefasst wird
Härtungsrollen bekommen Eingaben von vielen Leuten (Inventar, CI-Variablen, `-e`). Ein
Tippfehler in einer Ausnahme-ID deaktiviert still nichts - oder schlimmer, das Falsche.
Früh und mit klarer Meldung scheitern. Die Datumsprüfung macht aus einer vergessenen
Ausnahme eine rote Pipeline statt eines dauerhaften Lochs.

### YAML-Datumswerte
`expires: 2027-01-31` wird von YAML als `date`-Objekt gelesen; `"2027-01-31"` bleibt ein
String. `| string | to_datetime('%Y-%m-%d')` normalisiert beides.

### Vertragstests
Der Check sieht deine Dateien nie an. Er startet das Playbook mit
`ANSIBLE_STDOUT_CALLBACK=ansible.posix.json` und wertet aus, welche Tasks übersprungen
wurden. So testet man Infrastrukturcode von außen - und deshalb sind stabile Task-Namen wichtig.

### Praxis
Ausnahmen in Git neben dem Inventar ablegen (`group_vars/<env>/cis_exceptions.yml`), nur
über geprüfte Merge Requests ändern, Ticketnummer in `reason`. Der Compliance-Bericht
(5.01) listet sie, damit Auditoren das ganze Bild sehen.

## Musterlösung

Anzeigen mit `lab solution 4.02`, anwenden mit `lab solve 4.02`.
