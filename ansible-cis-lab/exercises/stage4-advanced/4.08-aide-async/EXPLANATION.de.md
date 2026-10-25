# 4.08 - Dateiintegrität mit AIDE - lang laufende Tasks: Erklärung

### async in drei Zeilen
```yaml
- command: aide --init ...
  async: 1800      # maximale Laufzeit
  poll: 0          # nicht warten - abfeuern und vergessen
  register: job
- async_status: jid="{{ job.ansible_job_id }}"
  register: r
  until: r.finished
  retries: 120
  delay: 15
```
Alle fünf Hosts starten ihren Scan innerhalb von Sekunden; die Warteschleife sammelt sie
dann ein. Mit `poll: 15` statt `0` würde Ansible pro Host blockieren, die Verbindung aber
kurzlebig halten - auch gültig, weniger parallel.

### creates = Idempotenz für Befehle
`creates: /var/lib/aide/aide.db` → der Befehl wird übersprungen, wenn die Datei existiert.
Im Check-Modus kann Ansible das auswerten, `--check` zeigt also `skipped`, nicht `changed`.

### Timer statt cron
systemd-Timer loggen ins Journal, unterstützen `Persistent=true` (verpasste Läufe nach
Ausfallzeit nachholen) und lassen sich auflisten (`systemctl list-timers`). CIS akzeptiert
für die periodische Prüfung cron oder einen Timer.

### Betriebsrealität
AIDE ohne Prozess ist Rauschen: nach jedem Patchlauf muss die Baseline aktualisiert
werden, und Alarme müssen jemanden erreichen. Das Werkzeug ist einfach - der Prozess
drumherum ist die Arbeit.

## Musterlösung

Anzeigen mit `lab solution 4.08`, anwenden mit `lab solve 4.08`.
