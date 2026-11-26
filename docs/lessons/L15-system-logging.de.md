# L15 - Systemprotokollierung: journald, rsyslog und BusyBox-syslogd

*[English](L15-system-logging.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 4.09 | 6.2 | ~25 Min. | L02, L03, L04 |

Logs liest man, nachdem etwas schiefgegangen ist, und ein Angreifer will sie als Erstes
beseitigen. Der Benchmark verlangt wenig: ein Logger je Host, vollständig konfiguriert, seine
Dateien geschützt, seine Größe begrenzt. Die Arbeit steckt in den Details, die je Distribution
anders sind - welcher Daemon eine Nachricht empfängt, welche Datei zuletzt gelesen wird, wann eine
Einstellung wirklich gilt. Diese Lektion verfolgt eine Nachricht vom Programm bis auf die Platte,
erklärt, wie journald und rsyslog konfiguriert und geprüft werden, und behandelt die
Ansible-Werkzeuge, die eine solche Änderung sicher machen: eine Prüfung der ganzen Konfiguration
vor einem Neustart und Handler, die zusammengehören.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] die Wege beschreiben, die eine Nachricht zu journald, zu rsyslog und zu BusyBox-syslogd nimmt, und sagen, welchem Daemon `/dev/log` gehört
- [ ] aus einer Menge von journald-Drop-ins den wirksamen Wert vorhersagen und ein Hersteller-Drop-in ersetzen oder entfernen
- [ ] erklären, wann journald nach `/var/log/journal` schreibt und warum ein Neustart dafür nicht reichen kann
- [ ] eine rsyslog-Regel lesen, die beiden Konfigurationssyntaxen unterscheiden und eine Konfiguration vor einem Neustart prüfen
- [ ] mit `listen` mehrere Handler für eine Änderung in bekannter Reihenfolge laufen lassen
- [ ] bei einem OpenRC-Dienst "läuft" von "aktiviert" unterscheiden

## Theorie

### Eine Nachricht, mehrere Wege

Ein Programm, das auf die klassische Art protokolliert, schreibt eine kurze Zeile an den Socket
`/dev/log`: eine *Facility* (wer: `auth`, `authpriv`, `cron`, `mail`, `user`, `local0` ...
`local7`), eine *Priorität* (wie schlimm: `debug` ... `emerg`) und den Text. Auf einem
systemd-Host gehört dieser Socket journald (`systemd-journald-dev-log.socket` gibt es auf allen
sieben systemd-Targets). journald speichert jede Nachricht, mit viel mehr Feldern als die
Syslog-Zeile, in seinem binären Journal und liest sie mit `journalctl` wieder aus.

Ein klassischer Syslog-Daemon wie rsyslog bekommt die Nachrichten dann auf einem von zwei Wegen:

- **Er liest die Journal-Dateien**, so wie `journalctl`. Auf der RedHat-Familie lädt rsyslog
  `imjournal` und schaltet seinen eigenen Socket ab (`imuxsock` mit `SysSock.Use="off"`, gemessen
  auf rocky, alma und fedora).
- **journald leitet eine Kopie weiter** an einen zweiten Socket, wenn `ForwardToSyslog=yes` gilt,
  und rsyslog empfängt sie dort (`imuxsock`). Die `rsyslog.conf` von Debian, Ubuntu und openSUSE
  lädt `imuxsock`, und systemds `syslog.socket` startet rsyslog dort (gemessen: beim Stoppen von
  rsyslog warnt systemd, dass `syslog.socket` noch aktiv ist).

Welchen Weg eine Familie nutzt, entscheidet, was `ForwardToSyslog` sein muss. Auf rocky kam die
Testnachricht mit `ForwardToSyslog=no` einmal in `/var/log/messages` an und mit `yes` ebenfalls
einmal - `imjournal` braucht die Kopie nicht. Ohne Syslog-Daemon hat die Kopie keinen Empfänger.

Auf Alpine gibt es kein Journal: Der BusyBox-`syslogd` besitzt `/dev/log` und schreibt jede
Nachricht nach `/var/log/messages`.

Die Regeln des Syslog-Daemons entscheiden, in welcher Datei eine Nachricht landet. Dieselbe Zeile
`logger -p auth.info` landete auf debian in `/var/log/auth.log` und auf rocky in
`/var/log/messages`: Die Regeln von rocky schicken `authpriv` (nicht `auth`) nach
`/var/log/secure`.

