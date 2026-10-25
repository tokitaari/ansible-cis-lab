# 4.03 - Datengetriebene Rolle für alle Plattformen (inkl. Alpine): Erklärung

### Daten schlagen Verzweigungen
Vergleiche:
```yaml
# verzweigt
- when: ansible_facts.os_family in ['Debian', 'RedHat']
# datengetrieben
- when: cis_pwquality_supported
```
Die zweite Version sagt, *warum* der Task läuft. Eine neue Plattform zu unterstützen
heißt dann: eine vars-Datei und eine Prüfung der Flags - keine Änderung an der
Task-Logik, kein Risiko für bestehende Plattformen.

### Die Variablenhierarchie
`first_found` liefert die spezifischste vorhandene Datei. Typische Nutzung:
- `Rocky-9.yml` vs. `Rocky-10.yml` für Versionsunterschiede (z. B. Crypto-Policies),
- `Ubuntu.yml` für reines Ubuntu-Verhalten innerhalb der Debian-Familie (Snaps, `ssh.socket`),
- `default.yml` mit konservativen Werten, damit eine unbekannte Plattform nicht abstürzt.
Achtung: es lädt **eine** Datei. Für Schichtung (Familie + Distribution) zwei
`include_vars`-Aufrufe, Familie zuerst.

### Alpine als vollwertige Plattform
Alpine erzwingt die ehrlichen Fragen: kein PAM (kein pwquality), busybox-crontab (kein
cron.allow), OpenRC (andere Dienstnamen), kein Python vor dem Bootstrap. Jede wird ein
Flag mit Kommentar zur kompensierenden Kontrolle oder dokumentierten Lücke.

### Regressionstests
Du hast gerade eine Rolle geändert, die acht Plattformen härtet. Die früheren Checks sind
dein Sicherheitsnetz - nach jedem Refactoring ausführen (`lab check 4.03` erledigt das).

## Musterlösung

Anzeigen mit `lab solution 4.03`, anwenden mit `lab solve 4.03`.
