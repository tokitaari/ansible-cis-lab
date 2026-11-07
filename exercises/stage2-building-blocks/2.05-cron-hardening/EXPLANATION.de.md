# 2.05 - Job-Scheduler: cron-Rechte und Zugriff: Erklärung

### Was der Check prüft
`lab check 2.05` führt `check.yml` auf allen acht Targets aus und dann dein Playbook noch einmal
mit `--check`; erwartet wird `changed=0` (`meta.yml` sagt `idempotency: true`). `check.yml`:
- macht `stat` auf `/etc/crontab`, die vier `cron.<periode>`-Verzeichnisse, `/etc/cron.d` und
  `/etc/crontabs`; jeder vorhandene Pfad muss `root:root` sein und darf kein Rechtebit für Gruppe
  oder andere haben;
- außer auf Alpine: `/etc/cron.allow` existiert, gehört root, ist für andere weder lesbar noch
  schreibbar und für die Gruppe nicht schreibbar;
- der cron-Dienst der Familie (Dict wie im README) läuft und ist aktiviert - auf systemd-Hosts
  meldet `service_facts` `enabled`, auf Alpine muss der Dienst im Runlevel `default` stehen.

Nicht geprüft wird: die genauen Modi (eine Crontab mit `0400` oder ein Verzeichnis mit `0500`
besteht auch), Inhalt und Gruppe von `cron.allow`, dass `cron.deny` weg ist, und dass du nichts
angelegt hast - ein auf Alpine erzeugtes `/etc/cron.d` besteht ebenfalls. Diese Teile des README
liegen bei dir.

### So funktioniert es

#### Härten, was existiert
Die Lösung hält eine Liste von `{path, mode}`-Dicts, macht `stat` auf jeden Pfad und dann einen
`file`-Task mit `when: item.stat.exists` über die Ergebnisse (`item.item.path`,
`item.item.mode`). Fehlende Pfade werden übersprungen, nicht angelegt: ein Verzeichnis, das das
installierte cron nicht liest, *sähe* für einen Scanner nur konform aus. Härte, was existiert;
erfinde keine Konfiguration.

#### Eine Absicht, vier Dienstnamen
`cron`, `crond`, `cronie`: das Dict mit `ansible_facts.os_family` als Schlüssel hält den Task
selbst auf allen Hosts gleich. In Stufe 3 wandert dieses Dict in `vars/<familie>.yml` der Rolle.

#### Was Allow- und Deny-Liste steuern
Gemessen für Lektion L06 (Debian-cron 3.0pl1, cronie 1.7.1, BusyBox-crond 1.36.1/1.37.0):
- `cron.allow` gewinnt gegen `cron.deny`; root darf `crontab` immer benutzen; eine leere
  `cron.allow` heißt: nur root.
- Ohne beide Dateien lässt Debians cron jeden Benutzer `crontab` ausführen, cronie nur root.
- Die Listen steuern den Befehl `crontab`, nicht laufende Jobs: die vorhandene Crontab eines
  Benutzers lief weiter, nachdem `cron.allow` ihn ausgeschlossen hatte (cron und cronie). Entferne
  auch die Spool-Datei.
- BusyBox unterstützt `cron.allow`/`cron.deny` gar nicht, und sein `crontab` weist Benutzer außer
  root ab, solange es nicht setuid installiert ist ("must be suid"). Die nächstliegende Kontrolle
  ist das Spool-Verzeichnis `/etc/crontabs`.

Mit `cron.allow` wird `cron.deny` ignoriert; die Lösung entfernt sie, damit niemand eine Liste
liest, die nichts bewirkt (Bonus 1).

#### Unsichere Dateien werden still übersprungen
Die Daemons scheitern nicht an einer Datei, die sie für unsicher halten - sie überspringen sie und
schreiben höchstens eine Logzeile. Gemessen: Debians cron und cronie ignorieren eine für Gruppe
oder andere schreibbare Datei in `/etc/cron.d` und eine `/etc/crontab` mit `0666`; cronie
überspringt zusätzlich Dateien, die nicht root gehören, und in `/etc/cron.d` Dateien mit
Ausführungsbit (`BAD FILE MODE`, `WRONG FILE OWNER`); Debians cron überspringt Namen mit Punkt und
einen zweiten Hardlink. Eine zu offene Datei ist keine Fehlermeldung, sondern ein Job, der nie
läuft.