Um selbst eine Nachricht zu senden, ist `logger` das klassische Werkzeug; das opensuse-Image hat
es nicht, `systemd-cat` (auf allen sieben systemd-Targets) schreibt direkt ins Journal:

```bash
ansible opensuse -b -m ansible.builtin.shell -a "echo hello from L15 | systemd-cat -t lesson15 && sleep 1 && journalctl -t lesson15 -n 1 --no-pager -o cat"
```

`-t` setzt den Bezeichner, und `journalctl -t` wählt danach aus. Das System-Journal zu lesen
braucht root oder die Mitgliedschaft in einer Gruppe wie `systemd-journal`, daher `-b`.

### journald: Dateien, Drop-ins und der wirksame Wert

journald liest eine Hauptdatei und danach seine Drop-ins. Wo die Hauptdatei liegt, ist
verschieden: debian, ubuntu und arch haben `/etc/systemd/journald.conf`; rocky, alma, fedora und
opensuse nur `/usr/lib/systemd/journald.conf` (systemd 257 bis 262 auf den Targets). So oder so
änderst du sie nicht - das Drop-in-Verzeichnis `/etc/systemd/journald.conf.d/` ist der Ort für
deine Einstellungen, und ein Paket kann eigene Drop-ins nach `/usr/lib/systemd/journald.conf.d/`
legen.

Die entscheidende Regel (`journald.conf(5)`): Die Drop-ins aller Verzeichnisse werden nach
**Dateinamen** sortiert, egal in welchem Verzeichnis sie liegen, und für einen Schlüssel mit nur
einem Wert gewinnt die zuletzt gelesene Datei. Zwei Folgen:

- Ein Hersteller-Drop-in kann über deines gewinnen. debian und ubuntu liefern
  `/usr/lib/systemd/journald.conf.d/syslog.conf` (Paket `systemd`) mit `ForwardToSyslog=yes`;
  `syslog.conf` sortiert nach einer Datei namens `60-irgendwas.conf`, also ist sein Wert der
  wirksame. opensuse liefert `20-defaults-SUSE.conf` mit `Audit=no`.
- Eine Datei in `/etc` mit **gleichem Namen** wie eine Herstellerdatei ersetzt sie, und ein
  Symlink dieses Namens auf `/dev/null` entfernt sie ("Maskieren"). Das ist der dokumentierte Weg,
  eine Herstellerdatei abzuschalten, ohne `/usr` anzufassen, wo das nächste Paket-Update deine
  Änderung zurücknehmen würde.

Die Reihenfolge musst du nicht von Hand ausrechnen. `systemd-analyze cat-config` gibt jede Datei in
der Reihenfolge aus, in der journald sie liest, jeweils nach einer Zeile `# /pfad`:

```bash
ansible 'targets:!alpine' -m ansible.builtin.shell -a "systemd-analyze cat-config systemd/journald.conf | grep -E '^# /.*[.]conf$|^[A-Za-z]+='"
```

Auf einem frischen debian endet die Ausgabe mit `# /usr/lib/systemd/journald.conf.d/syslog.conf`
und `ForwardToSyslog=yes`; auf rocky zeigt sie die Hauptdatei mit `Audit=` und sonst nichts. Die
letzte Zeile für einen Schlüssel ist sein wirksamer Wert - so liest ihn auch der Check von 4.09.
Eine maskierte Datei erscheint als ihre Zeile `# /etc/...` ohne etwas darunter.

### Wo das Journal liegt: Storage, Flush und Größe

`Storage=` entscheidet, wo das Journal liegt: `volatile` (in `/run/log/journal`, beim
Herunterfahren verloren), `persistent` (in `/var/log/journal`), `auto` (persistent, wenn
`/var/log/journal` existiert, sonst flüchtig) und `none`. Der Standard ist `auto`, also
entscheidet das Verzeichnis. Auf den frischen Targets existiert es auf debian, ubuntu, fedora,
opensuse und arch und fehlt auf rocky und alma: Deren Journal ist flüchtig.

