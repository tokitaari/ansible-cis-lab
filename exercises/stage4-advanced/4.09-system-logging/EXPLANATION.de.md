# 4.09 - Systemprotokollierung: ein Logger je Host, gewählt über Daten: Erklärung

### Was der Check prüft
`lab check 4.09` führt `check.yml` auf allen acht Targets aus und dann dein Playbook noch einmal
mit `--check`; erwartet wird `changed=0` (`meta.yml` sagt `idempotency: true`). Der Check kennt
dieselbe Tabelle wie die README und prüft jeden Host auf seinen Logger:

- **systemd-Hosts:** Er liest `systemd-analyze cat-config systemd/journald.conf`, behält den
  letzten Wert jedes Schlüssels und prüft `Storage=persistent`, `Compress=yes`, `SystemMaxUse`
  als Zahl mit optionalem `K`/`M`/`G`/`T`, auf den Hosts mit nur journald `ForwardToSyslog=no`,
  und mindestens ein `system.journal` unter `/var/log/journal`.
- **RedHat-Familie:** `rsyslogd -N1` endet mit 0, `rsyslog` ist `enabled` und `active`, in
  `rsyslog.conf` oder `rsyslog.d/*.conf` steht mindestens eine `$FileCreateMode`-Zeile und keine
  ist lockerer als 0640, keine nicht auskommentierte Zeile nennt `imtcp` oder `imudp`, eine
  `logger`-Zeile mit dem Hostnamen erscheint innerhalb von fünf Sekunden in `/var/log/messages`,
  und `/var/log/messages` und `/var/log/secure` existieren mit einem Modus, der nicht lockerer
  als 0640 ist.
- **Alpine:** `rc-update show default` listet `syslog`, genau ein `/sbin/syslogd` läuft, und
  sowohl `SYSLOGD_OPTS` als auch die laufende Befehlszeile enthalten `-s` und `-b` mit einem Wert
  ungleich null.

Nicht geprüft wird, ob die Wahl in einem Dict steht oder ein `assert` sie absichert, wohin deine
journald-Einstellungen geschrieben werden (eine geänderte Hauptdatei besteht, wo es eine gibt),
ob die Modus-Zeile wirkt, ob `rsyslogd -N1` *vor* dem Neustart lief, und der Modus von
`/var/log/messages` auf Alpine. Gemessen mit der Musterlösung: Der Check schlägt in einem frischen
Lab auf allen sieben systemd-Hosts fehl; der erste Lauf ändert 8 Tasks auf rocky, alma und fedora,
5 auf debian und ubuntu, 4 auf arch, 3 auf opensuse und alpine; der zweite Lauf und `--check`
ändern nichts; der ganze Runner-Job (`tools/run-solutions.sh 4.09`: Reset, 0.02, Lösung, Check,
zweiter Lauf) dauerte 157 s.

### So funktioniert es

#### Die Wahl ist Daten
```yaml
cis_logger_by_family: {Debian: journald, RedHat: rsyslog, Suse: journald,
                       Archlinux: journald, Alpine: syslogd}
cis_logger: "{{ cis_logger_by_family[ansible_facts.os_family] }}"
```
Jeder Block des Plays hat ein `when:` auf `cis_logger`, nie auf die Familie. Um eine Familie auf
einen anderen Logger umzustellen, änderst du einen Wert (oder überschreibst `cis_logger` in
`host_vars`), und das `assert` stoppt einen Tippfehler vor der ersten Änderung, statt still jeden
Block zu überspringen.

