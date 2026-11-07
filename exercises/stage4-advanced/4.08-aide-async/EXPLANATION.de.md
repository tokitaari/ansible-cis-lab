# 4.08 - Dateiintegrität mit AIDE - lang laufende Tasks: Erklärung

### Was der Check prüft
`lab check 4.08` führt `check.yml` auf den fünf Hosts aus und dann dein Playbook noch einmal mit
`--check`; erwartet wird `changed=0` (`meta.yml` sagt `idempotency: true`). `check.yml` prüft
zwei Dinge: die Datenbankdatei existiert (`aide.db` auf Debian, `aide.db.gz` auf RedHat), und
`systemctl is-enabled cis-aidecheck.timer` sagt `enabled`.

Nicht geprüft wird, ob `async` benutzt wurde (ein normaler blockierender Befehl besteht, ebenso eine
leere Datei am Datenbankpfad), was die Datenbank enthält, der Text der Unit-Dateien, ob der Timer
aktiv ist oder ob die Unit läuft. Der zweite Lauf fängt die Falle aus `poll: 0` zusammen mit
`creates:`: der Start-Task wäre wieder `changed`. Gemessen im Lab mit der Musterlösung: der erste
Lauf zeigt auf allen fünf Hosts `changed=5`, der zweite Lauf und `--check` zeigen `changed=0`, Start-
und Warte-Task übersprungen.

### So funktioniert es

#### async in drei Zeilen
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
Alle fünf Hosts starten ihren Scan innerhalb von Sekunden; die Warteschleife sammelt sie dann ein.
`retries` mal `delay` (120 × 15 s) sollte `async` abdecken: gibt die Schleife vorher auf, scheitert
der Task, während der Job weiterläuft. Im Lab dauerten die Scans 9 bis 89 Sekunden (Tabelle unten).

`poll: 0` ist nicht das, was die Hosts parallel laufen lässt. Mit `poll: 15` wartet Ansible pro
Host und fragt alle 15 Sekunden nach; die Hosts laufen weiter nebeneinander, solange `forks` es
erlaubt. Die Lektion L09 hat vier Hosts mit einem 3-Sekunden-Job gemessen (Einzelläufe):
Vordergrund 3,9 s, `poll: 0` plus Warteschleife 5,1 s bei `forks=10`; 7,1 s, 5,9 s und (`poll: 1`)
9,1 s bei `forks=2`. Das Lab nutzt `forks = 10` für fünf Hosts, der Poll-Wert ändert hier also nichts;
Hintergrund-Jobs lohnen sich bei mehr Hosts als `forks`, bei anderer Arbeit im Play oder wenn der Job
eine Verbindung überleben soll.

#### creates reicht bei poll: 0 nicht
`creates: /var/lib/aide/aide.db` macht einen Befehl normalerweise idempotent: übersprungen, wenn die
Datei existiert. Mit `poll: 0` ist das Task-Ergebnis aber nur "Job gestartet" - `changed`, bei
jedem Lauf. Das Modul (und sein `creates:`-Test) läuft später im Hintergrund, und niemand sieht
sich sein Ergebnis an. Also *vor* dem Start des Jobs entscheiden:
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
Jetzt zeigt der zweite Lauf `skipped`, der Warte-Task wird ebenfalls übersprungen (keine Job-ID),
und beim ersten Lauf meldet `async_status` das echte Ergebnis. Auf einem Host ohne Datenbank zeigt
`--check` Start- und Warte-Task als `changed` und legt nichts an (gemessen).

`creates:` im Job ist nur eine letzte Absicherung. Ein langer Scan legt die Datenbank erst am Ende
an; ein zweiter Lauf, der startet, während der erste noch scannt, findet also keine Datenbank, passiert
das `stat` und startet einen zweiten Scan (gemessen mit einem Stellvertreter-Job: beide Jobs
liefen). Starte das Play nicht zweimal gleichzeitig gegen dieselben Hosts.

#### Timer statt cron
systemd-Timer loggen ins Journal, unterstützen `Persistent=true` (verpasste Läufe nach Ausfallzeit
nachholen) und lassen sich auflisten (`systemctl list-timers`). CIS akzeptiert für die periodische
Prüfung cron oder einen Timer. Die Lösung ergänzt `RandomizedDelaySec=30min`, damit viele Hosts nicht
im selben Moment starten.