`Storage=` zu ändern und journald neu zu starten ist nicht die ganze Geschichte. Beim Booten ist
`/var` vielleicht noch nicht eingehängt, also startet journald in `/run` und wartet, bis
`systemd-journal-flush.service` es zum Umzug auffordert (`journalctl --flush`). Gemessen auf rocky
und alma mit `Storage=persistent` in einem Drop-in:

```
systemctl restart systemd-journald   ->  Runtime Journal (/run/log/journal/...) is 8M, max 796.5M, 788.5M free.
journalctl --flush                   ->  Received client request to flush runtime journal.
                                         (/var/log/journal/<machine-id>/system.journal existiert jetzt)
systemctl restart systemd-journald   ->  System Journal (/var/log/journal/...) is 8M, max 4G, 3.9G free.
```

Der Flush legte `/var/log/journal` an und hinterließ die Flag-Datei
`/run/systemd/journal/flushed`; mit diesem Flag geht ein späterer Neustart direkt nach `/var`. Wie
jede Datei unter `/run` ist das Flag nach einem Neustart des Hosts weg, wenn der Flush beim Booten
wieder läuft.

Die Zeilen oben stammen von journald selbst: Nach einem Start protokolliert es, welches Journal es
nutzt, seine Größe und seine Grenze. `journalctl -u systemd-journald -n 1 --no-pager -o cat` (als
root) zeigt die neueste - der einfachste Beweis, dass eine Größeneinstellung wirkt. Die Grenze ist
`SystemMaxUse=` für das persistente Journal und `RuntimeMaxUse=` für das flüchtige; ihre
Standardwerte sind ein Anteil des Dateisystems mit einer Obergrenze (`journald.conf(5)`), was auf
der großen virtuellen Platte des Labs "max 4G" ergab. `Compress=` steht standardmäßig auf `yes`;
`journalctl --header` listet die Flags einer Datei, und jede Journal-Datei auf den Targets zeigte
`COMPRESSED-ZSTD`.

Einen Standardwert ausdrücklich zu setzen lohnt sich trotzdem: Der Wert hängt dann nicht mehr von
der Distribution ab, und ein Audit kann ihn finden.

### rsyslog: Regeln, zwei Syntaxen und eine Prüfung der ganzen Konfiguration

`/etc/rsyslog.conf` hat drei Teile: Module (Eingänge wie `imjournal`, `imuxsock`, `imtcp`), globale
Einstellungen und Regeln - ein *Selektor* (`facility.priority`) gefolgt von einer *Action* (meist
eine Datei). Ein `include` von `/etc/rsyslog.d/*.conf` holt Drop-ins an der Stelle herein, an der
es steht; auf allen vier Familien mit rsyslog steht es vor den Regeln. Zwei Syntaxen sind im
Gebrauch, und die Targets zeigen beide:

```
$FileCreateMode 0640                                    # Legacy-Direktive (debian, opensuse)
*.info;mail.none;authpriv.none;cron.none  /var/log/messages               # Legacy-Regel (fedora)
*.info;mail.none;authpriv.none;cron.none  action(type="omfile" file="/var/log/messages")   # el10
```

Der Unterschied ist mehr als Optik. Eine Legacy-Direktive wie `$FileCreateMode` gilt für die
Legacy-Regeln, die *nach* ihr folgen, und Legacy-Direktiven wirken nicht auf RainerScript-Objekte
wie `action(...)` (die `omfile`-Dokumentation von rsyslog). Gemessen mit einem Drop-in
`$FileCreateMode 0400`: Ein frisches `/var/log/messages` bekam auf fedora 0400 und auf rocky 0600.
Die 0600 kommen von woanders - die RedHat-Unit `rsyslog` setzt `UMask=0066` -, und deshalb war dort
auch jede rsyslog-Datei schon 0600. Eine Konfigurationszeile und der Modus der Datei sind zwei
verschiedene Fakten; prüfe beide.

Woher weißt du vor dem Neustart, dass eine Konfiguration gültig ist? `rsyslogd -N1` parst alles,
Includes und Module, und endet bei einem Fehler mit 1. Gemessen auf rocky und fedora mit drei
kaputten Drop-ins:

```
bogus_directive_xyz        -N1 Exit 1   Neustart ok, active
module(load="imnotthere")  -N1 Exit 1   Neustart ok, active
$FileCreateMode 0640x      -N1 Exit 1   Neustart ok, active
```