#### Der wirksame Wert, nicht der Wert in deiner Datei
journald liest seine Hauptdatei, dann alle Drop-ins, nach Dateinamen sortiert *über* `/etc`,
`/run` und `/usr/lib` hinweg. Auf debian und ubuntu liefert das Paket `systemd`
`/usr/lib/systemd/journald.conf.d/syslog.conf` mit `ForwardToSyslog=yes`; `syslog.conf` sortiert
nach `60-cis.conf`, also gewinnt es (gemessen: `cat-config` listet es nach dem Drop-in des Labs).
Eine Datei mit gleichem Namen in `/etc` ersetzt eine Herstellerdatei, und ein Symlink auf
`/dev/null` entfernt sie - nach dem Maskieren gibt `cat-config` den Namen des Links aus und nichts
darunter. Die Lösung findet die Herstellerdateien mit `find` und `contains: "^ForwardToSyslog="`,
hängt also nicht vom Namen ab. Auf opensuse heißt die Herstellerdatei `20-defaults-SUSE.conf`
(`Audit=no`) und bleibt.

#### Persistent heißt: geflusht
`Storage=persistent` plus Neustart reichte auf rocky und alma nicht, die kein `/var/log/journal`
haben: journald meldete "Runtime Journal (/run/log/journal/...)". Erst `journalctl --flush` ließ
es das Verzeichnis anlegen und umschalten ("System Journal (/var/log/journal/...)"); danach
existiert die Flag-Datei `/run/systemd/journal/flushed`, und ein späterer Neustart schreibt sofort
nach `/var`. Die Lösung hat deshalb zwei Handler mit `listen: journald config changed`: Neustart,
dann Flush, in der Reihenfolge des Abschnitts `handlers:`.

