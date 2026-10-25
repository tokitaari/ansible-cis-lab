# 4.01 - Reiner Audit-Lauf mit Compliance-Bericht: Erklärung

### Aufbau der Lösung
1. **Sammeln** - `package_facts`, `service_facts`, `stat`, `slurp`, `command` (sshd -T,
   sysctl). Alles lesend; `command` bekommt `changed_when: false` und `check_mode: false`.
2. **Bewerten** - ein `set_fact` baut `cis_results`, eine Liste von Dicts. Jeder Status ist
   ein Jinja-Ausdruck. Hier kann nichts scheitern.
3. **Zusammenführen** - ein Play auf `localhost` liest `hostvars[h].cis_results` für jedes
   Target, berechnet Scores und schreibt JSON + Markdown.

### Warum nicht `assert` + `ignore_errors`?
`assert` stoppt den Host beim ersten Fehler (oder zeigt mit `ignore_errors` rotes
Rauschen und liefert trotzdem keine strukturierten Daten). Ausdrücke liefern *Daten*.

### `check_mode: false` an lesenden Tasks
Unter `--check` wird ein `command`-Task übersprungen (er kann seine Wirkung nicht
vorhersagen). Ein reiner Leser ist sicher, also überschreibst du das. So ist dein
Audit-Play selbst in `--check`-Pipelines nutzbar.

### n/a vs. pass
Eine nicht anwendbare Kontrolle (busybox-`cron.allow`) ist weder pass noch fail. n/a als
pass zu zählen bläht Scores auf; als fail bestraft es Plattformen. Getrennt halten und
aus dem Score herausnehmen.

### Die Zeitstempel-Frage (Bonus)
Ein Zeitstempel ändert die *Berichtsdatei* bei jedem Lauf. Das ist ok - der Bericht liegt
auf dem Control Node und ist eine Ausgabe, kein verwalteter Zustand. Die Idempotenzregel
gilt für die Systeme, die du verwaltest.

### Nächster Schritt
Das Abschlussprojekt (5.01) baut diese Idee in die Rolle selbst ein: jede Kontrolle läuft
im *Audit*-Modus über den Check-Modus und wird automatisch protokolliert.

## Musterlösung

Anzeigen mit `lab solution 4.01`, anwenden mit `lab solve 4.01`.
