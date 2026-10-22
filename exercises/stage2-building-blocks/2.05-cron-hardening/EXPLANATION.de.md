# 2.05 - Job-Scheduler: cron-Rechte und Zugriff: Erklärung

### Lösung
Siehe `lab solution 2.05`. Der Aufbau:
1. `stat` auf alle Kandidatenpfade (Liste von `{path, mode}`-Dicts),
2. `file` mit `when: item.stat.exists` - nicht vorhandene Pfade werden übersprungen, nicht angelegt,
3. `cron.allow` per `copy`, auf Alpine übersprungen,
4. Dienst aktiviert/gestartet mit Namens-Lookup.

### Warum nicht `state: directory` für alle cron-Verzeichnisse?
Verzeichnisse anzulegen, die das installierte cron gar nicht liest, würde für einen
Scanner nur *konform aussehen*. Härte, was existiert; erfinde keine Konfiguration.

### N/A ist ein legitimes Ergebnis
Eine Kontrolle kann *nicht anwendbar* sein (busybox-crontab hat keine Positivliste).
Schreib auf warum (Kommentar, Ausnahmeliste) und setze die nächstliegende Kontrolle
um (`/etc/crontabs` 0700). Auditoren akzeptieren ein dokumentiertes N/A, kein Schweigen.

### Inhalt von `cron.allow`
Nur `root` heißt: nur root darf `crontab -e` ausführen. Dienstkonten mit eigenen
Crontabs müssen gelistet werden. In der Praxis lieber `/etc/cron.d/<app>`-Dateien per
Konfigurationsmanagement ausrollen - sichtbar, prüfbar, versioniert.

### Lektion über Variabilität
Vier Dienstnamen für "cron" bei fünf Familien. Facts + Datenstrukturen halten das
Playbook lesbar. In Stufe 4 verschiebst du das in `vars/<familie>.yml` einer Rolle.

## Musterlösung

Anzeigen mit `lab solution 2.05`, anwenden mit `lab solve 2.05`.