rsyslog startete jedes Mal und protokollierte nur seine Beschwerde. Ein Neustart ist kein Test.

[L02](L02-safe-changes.de.md) zeigte `validate:`, das eine Datei prüft, bevor sie die alte
ersetzt. Hier passt es nicht: `rsyslogd -N1 -f <datei>` prüft die Datei, als wäre sie die *ganze*
Konfiguration, und ein korrektes Drop-in hat keine Actions - Exit 1, "no active actions
configured". Der andere Weg ist ein Task, der die ganze Konfiguration *nach* dem Schreiben der
Datei und vor jedem Neustart prüft. Schlägt er fehl, schlägt der Host fehl, und die Handler, die er
benachrichtigt hatte, laufen nicht (außer du setzt `force_handlers`). Der Preis: Die kaputte Datei
bleibt auf der Platte, bis du sie reparierst, und der nächste Neustart aus irgendeinem Grund liest
sie.

Zwei weitere Teile von rsyslog zählen für den Benchmark: kein Netzwerk-Eingang, außer der Host
soll Logs sammeln (`imtcp`, `imudp` in einer Zeile `module(...)` oder `$ModLoad`; auf rocky, alma
und fedora war nach der Installation keiner aktiv), und Rotation - rsyslog schreibt einfache
Dateien, `logrotate` rotiert sie.

### Handler, die zusammengehören: `listen`

Ein Handler läuft einmal am Ende des Plays, wenn ein Task, der ihn mit `notify` benachrichtigt
hat, `changed` meldete ([L02](L02-safe-changes.de.md)). Manche Änderungen brauchen danach mehr als
eine Aktion - Daemon neu starten, ihm dann etwas mitteilen, dann testen. Du kannst `notify` eine
Liste von Handler-Namen geben, aber dann muss jeder Task, der die Änderung auslöst, die Liste
wiederholen. `listen:` dreht es um: Mehrere Handler hören auf ein Thema, und ein Task
benachrichtigt das Thema.

```yaml
- name: Handlers that listen to one topic
  hosts: debian
  become: true
  handlers:
    - name: Restart journald
      ansible.builtin.systemd_service:
        name: systemd-journald
        state: restarted
      listen: lesson journald changed

    - name: Say what happened
      ansible.builtin.debug:
        msg: "journald on {{ inventory_hostname }} was restarted"
      listen: lesson journald changed
  tasks:
    - name: Drop-in directory of journald
      ansible.builtin.file:
        path: /etc/systemd/journald.conf.d
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Keep the journal for one month at most
      ansible.builtin.copy:
        dest: /etc/systemd/journald.conf.d/90-lesson.conf
        content: |
          [Journal]
          MaxRetentionSec=1month
        owner: root
        group: root
        mode: "0644"
      notify: lesson journald changed
```

Der erste Lauf legt das Verzeichnis an - es fehlt auf einem frischen debian, ubuntu, rocky, alma,
fedora und arch - und die Datei, und führt beide Handler einmal aus; der zweite ändert nichts und
führt keinen aus. Handler laufen in der Reihenfolge des Abschnitts `handlers:`, nicht in der Reihenfolge
der Benachrichtigungen; dort legst du also "erst neu starten, dann der Rest" fest. `./lab.sh reset
debian` auf dem Host entfernt das Beispiel wieder.

### BusyBox-syslogd und OpenRC

Der `syslogd` von Alpine ist Teil von BusyBox; der OpenRC-Dienst heißt `syslog`. Seine Optionen
kommen aus `SYSLOGD_OPTS` in `/etc/conf.d/syslog` (`-t` auf einem frischen Target: die
Zeitstempel entfernen, die Clients mitschicken); das Init-Skript startet `/sbin/syslogd
${SYSLOGD_OPTS} -n`. Er rotiert selbst: `-s` ist die Größe in KB, ab der `/var/log/messages`
rotiert wird (Standard 200), `-b` die Zahl der aufbewahrten alten Dateien (Standard 1),
`-R host:port` leitet an einen entfernten Host weiter (BusyBox 1.37, `syslogd --help`).

Auf einem frischen alpine läuft `syslogd`, und doch listet `rc-update show` ihn in keinem
Runlevel:

