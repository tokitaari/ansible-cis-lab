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

### creates reicht bei poll: 0 nicht
`creates: /var/lib/aide/aide.db` macht einen Befehl normalerweise idempotent: übersprungen,
wenn die Datei existiert. Mit `poll: 0` ist das Task-Ergebnis aber nur "Job gestartet" -
`changed`, bei jedem Lauf, auch unter `--check`. Das Modul (und sein `creates:`-Test) läuft
später im Hintergrund, und niemand sieht sich sein Ergebnis an. Also *vor* dem Start des Jobs
entscheiden:
```yaml
- ansible.builtin.stat:
    path: /var/lib/aide/aide.db
  register: db
- ansible.builtin.command:
    cmd: aideinit -y -f
    creates: /var/lib/aide/aide.db
  async: 1800
  poll: 0
  register: job
  when: not db.stat.exists
```
Jetzt zeigt der zweite Lauf `skipped`, der Warte-Task wird ebenfalls übersprungen (keine
Job-ID), und beim ersten Lauf meldet `async_status` das echte Ergebnis. `creates:` bleibt als
Absicherung, falls sich zwei Läufe überschneiden.

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