#### Der Prüfbefehl und sein Exit-Code
`aide --check` liefert die Summe aus 1 (hinzugefügt), 2 (entfernt) und 4 (geändert), jeder Unterschied
gibt also einen Code ungleich 0 (L09). Gemessen direkt nach dem Init im Lab, endete der Befehl der
Unit auf debian und ubuntu mit 7 (11 hinzugefügt, 5 entfernt, 7 oder 8 geändert) und auf rocky, alma
und fedora mit 5 (4 hinzugefügt, 1 oder 2 geändert): die Container verändern zwischen Init und
Prüfung Dateien. Eine `Type=oneshot`-Unit, deren Befehl mit einem Wert ungleich 0 endet, gilt als
fehlgeschlagen (`systemd.service(5)`, hier nicht ausprobiert), der erste tägliche Lauf endet also
`failed`, bis die Baseline aktualisiert ist.

### Hinweise je Familie
| `os_family` | Hosts | Init | Datenbank (Größe) | Init-Dauer | Zurückgeblieben | Include-Zeilen |
|---|---|---|---|---|---|---|
| Debian | debian, ubuntu | `aideinit -y -f` | `/var/lib/aide/aide.db` (4,1 MB, 3,5 MB) | 29 s, 89 s | `aide.db.new`, `/var/log/aide/aideinit.log` | `@@x_include /etc/aide/aide.conf.d ^[a-zA-Z0-9_-]+$` |
| RedHat | rocky, alma, fedora | `aide --init` + `mv` | `/var/lib/aide/aide.db.gz` (0,9, 0,8, 1,1 MB) | 12 s, 9 s, 14 s | `/var/log/aide/aide.log` | keine, nur `@@define`-Zeilen |

Gemessen im Lab mit AIDE 0.19.1 (debian) und 0.19.2 (die anderen), ein Lauf. Debians Wrapper
`aideinit` ruft `aide --init` mit `/etc/aide/aide.conf` auf, `-y` überschreibt die Ausgabedatei, `-f`
die Datenbank; er kopiert, daher bleibt `aide.db.new` neben `aide.db` liegen. Debian und Ubuntu
liefern einen eigenen `dailyaidecheck.timer`, die RedHat-Familie keinen (L09). Der Timer war auf allen
fünf Hosts `enabled` und `active`.

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Lösung |
|---|---|---|
| Der Start-Task ist bei jedem Lauf `changed` | `poll: 0` meldet "gestartet"; `creates:` läuft später im Job | erst `stat`, `when: not ....stat.exists` |
| Zwei Scans laufen gleichzeitig | ein zweiter Lauf startete, bevor der erste Scan die Datenbank angelegt hatte | Läufe nicht überlappen lassen |
| `FAILED - RETRYING`-Zeilen | die Warteschleife hat `finished` noch nicht gesehen | nichts - sie scheitert erst, wenn die Wiederholungen aufgebraucht sind |
| `[WARNING]: Module invocation had junk after the JSON data` | eine Terminal-Escape-Sequenz in der Job-Ausgabe | harmlos, siehe `docs/TROUBLESHOOTING.de.md` |
| Die Unit ist direkt nach dem Init `failed` | die Prüfung fand Unterschiede (Exit-Code 1 bis 7) | Baseline nach dem Lesen des Reports aktualisieren |
| Ein Drop-in `99_local.conf` in `/etc/aide/aide.conf.d` bleibt wirkungslos | Debian liest nur Namen, die `^[a-zA-Z0-9_-]+$` entsprechen (gemessen: eine Datei mit Punkt wird ohne Meldung ignoriert) | nenne sie `99_local` |
| Job-Dateien bleiben in `/root/.ansible_async` | niemand sammelt mit `mode: cleanup` ein (L09) | im Lab nicht nötig |

### Praxis-Hinweise
- AIDE ohne Prozess ist Rauschen: nach jedem Patchlauf muss die Baseline aktualisiert werden, und
  Alarme müssen jemanden erreichen. Lies zuerst den Report, aktualisiere dann und befördere die neue
  Datenbank (L09). Das Werkzeug ist einfach - der Prozess drumherum ist die Arbeit.
- Um flüchtige Pfade auszulassen, nimmt Debian ein Drop-in in `aide.conf.d`; auf der RedHat-Familie
  bearbeitest du `/etc/aide.conf` oder ergänzt eine eigene Include-Zeile.
- Bewahre eine Kopie der Baseline außerhalb des Hosts auf: ein Angreifer mit root kann auch die
  Datenbank umschreiben.

### Weiterführend
- Lektion [L09 - Auditing und Integrität](../../../docs/lessons/L09-auditing-and-integrity.de.md): die AIDE-Datenbank, Exit-Codes, Timer und Units, `async` und die Idempotenz-Falle - die Konzepte vor dieser Übung.
- Übung [3.04 - auditd: Regeln und Log-Aufbewahrung](../../stage3-intermediate/3.04-auditd-rules/README.de.md): die erste Hälfte der Lektion.

## Musterlösung

Anzeigen mit `lab solution 4.08`, anwenden mit `lab solve 4.08`.