```bash
ansible alpine -m ansible.builtin.command -a "rc-update show default"
ansible alpine -m ansible.builtin.shell -a "ps -o args | grep '[s]yslogd'"
```

OpenRC hat ihn gestartet, weil andere Dienste von ihm abhängen: `crond` hat `need logger`, `sshd`
hat `use logger`, und `syslog` stellt `logger` bereit (`rc-status -a` listet ihn unter
"needed/wanted"). Laufen ist nicht dasselbe wie aktiviert: OpenRC startet ihn nur, solange etwas
von ihm abhängt. `ansible.builtin.service` mit `enabled: true` nimmt einen Dienst auf OpenRC in
den Runlevel `default` auf, so wie es auf systemd eine Unit aktiviert. Die Abhängigkeit wirkt auch
in die andere Richtung: Ein Neustart von `syslog` stoppte und startete auch `crond` (gemessen).

## CIS-Hintergrund

Abschnitt 6.2 der aktuellen Benchmarks behandelt die Systemprotokollierung ([der
Kontrollkatalog](../../cis-catalogue/controls.yml): 6.2, Level 1). In eigenen Worten verlangen die
Empfehlungen: einen gewählten und laufenden Protokolldienst; journald mit persistentem Speicher,
Kompression und Größengrenzen; wenn rsyslog der gewählte Logger ist, das Paket installiert, den
Dienst aktiviert, journald, das die Nachrichten übergibt, restriktive Modi für neue Logdateien,
keinen Empfang entfernter Nachrichten, außer der Host sammelt Logs, und eingerichtete Rotation;
und die Dateien unter `/var/log` nur für die lesbar, die sie brauchen. Die Weiterleitung an einen
zentralen Host gehört dazu, das Ziel bleibt dir überlassen.

Der Grund ist einfach: Ein Log, das ein Angreifer lesen kann, verrät ihm, was du sehen kannst, ein
Log, das er schreiben kann, ist kein Beweis, und ein Log, das die Platte füllt, legt den Host
lahm. Die Abwägungen sind Größe gegen Historie, lokal gegen zentral und ein Daemon gegen zwei. Die
Benchmarks verschiedener Distributionen unterscheiden sich darin, welchen Logger sie standardmäßig
erwarten, und in den Nummern der Empfehlungen; schlag sie im PDF deiner Distribution nach.

## Plattformunterschiede

| os_family | Hosts | Logger im Image | journald-Hauptdatei | Journal auf einem frischen Target | Hersteller-Drop-in für journald | rsyslog-Paket |
|---|---|---|---|---|---|---|
| Debian | debian, ubuntu | nur journald | `/etc/systemd/journald.conf` | persistent | `syslog.conf`: `ForwardToSyslog=yes` | 8.2504 / 8.2512, bringt `logrotate` mit; `$FileCreateMode 0640`, Gruppe `adm` |
| RedHat | rocky, alma / fedora | nur journald | `/usr/lib/systemd/journald.conf` | flüchtig / persistent | keins | 8.2604, `imjournal`, Unit `UMask=0066`, Dateien 0600 |
| Suse | opensuse | nur journald (kein `logger`) | `/usr/lib/systemd/journald.conf` | persistent | `20-defaults-SUSE.conf`: `Audit=no` | 8.2608, zieht `syslog-service` nach; `$FileCreateMode 0640` |
| Alpine | alpine | BusyBox-`syslogd`, in keinem Runlevel | - | - | - | 8.2608 im Paketindex |
| Archlinux | arch | nur journald | `/etc/systemd/journald.conf` | persistent | keins | nicht in den Repositories (`syslog-ng` 4.12 schon) |

Nach der Installation war rsyslog auf debian, ubuntu, rocky, alma, fedora und opensuse aktiviert,
aber nicht gestartet. Die Journal-Dateien waren auf jedem Host mit persistentem Journal 0640
`root:systemd-journal`; auf rocky und alma waren die Dateien, die der Flush anlegte, `root:root`.
`systemd-journald.service(8)` empfiehlt `systemd-tmpfiles --create --prefix /var/log/journal`, um
einem neuen Journal-Verzeichnis den richtigen Besitzer und Modus zu geben.

### In den Lab-Containern