#### Eine Prüfung der ganzen Konfiguration vor dem Neustart
`rsyslogd -N1 -f <drop-in>` endet für ein *gültiges* Drop-in mit 1 ("no active actions
configured"), also kann `validate:` ein Drop-in allein nicht prüfen. `rsyslogd -N1` prüft die
ganze Konfiguration samt Drop-in; es fand eine unbekannte Direktive, ein fehlendes Modul und ein
überzähliges Zeichen (jeweils Exit-Code 1). `systemctl restart rsyslog` gelang mit jedem dieser
kaputten Drop-ins (`active`), also bemerkt nur die Prüfung den Fehler. Als Task zwischen dem
Drop-in und dem Ende des Plays stoppt ein Fehler den Host, und seine ausstehenden Handler laufen
nicht.

#### Was `$FileCreateMode` wirklich tut
Die Unit `rsyslog` setzt `UMask=0066` (gemessen auf rocky und fedora), und das Skript des Pakets
läuft über `messages`, `secure`, `maillog` und `spooler`: Sie existieren vor dem ersten Start mit
0600 und gehören keinem Paket. Eine Probe mit `$FileCreateMode 0400` ergab auf fedora
(Legacy-Action-Zeilen in `rsyslog.conf`) ein frisches `messages` mit 0400, auf rocky aber 0600:
el10 (alma hat dieselbe `rsyslog.conf`) schreibt seine Actions als `action(type="omfile" ...)`,
und Legacy-Direktiven wirken nicht auf RainerScript-Objekte (omfile-Dokumentation). Auf rocky und
alma ist die Zeile das, wonach ein Audit der Konfiguration sucht, während die umask der Unit die
Dateien auf 0600 hält.

### Hinweise je Familie
| `os_family` | Hosts | Vorher | Die Lösung ändert | Hersteller-Drop-in |
|---|---|---|---|---|
| Debian | debian, ubuntu | journald persistent, `ForwardToSyslog=yes` | Drop-in, `syslog.conf` maskieren, Neustart, Flush | `syslog.conf` (Paket `systemd`) |
| RedHat | rocky, alma / fedora | journald flüchtig / persistent, kein rsyslog | Drop-in, rsyslog + Drop-in, Neustart, Flush | keins |
| Suse | opensuse | journald persistent | Drop-in, Neustart, Flush | `20-defaults-SUSE.conf` (`Audit=no`) |
| Alpine | alpine | `syslogd -t` läuft, in keinem Runlevel | `SYSLOGD_OPTS`, Runlevel `default`, Neustart | - |
| Archlinux | arch | journald persistent | Drop-in, Neustart, Flush | keins |

Nach der Lösung meldete journald "max 200M" auf den gemessenen Hosts (debian, ubuntu, fedora,
opensuse, arch). Auf rocky und alma legte der Flush die Journal-Datei mit 0640 `root:root` an, die
anderen Hosts haben `root:systemd-journal`; `systemd-journald.service(8)` empfiehlt
`systemd-tmpfiles --create --prefix /var/log/journal`, um einem neuen Verzeichnis den richtigen
Besitzer und Modus zu geben.

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Abhilfe |
|---|---|---|
| `ForwardToSyslog=no` steht in deiner Datei, `cat-config` endet mit `yes` | ein Hersteller-Drop-in sortiert nach deinem | mit einem `/dev/null`-Link gleichen Namens maskieren |
| `Storage=persistent`, trotzdem "Runtime Journal" | journald wartet auf eine Flush-Anforderung | `journalctl --flush` nach dem Neustart |
| `validate: rsyslogd -N1 -f %s` scheitert an einem korrekten Drop-in | ein Drop-in hat keine Actions | die ganze Konfiguration mit `rsyslogd -N1` prüfen |
| rsyslog ist `active` mit einer kaputten Zeile | rsyslog startet und protokolliert den Fehler | der `-N1`-Task vor dem Neustart |
| `$FileCreateMode 0640`, die Dateien haben 0600 | `UMask=0066` in der Unit; auf el10 wirkt die Zeile nicht auf `action()` | den Modus der Dateien lesen, nicht nur die Zeile |
| `module(load="builtin:omfile" fileCreateMode=...)` scheitert | `omfile` ist in `rsyslog.conf` schon geladen | eine Legacy-Zeile oder `fileCreateMode` je Action |
| `Destination directory /etc/systemd/journald.conf.d does not exist` | nur opensuse liefert es in `/etc` mit | zuerst ein `ansible.builtin.file`-Task mit `state: directory` |
| `rsyslogd -N1` scheitert mit `capng_apply=-4` (Fehler -2455) auf rocky/alma | das rsyslog von el10 kann auf manchen Host-Kerneln im Container seine Capabilities nicht abgeben | das `00-lab-container.conf` des Images (`libcapng.default="off"`, CONTAINER_LIMITS) |
| `logger: command not found` auf opensuse | das Image hat kein `logger` | `systemd-cat` (L15) |
| Ein Neustart von `syslog` startet auch `crond` neu | `crond` braucht `logger` (OpenRC) | erwartet; einplanen |

### Praxis-Hinweise
- Der Benchmark will einen Logger; ein zweiter verdoppelt den Plattenverbrauch und die Orte, an
  denen man suchen muss. Auf der RedHat-Familie liest rsyslog das Journal, also braucht journald
  trotzdem seine Speicher- und Größeneinstellungen.
- Ein lokales Log geht mit dem Host verloren. Leite an einen zentralen Host über TLS weiter
  (rsyslog `omfwd` mit einem `StreamDriver` oder `systemd-journal-upload`) und entscheide, wie
  viel der Sender puffert, solange der zentrale Host nicht erreichbar ist.
- Prüfe die Rotation: journald begrenzt sich selbst; Dateien, die rsyslog schreibt, brauchen
  `logrotate`, das auf debian und ubuntu mit rsyslog kam und auf der RedHat-Familie schon
  installiert war.

### Weiterführend
- Lektion [L15 - Systemprotokollierung](../../../docs/lessons/L15-system-logging.de.md): die Wege einer Nachricht, journald-Drop-ins und Speicher, rsyslog-Syntax und -Prüfungen, `listen`, BusyBox-syslogd - die Konzepte vor dieser Übung.
- Übung [4.08 - Dateiintegrität mit AIDE](../4.08-aide-async/README.de.md): der andere Teil von Abschnitt 6 (6.1), der vollständig in den Containern läuft.

## Musterlösung

Anzeigen mit `lab solution 4.09`, anwenden mit `lab solve 4.09`.