#### N/A ist ein legitimes Ergebnis
Eine Kontrolle kann *nicht anwendbar* sein (BusyBox hat keine Allow-Liste). Schreib auf, warum
(Kommentar, Ausnahmeliste), und setz die nächstliegende gleichwertige Kontrolle um
(`/etc/crontabs` `0700`). Auditoren akzeptieren ein dokumentiertes N/A, kein Schweigen.

### Hinweise je Familie
| `os_family` | Hosts | cron / Dienst | Zu Beginn (frische Targets) |
|---|---|---|---|
| Debian | debian, ubuntu | Debian-cron / `cron` | `/etc/crontab` `0644`, Verzeichnisse `0755`, keine `cron.deny` |
| RedHat | rocky, alma, fedora | cronie / `crond` | `/etc/crontab` `0644`, Verzeichnisse `0755`, leere `cron.deny` `0644` |
| Suse | opensuse | cronie / `cron` | `/etc/crontab` `0600`, Verzeichnisse `0755`, `cron.deny` (6 Byte) `0600` |
| Archlinux | arch | cronie / `cronie` | `/etc/crontab` `0644`, Verzeichnisse `0755`, `cron.deny` (74 Byte) `0644` |
| Alpine | alpine | BusyBox-crond / `crond` | keine `/etc/crontab`, keine `cron.*`-Verzeichnisse; `/etc/crontabs` `0755` mit der Crontab von root |

Kein Target hat zu Beginn eine `cron.allow`, `at` oder `atd` (Bonus 2: `at` ist auf keinem
installiert).

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| Ein Job in `/etc/cron.d` läuft nie, kein Fehler | die Datei ist für Gruppe oder andere schreibbar, gehört nicht root oder ist (cronie) ausführbar | `0644` oder `0600`, `root:root`, kein Ausführungsbit |
| Auf Debian darf noch jeder `crontab` ausführen | keine der Listen existiert, also erlaubt Debians cron allen | `cron.allow` anlegen |
| Die Jobs eines ausgeschlossenen Benutzers laufen weiter | die Listen schützen nur den Befehl `crontab` | auch die Spool-Datei des Benutzers entfernen |
| `cron.allow` auf Alpine ändert nichts | BusyBox liest sie nicht | `/etc/crontabs` einschränken, das N/A dokumentieren |
| Der Check besteht, das README ist nicht erfüllt | er prüft "keine Bits für Gruppe/andere", nicht den genauen Modus | genau `0600`/`0700`/`0640` setzen |

### Praxis-Hinweise
- `root` allein in `cron.allow` heißt, nur root darf `crontab -e` ausführen. Dienstkonten mit
  eigener Crontab müssen eingetragen werden. In der Praxis sind Dateien `/etc/cron.d/<app>` aus dem
  Konfigurationsmanagement besser - sichtbar, prüfbar, versioniert.
- Auch systemd-Timer planen Jobs, und keine dieser Dateien steuert sie: `systemctl list-timers`
  zeigte auf jedem der sieben systemd-Targets zwei bis sechs Timer.

### Weiterführend
- Lektion [L06 - Job-Scheduler: wer führt was aus und wer darf planen](../../../docs/lessons/L06-job-schedulers.de.md): die drei Implementierungen, die Listen, was die Daemons überspringen - die Konzepte vor dieser Übung.
- Lektion [L04 - Plattformunterschiede als Daten: Dictionaries, Schleifen, Jinja2 und Templates](../../../docs/lessons/L04-platform-differences-as-data.de.md): der Dict-Lookup und die `stat`-Schleifen, die hier vorkommen.

## Musterlösung

Anzeigen mit `lab solution 2.05`, anwenden mit `lab solve 2.05`.