Nichts in dieser Lektion berührt den Kernel des Hosts: journald, rsyslog und syslogd laufen in den
Containern wie auf einer virtuellen Maschine, und jedes Target hat seine eigene Machine-ID und sein
eigenes Journal. Zwei Unterschiede: Die Standard-Größengrenzen werden aus dem Dateisystem des
Containers berechnet, also der großen virtuellen Platte von Docker (daher "max 4G"), und `./lab.sh
reset` wirft jedes Log mit dem Container weg. Auf rocky und alma liefert das Image
`/etc/rsyslog.d/00-lab-container.conf` mit: Auf manchen Host-Kerneln kann das rsyslog von el10 im
Container seine Capabilities nicht abgeben und würde nicht einmal `rsyslogd -N1` ausführen
([Container-Grenzen](../CONTAINER_LIMITS.de.md)). Die Protokollierung des Docker-Hosts selbst ist
nicht betroffen.

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| Dein Drop-in sagt `no`, der Daemon verhält sich wie bei `yes` | ein Hersteller-Drop-in sortiert nach deinem | `systemd-analyze cat-config` lesen; die Herstellerdatei ersetzen oder maskieren |
| `Storage=persistent` und trotzdem "Runtime Journal" | journald zieht erst auf eine Flush-Anforderung nach `/var` um | `journalctl --flush` nach dem Neustart |
| `validate:` lehnt ein korrektes rsyslog-Drop-in ab | `-N1 -f` behandelt die Datei als ganze Konfiguration | die ganze Konfiguration nach dem Schreiben und vor dem Neustart prüfen |
| rsyslog ist `active`, die neue Zeile wirkt nicht | rsyslog startet mit Fehlern und protokolliert sie nur | `rsyslogd -N1`, und die eigenen Meldungen von rsyslog lesen |
| Eine Modus-Zeile ist gesetzt, die Dateien haben einen anderen Modus | die umask der Unit oder eine Legacy-Zeile vor `action()`-Regeln | die Dateien selbst prüfen |
| Eine Nachricht fehlt in der erwarteten Datei | die Regel nutzt eine andere Facility (`auth` statt `authpriv`) | die Selektoren der Regeln lesen |
| `logger: command not found` | nicht jedes Image hat es (opensuse) | `systemd-cat` auf systemd-Hosts |
| syslogd läuft auf Alpine, aber nicht nach einem Neustart | er wurde als Abhängigkeit gestartet, nicht aus einem Runlevel | ihn aktivieren (`rc-update add` oder `service` mit `enabled: true`) |
| `Destination directory /etc/systemd/journald.conf.d does not exist` | nur opensuse liefert das Verzeichnis in `/etc` mit | es zuerst mit `ansible.builtin.file` anlegen |
| `journalctl` zeigt nichts oder nur deine eigenen Nachrichten | das System-Journal braucht root oder eine Log-Gruppe | `-b` oder Mitgliedschaft in `systemd-journal` |

## Übungen

| Übung | Worauf diese Lektion vorbereitet |
|---|---|
| [4.09](../../exercises/stage4-advanced/4.09-system-logging/README.de.md) | die drei Logger und ihre Wege, Reihenfolge und Maskieren von Drop-ins, Flush, `rsyslogd -N1`, `listen`, OpenRC-Runlevel |

Starte eine Übung mit `lab start <id>`; `lab show <id>` gibt ihre README aus.

## Selbstkontrolle

1. Ein Drop-in `/etc/systemd/journald.conf.d/50-local.conf` setzt `ForwardToSyslog=no`, und doch
   ist der wirksame Wert auf debian `yes`. Warum, und welche zwei Wege gibt es, das zu beheben?

   <details><summary>Antwort</summary>

   Drop-ins werden über `/etc` und `/usr/lib` hinweg nach Dateinamen sortiert, und die
   Herstellerdatei `syslog.conf` sortiert nach `50-local.conf`, also wird ihr `yes` zuletzt
   gelesen und gewinnt. Entweder gibst du deiner Einstellung eine Datei, die später sortiert, oder
   du ersetzt die Herstellerdatei durch eine Datei gleichen Namens in `/etc` oder maskierst sie mit
   einem `/dev/null`-Symlink dieses Namens. `systemd-analyze cat-config` zeigt das Ergebnis.

   </details>

2. Auf rocky setzt du `Storage=persistent` und startest journald neu, aber `/var/log/journal`
   fehlt weiter. Worauf wartet journald, und warum funktioniert derselbe Neustart auf fedora?

   <details><summary>Antwort</summary>

   Auf eine Flush-Anforderung (`journalctl --flush`, die beim Booten über
   `systemd-journal-flush.service` kommt): Bis dahin behält es das Laufzeit-Journal in `/run`.
   fedora hat `/var/log/journal` schon, also hat der Flush beim Booten sein Journal dorthin
   verschoben, und ein Neustart schreibt sofort nach `/var`; die Flag-Datei
   `/run/systemd/journal/flushed` hält den Flush fest.

   </details>

3. Warum kann `validate:` ein rsyslog-Drop-in nicht prüfen, und was gibst du auf, wenn du
   stattdessen die ganze Konfiguration in einem Task nach dem Schreiben der Datei prüfst?

   <details><summary>Antwort</summary>

   `rsyslogd -N1 -f <datei>` prüft die Datei als vollständige Konfiguration, und ein Drop-in
   allein hat keine Actions, also scheitert sogar ein korrektes. Ein späterer Task prüft die
   echte, zusammengefügte Konfiguration und stoppt den Host, bevor der Neustart-Handler läuft,
   aber die kaputte Datei liegt schon auf der Platte und bleibt dort, bis sie repariert ist.

   </details>

4. Auf der RedHat-Familie hat journald `ForwardToSyslog=no`, und doch schreibt rsyslog jede
   Nachricht nach `/var/log/messages`. Wie bekommt es sie?

   <details><summary>Antwort</summary>

   Sein Eingang `imjournal` liest die Journal-Dateien direkt, wie `journalctl`; der
   Weiterleitungs-Socket ist nicht beteiligt (der lokale Socket-Eingang ist abgeschaltet). Auf
   debian, wo rsyslog `imuxsock` lädt, bräuchte es die weitergeleitete Kopie.

   </details>

5. Zwei Handler hören auf dasselbe Thema. Der Task, der das Thema benachrichtigt, kommt nach einem
   Task, der den zweiten Handler beim Namen benachrichtigt. In welcher Reihenfolge laufen sie?

   <details><summary>Antwort</summary>

   In der Reihenfolge des Abschnitts `handlers:`, jeder einmal, am Ende des Plays (oder bei
   `meta: flush_handlers`). Die Reihenfolge der Benachrichtigungen spielt keine Rolle.

   </details>

6. `ps` zeigt `syslogd` auf einem frischen alpine, aber `rc-update show` listet `syslog` nicht. Ist
   er aktiviert?

   <details><summary>Antwort</summary>

   Nein. OpenRC hat ihn gestartet, weil `crond` `logger` braucht und `sshd` es nutzt, und
   `syslog` stellt `logger` bereit. Er steht in keinem Runlevel, startet also nur, solange etwas
   von ihm abhängt; `rc-update add syslog default` (oder `service` mit `enabled: true`) aktiviert
   ihn.

   </details>

## Weiterführendes

- [journald.conf(5)](https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html) - `Storage=`, `Compress=`, `SystemMaxUse=`, `ForwardToSyslog=`, die Reihenfolge der Drop-ins
- [systemd-journald.service(8)](https://www.freedesktop.org/software/systemd/man/latest/systemd-journald.service.html) - Sockets, der Flush nach `/var`, das Journal-Verzeichnis
- [systemd-analyze(1)](https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html) - `cat-config`
- [rsyslog: omfile](https://docs.rsyslog.com/doc/configuration/modules/omfile.html) - `fileCreateMode`, Legacy-Direktiven und RainerScript
- [rsyslog: $FileCreateMode](https://docs.rsyslog.com/doc/configuration/action/rsconf1_filecreatemode.html) - die Legacy-Direktive und ihre Position
- [BusyBox-Befehle](https://busybox.net/downloads/BusyBox.html) - `syslogd`, `logread`
- [Handlers: running operations on change](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html) - `notify`, `listen`, Reihenfolge, `force_handlers`
- [`ansible.builtin.find`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/find_module.html) - `contains:`
- [`ansible.builtin.service`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/service_module.html) - `enabled` auf systemd und OpenRC
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: `ForwardToSyslog`, journald, `listen`,
  mask (drop-in), rsyslog, syslogd (BusyBox)
