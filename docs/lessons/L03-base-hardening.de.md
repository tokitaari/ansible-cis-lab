# L03 - Basis-Härtung: Pakete, Dienste, Dateirechte, SSH und sudo

*[English](L03-base-hardening.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 1.01, 1.02, 1.03, 1.04, 1.05, 2.01 | 2.1, 2.2, 5.1, 5.2, 7.1 | ~25 Min. | L00, L02 |

L02 hat gezeigt, wie du einen Host sicher änderst; diese Lektion behandelt, *was* du in den ersten
Härtungsschritten änderst und was "fertig" jeweils bedeutet: Software, die nicht da sein soll,
Dienste, die nicht laufen sollen, Dateien, die nicht lesbar sein sollen, und die zwei Programme -
sshd und sudo -, über die du den Host selbst verwaltest.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] installiert, laufend, aktiviert und maskiert unterscheiden und das Modul wählen, das jeweils ändert
- [ ] prüfen, dass eine Entfernung die gewünschte Wirkung hatte, statt der Paketdatenbank zu vertrauen
- [ ] Dateimodi ohne die Quoting-Falle schreiben und erklären, warum Compliance eine Schranke und kein Wert ist
- [ ] vorhersagen, welchen Wert sshd nimmt, wenn mehrere Dateien dasselbe Schlüsselwort setzen, und das effektive Ergebnis lesen
- [ ] vorhersagen, welche sudoers-Drop-ins in welcher Reihenfolge gelesen und welche ignoriert werden
- [ ] die zwei Programme nennen, bei denen ein Fehler dich den Verwaltungskanal kostet, und warum

## Theorie

### Angriffsfläche in Schichten: installiert, laufend, aktiviert

"Wirf den FTP-Server raus" kann vier verschiedene Dinge bedeuten, und eine Vorgabe, die eines
verlangt, ist durch ein anderes nicht erfüllt. Ein Programm hat mehrere Schichten, und jede ändert
sich über einen eigenen Mechanismus:

| Schicht | Frage | Ansible |
|---|---|---|
| installiert | liegen die Dateien auf der Platte? | `package` mit `state: absent` |
| laufend | gibt es gerade einen Prozess? | `service` mit `state: stopped` |
| aktiviert | wird es beim Booten gestartet? | `service` mit `enabled: false` |
| maskiert (nur systemd) | kann es überhaupt jemand starten? | `systemd_service` mit `masked: true` |

Gestoppt und deaktiviert lässt das Programm weiterhin startbar: Ein Administrator, ein Skript oder
eine andere Unit, die davon abhängt, kann es zurückholen. Eine maskierte Unit lässt sich gar nicht
starten, und ein entferntes Paket hat nichts mehr, das man starten, falsch konfigurieren oder mit
einer Schwachstelle versehen könnte. Entfernen ist deshalb die stärkste Antwort; Stoppen und
Deaktivieren ist der Rückfall, wenn etwas auf dem Host das Paket braucht.

`package` schaut auf den Fakt `pkg_mgr` und ruft das passende Modul auf, also läuft ein Task auf
allen acht Hosts. `state: absent` beschreibt den Endzustand: Ein Paket, das nicht installiert ist,
erfüllt ihn bereits, der Task meldet `ok`, und nichts braucht eine Bedingung zum Schutz. Optionen,
die nur ein Paketmanager kennt (`purge` für apt, `autoremove` für apt und dnf), brauchen das
Modul dieses Managers. `service` verbirgt den Unterschied zwischen systemd und OpenRC, aber nicht
vor `service_facts`:

```yaml
- name: Report how the init system describes a service
  hosts: targets
  become: true
  tasks:
    - name: Collect service data
      ansible.builtin.service_facts:
    - name: Show the entry of the SSH daemon
      ansible.builtin.debug:
        msg: "{{ ansible_facts.services[item] }}"
      loop: [ssh.service, sshd.service, sshd]
      when: item in ansible_facts.services
```

Auf systemd-Hosts hat der Eintrag `state` (running oder stopped) und `status` (enabled, disabled,
static, masked ...); auf OpenRC hat er `state` und eine Liste `runlevels`, aber gar kein `status` -
"aktiviert" heißt dort, dass `default` in dieser Liste steht. Code, der `status` liest, funktioniert
auf sieben Hosts und sieht auf dem achten stillschweigend nichts.

Auch die Paketdatenbank hat nicht das letzte Wort. Prüfe die *Wirkung*:

```yaml
- name: Remove a package and check the effect
  hosts: targets
  become: true
  tasks:
    - name: Package is absent
      ansible.builtin.package:
        name: lab-no-such-package
        state: absent
    - name: Look for the program itself
      ansible.builtin.stat:
        path: /usr/bin/lab-no-such-program
      register: program
    - name: Removal left nothing behind
      ansible.builtin.assert:
        that: not program.stat.exists
        fail_msg: "the program is still installed"
```

Beide Tasks sind auf jedem Host `ok`, der zweite Lauf ist also ebenfalls ein No-op - und das ist der
Punkt: Die Assertion prüft das, worum es der Vorgabe geht, nicht das, was das Modul meldet.

### Ein Werkzeug, viele Pakete: Entfernen über den Namen

Dasselbe Programm steckt in verschieden benannten Paketen: Das DNS-Abfragewerkzeug `dig` liegt in
`bind9-dnsutils` auf Debian, `bind-utils` auf RedHat und Suse, `bind-tools` auf Alpine und `bind`
auf Arch (siehe die Tabelle unten). Eine Entfernungsliste, die für eine Distribution geschrieben
ist, scheitert auf einer anderen oder tut nichts. Zwei weitere Fallen machen den Namen unzuverlässig:

- ein **Übergangs- oder Meta-Paket** existiert nur, um von einem anderen abzuhängen; entfernst du
  es, bleibt das Programm installiert
- ein **Sammelpaket** liefert mehrere Werkzeuge, und sein Entfernen entfernt alle; lies zuerst, was
  ein Name liefert (`dpkg -L`, `rpm -ql`, `pacman -Ql`, `apk info -L` listen die Dateien eines
  installierten Pakets)

Schreibe die Entfernung für den Namen, den der *Host* verwendet, und schau danach, was auf der
Platte übrig ist.

### Modi: Bits, Schreibweise und warum Compliance eine Schranke ist

Ein Dateimodus hat drei Gruppen (Besitzer, Gruppe, Andere) mit je drei Bits: lesen, schreiben,
ausführen. `0640` heißt Besitzer lesen und schreiben, Gruppe lesen, Andere nichts; die führende `0`
gehört zur Oktalschreibweise, die optionale erste Ziffer trägt setuid, setgid und sticky. Die Module
`file`, `copy` und `template` akzeptieren oktale oder symbolische Modi, und `stat` meldet den
aktuellen Wert als vierstelligen String:

```yaml
- name: Modes as the file module sees them
  hosts: targets
  become: true
  tasks:
    - name: Scratch directory
      ansible.builtin.file:
        path: /tmp/lab-modes
        state: directory
        mode: "0755"
    - name: One file per notation
      ansible.builtin.copy:
        dest: "/tmp/lab-modes/{{ item.name }}"
        content: "demo\n"
        owner: root
        group: root
        mode: "{{ item.mode }}"
      loop:
        - {name: octal, mode: "0640"}
        - {name: symbolic, mode: "u=rw,g=r,o="}
        - {name: strict, mode: "0000"}
    - name: Read the result back
      ansible.builtin.stat:
        path: "/tmp/lab-modes/{{ item }}"
      loop: [octal, symbolic, strict]
      register: modes
    - name: Compare
      ansible.builtin.debug:
        msg: "{{ item.item }}: {{ item.stat.mode }} {{ item.stat.pw_name }}:{{ item.stat.gr_name }}"
      loop: "{{ modes.results }}"
      loop_control:
        label: "{{ item.item }}"
```

`octal` und `symbolic` enden mit denselben Bits (`0640`). **Setze den Modus in Anführungszeichen.**
YAML liest ein unquotiertes `0640` als Oktalzahl und ein unquotiertes `640` als *Dezimal*zahl 640,
das ist oktal `1200`: nur der Besitzer darf schreiben, dazu das Sticky-Bit. `ansible-lint` hat dafür
eine Regel, weil das Ergebnis plausibel aussieht und falsch ist. Symbolische Modi dokumentieren sich
selbst und können einzelne Bits entfernen (`go-w`), aber dann hängt das Ergebnis vom Ausgangszustand ab.

Zwei Details zählen bei Systemdateien. Erstens werden Besitzer und Gruppe per **Name** angegeben und
*auf dem Target* aufgelöst: Eine Gruppe, die dort nicht existiert, lässt den Task scheitern, und
dieselbe Datei kann auf einer anderen Distribution eine andere richtige Gruppe haben. Zweitens
übergeht root die Lese- und Schreibbits gewöhnlicher Dateien (er hält die Capability
`CAP_DAC_OVERRIDE`), also kostet selbst `0000` root nichts und sperrt alle anderen aus. Die
Distributionen nutzen den Spielraum unterschiedlich: Manche geben die Passwort-Hash-Dateien einer
eigenen Gruppe, damit kleine setgid-Helfer ein Passwort prüfen können, ohne root zu sein, andere
schließen sie für alle außer root. Beides ist sicher, deshalb sind die Empfehlungen als Schranke
formuliert ("so streng oder strenger") und deshalb darf eine Prüfung nicht gegen einen einzigen
Zauberwert vergleichen.

Schließlich erwartet `file` mit nur `mode`, `owner` oder `group`, dass der Pfad existiert, und
scheitert an einer fehlenden Datei. Systemdateien wie Sicherungskopien gibt es nicht überall, der
Task muss also vorher Bescheid wissen - `stat` und eine Bedingung, oder eine Schleife über das, was
existiert (L04 baut das auf).

### sshd: mehrere Dateien, ein effektiver Wert

Eine sshd-Einstellung ist nur so viel wert, wie der *laufende* Daemon sieht. Die Konfiguration
besteht aus der Hauptdatei plus den Dateien, die per `Include` hereinkommen (typisch
`sshd_config.d/*.conf`), gelesen in lexikalischer Reihenfolge, und bei fast jedem Schlüsselwort
gewinnt der **erste** Wert, den sshd liest. Spätere Werte für dasselbe Schlüsselwort werden
ignoriert. Auch die Position der `Include`-Zeile zählt: Oben in der Hauptdatei entscheiden die
Drop-ins, unten gewinnen die eigenen Zeilen der Hauptdatei.

```yaml
- name: First value wins in sshd
  hosts: targets
  become: true
  tasks:
    - name: Scratch directory for the drop-ins
      ansible.builtin.file:
        path: /tmp/lab-sshd/conf.d
        state: directory
        mode: "0755"
    - name: Main file that includes the drop-ins first
      ansible.builtin.copy:
        dest: /tmp/lab-sshd/sshd_config
        content: |
          Include /tmp/lab-sshd/conf.d/*.conf
          MaxAuthTries 6
        mode: "0644"
    - name: Two drop-ins that disagree
      ansible.builtin.copy:
        dest: "/tmp/lab-sshd/conf.d/{{ item.name }}"
        content: "MaxAuthTries {{ item.tries }}\n"
        mode: "0644"
      loop:
        - {name: 10-legacy.conf, tries: 10}
        - {name: 20-team.conf, tries: 3}
    - name: Ask sshd for the effective configuration
      ansible.builtin.command: /usr/sbin/sshd -T -f /tmp/lab-sshd/sshd_config
      register: effective
      changed_when: false
    - name: Report the winner
      ansible.builtin.debug:
        msg: "{{ effective.stdout_lines | select('match', '(?i)^maxauthtries ') | list }}"
```

Der Bericht zeigt `10`: `10-legacy.conf` wird vor `20-team.conf` gelesen, und beide kommen vor der
`6` der Hauptdatei. Eine Datei namens `00-` würde alle schlagen, eine namens `99-` würde verlieren.
Das Beispiel arbeitet auf einer Scratch-Kopie, damit es den echten Daemon nicht berühren kann; mit
den echten Dateien lautet derselbe Befehl `sshd -T` ohne `-f`, als root ausgeführt.

`sshd -T` gibt die effektive Konfiguration aus, Schlüsselwort und Wert pro Zeile. Schlüsselwörter
unterscheiden nicht zwischen Groß- und Kleinschreibung, und die Schreibweise der Ausgabe hängt von
der Version ab (manche Releases geben `permitrootlogin` aus, andere `PermitRootLogin`), also
vergleiche das Schlüsselwort kleingeschrieben; die Werte behalten ihre Schreibweise. Abschnitte, die
mit `Match` beginnen, gelten nur für Verbindungen, auf die eine Bedingung passt, und alles nach einer
`Match`-Zeile gehört dazu, bis zum nächsten `Match` oder zum Ende dieser Datei. Werte einen für eine
bestimmte Verbindung mit `-C` aus:

```bash
sshd -T -f /tmp/lab-sshd/sshd_config -C user=backup,host=example,addr=192.0.2.10
```

Eine Zeile, die am Ende einer Hauptdatei mit `Match`-Block angehängt wird, wird Teil dieses
Blocks: still, wenn das Schlüsselwort dort erlaubt ist, als Startfehler, wenn nicht. Ein
`Match`-Block in einem Drop-in endet mit dieser Datei und kann die nächste also nicht verschlucken.
Das ist ein Grund mehr, eigene Einstellungen in einer Datei zu halten, die dir gehört.

Eine geänderte Konfiguration erreicht den Daemon per **Reload** (sshd liest seine Dateien neu und
startet sich selbst neu) oder per **Restart**. Bestehende Sitzungen überleben einen Reload -
einschließlich der, die Ansible gerade nutzt - und nur *neue* Logins folgen den neuen Regeln. Eine
Konfiguration, die gültig, aber falsch ist, schadet also nicht in dem Lauf, der sie anwendet,
sondern beim nächsten Login, wenn du nicht mehr hineinkommst. Halte eine zweite Sitzung offen und
teste einen neuen Login, bevor du die erste schließt.

### sudo: Drop-ins, Reihenfolge und der Verwaltungskanal

`sudo` liest `/etc/sudoers`, das mit einer Include-Anweisung für ein Verzeichnis endet
(`@includedir /etc/sudoers.d`; älteres sudo schreibt `#includedir`, und das `#` ist dort *kein*
Kommentar). Die Regeln für dieses Verzeichnis:

- Dateien werden in lexikalischer Reihenfolge gelesen, und bei `Defaults` **gewinnen spätere
  Einträge** - das Gegenteil von sshd
- eine Datei, deren Name einen `.` enthält oder auf `~` endet, wird ohne Meldung übersprungen
  (Pakete hinterlassen dort Sicherungen und Vorlagen); `30-site.conf` tut nichts, `30-site` funktioniert
- eine Datei ist eine Liste von `Defaults`-Optionen und Regeln; beide Arten können in jeder Datei stehen

```
# /etc/sudoers.d/10-site            wird zuerst gelesen
Defaults passwd_tries=5
# /etc/sudoers.d/20-site            wird später gelesen: dieser Wert gilt
Defaults passwd_tries=2
# /etc/sudoers.d/30-site.conf       wird nie gelesen: der Name enthält einen Punkt
Defaults passwd_tries=7
```

`Defaults`-Einstellungen stimmen die Richtlinie ab. Ein Pseudo-Terminal für den Befehl (`use_pty`)
hindert einen Prozess, der den Befehl überlebt, daran, ins Terminal des Benutzers zu schreiben; eine
eigene Logdatei (`logfile`) gibt Auditoren einen Ort, an dem sie die Nutzung von Privilegien lesen,
zusätzlich zum Systemlog; wie lange ein Benutzer angemeldet bleibt (`timestamp_timeout`), ist
ebenfalls eine `Defaults`-Option.

Was sudo und sshd von jedem anderen Härtungsziel unterscheidet: **Ansible selbst hängt von beiden
ab**. Es verbindet sich über sshd und wird über sudo zu root. Ein Syntaxfehler in einer sudoers-Datei
lässt sudo *alle* Befehle verweigern, sodass der nächste Task nicht mehr root werden kann - auf jedem
Host, den das Play erreicht hat. Das Programm bringt ein Prüfwerkzeug mit, das eine Datei liest, ohne
sie zu installieren; den Aufruf zu finden ist Teil der Übung, und L02 hat gezeigt, wo er sich
einklinkt (`validate`). Im Lab hat der Account, den Ansible nutzt, eine eigene sudo-Regel; lass sie
dort, wo sie ist.

## CIS-Hintergrund

Die Empfehlungen hinter diesen Übungen teilen einen Gedanken: Entferne, was der Host nicht braucht,
und schließe, was er behalten muss. Die Abschnitte 2.1 (Server-Dienste) und 2.2 (Client-Dienste) im
[Kontrollkatalog](../../cis/controls.yml) verringern, was ein Angreifer erreichen oder missbrauchen
kann; Klartext-Clients wie telnet sind der Lehrbuchfall, und "entfernen, oder zumindest stoppen und
deaktivieren" spiegelt die Schichten oben. Abschnitt 5.1 (SSH-Server) begrenzt, wie sich ein
Angreifer anmelden kann: kein direkter root-Login, damit die Audit-Spur eine Person nennt, und keine
leeren Passwörter. Abschnitt 5.2 (Rechteausweitung) macht die sudo-Nutzung nachvollziehbar und hält
außer Kontrolle geratene Prozesse aus dem Terminal des Benutzers. Abschnitt 7.1 (Rechte auf
Systemdateien) schützt die Dateien mit Konten und Passwort-Hashes: Eine lesbare Hash-Datei lässt
jeden lokalen Benutzer die Hashes offline knacken.

Alle sind Level 1: billig und mit wenig Risiko für die Dienste auf dem Host. Das Risiko steckt in
den zwei, die den Verwaltungskanal berühren (5.1, 5.2) - daher die Sorgfalt in L02. Der Preis von
"entfernen statt deaktivieren" ist, dass ein später benötigtes Paket neu installiert werden muss; die
Antwort ist eine dokumentierte Ausnahme (L11), kein Dienst, der standardmäßig läuft.

## Plattformunterschiede

| os_family | Hosts | `pkg_mgr` | Paket mit `dig` | "Aktiviert" in `service_facts` | Vendor-Defaults |
|---|---|---|---|---|---|
| Debian | debian, ubuntu | `apt` | `bind9-dnsutils` | `status: enabled` | `/etc` |
| RedHat | rocky, alma, fedora | `dnf` (`dnf5` auf fedora) | `bind-utils` | `status: enabled` | `/etc`, Distributions-Drop-ins in `sshd_config.d` |
| Suse | opensuse | `zypper` | `bind-utils` | `status: enabled` | `/usr/etc`, lokale Änderungen in `/etc` |
| Alpine | alpine | `apk` | `bind-tools` | `default` in `runlevels`, kein `status` | `/etc` |
| Archlinux | arch | `pacman` | `bind` | `status: enabled` | `/etc` |

Auf openSUSE liegen die Vendor-Defaults mehrerer Programme unter `/usr/etc`, und eine Datei in
`/etc` überschreibt sie. Ein Werkzeug, das "die" Konfiguration des Systems prüft, kann sich über eine
Datei beschweren, die dir nicht gehört. Auf Ubuntu 26.04 ist der Befehl `sudo` standardmäßig eine
Rust-Neuimplementierung (sudo-rs), das ursprüngliche sudo ist daneben verfügbar; sie liest dieselben
sudoers-Dateien, setzt aber nicht jede Option um, und `sudo -V` listet keine Richtlinienwerte auf.
Schau auf `sudo --version`, bevor du dich auf ein sudo-Feature verlässt. Das Ubuntu-Image des Labs
ist anders: Dort ist `sudo` das ursprüngliche sudo 1.9.17p2 (ein Alternatives-Link auf `sudo.ws`),
die Übungen verhalten sich also wie auf den anderen Hosts.

### In den Lab-Containern

- Die Dienste laufen unter einem echten Init-System, also verhalten sich `service` und
  `systemd_service` wie auf einer VM. Die Targets bringen `telnet` und `vsftpd` mit, wo ihre
  Distribution sie hat, sodass manche Hosts mit der Software starten und manche ohne.
- Das Boot-Skript des Labs setzt die `Include`-Zeile auf jedem Host an den **Anfang** der
  sshd-Hauptdatei, also entscheidet ein Drop-in, wie oben beschrieben. Prüfe auf einem echten Host
  zuerst `grep -n '^Include' /etc/ssh/sshd_config`. Außerdem legt es ein altes Drop-in mit
  schwachen Einstellungen an, das du überstimmen musst.
- Der Lab-Account `ansible` hat eine eigene sudo-Regel in `/etc/sudoers.d`. Wenn du sudo kaputt
  machst, stellt `./lab.sh reset <host>` (`.\lab.ps1 reset <host>` unter Windows) den Host wieder her.
- Dateirechte sind voll realistisch: Sie liegen im eigenen Dateisystem des Containers.

## Stolperfallen

| Symptom | Ursache | Abhilfe |
|---|---|---|
| Der Paket-Task ist `ok`, das Programm liegt noch auf der Platte | Meta- oder Übergangspaket, oder ein anderes Paket liefert das Programm | die Wirkung prüfen (`stat`, `command -v`), das entfernen, was die Datei tatsächlich liefert |
| Eine Entfernung nimmt fremde Werkzeuge mit | das Paket bündelt mehrere Programme | vor dem Entfernen auflisten, was das Paket liefert |
| Ein gestoppter, deaktivierter Dienst läuft wieder | eine Socket-Unit oder eine abhängige Unit startet ihn bei Bedarf | auch den Socket deaktivieren, oder die Unit maskieren, oder das Paket entfernen |
| Eine Datei hat nach `mode: 644` seltsame Bits wie `-w----r-T` | YAML hat `644` als Dezimalzahl gelesen | den Modus quoten: `"0644"` |
| `failed to look up group shadow` | die Gruppe existiert auf dieser Distribution nicht | die Gruppe je OS-Familie wählen (L04) oder eine vorhandene Gruppe nehmen |
| `file (...) is absent, cannot continue` | der Pfad existiert auf diesem Host nicht | erst `stat`, dann nur dort handeln, wo er existiert |
| Ein neues sshd-Drop-in hat keine Wirkung | eine andere Datei wird früher gelesen, ein `Match`-Block verschluckt es, oder `Include` steht unten | `sshd -T` lesen, dann das Drop-in umbenennen oder das `Include` verschieben |
| Der Vergleich mit der `sshd -T`-Ausgabe scheitert auf einem Host | das Schlüsselwort heißt dort `PermitRootLogin` statt `permitrootlogin` | das Schlüsselwort vor dem Vergleich kleinschreiben |
| Ein sudoers-Drop-in wird ignoriert, obwohl die Syntax stimmt | der Dateiname enthält einen `.` oder endet auf `~` | ohne Punkt umbenennen |
| Das Play lief durch, und der nächste Login scheitert | ein Reload wendet die Konfiguration nur auf neue Verbindungen an | eine zweite Sitzung offen halten und neu einloggen, bevor du sie schließt |

## Übungen

| Übung | Was diese Lektion dafür vorbereitet |
|---|---|
| [1.01](../../exercises/stage1-beginner/1.01-remove-telnet/README.de.md) | Schichten, `state: absent` als Endzustand, Paketnamen, die Wirkung prüfen |
| [1.02](../../exercises/stage1-beginner/1.02-passwd-group-permissions/README.de.md) | Modus-Schreibweise und die Quoting-Falle, Besitzer und Gruppe per Name, Dateien, die es vielleicht nicht gibt |
| [1.03](../../exercises/stage1-beginner/1.03-ssh-root-login/README.de.md) | die sshd-Dateireihenfolge, erster Wert gewinnt, `sshd -T`, Reload gegenüber Restart |
| [1.04](../../exercises/stage1-beginner/1.04-disable-ftp-server/README.de.md) | gestoppt gegenüber deaktiviert gegenüber maskiert, `service_facts` je Init-System |
| [1.05](../../exercises/stage1-beginner/1.05-sudo-hardening/README.de.md) | sudoers-Drop-ins, Reihenfolge und ignorierte Namen, warum sudo nicht kaputtgehen darf |
| [2.01](../../exercises/stage2-building-blocks/2.01-shadow-permissions-per-family/README.de.md) | warum der richtige Modus je Distribution abweicht, Modi als Schranke, optionale Dateien |

Eine Übung startest du mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. `package` mit `state: absent` meldet auf einem Host `ok`, und das Programm startet trotzdem.
   Nenne zwei Gründe und die Prüfung, die es gefunden hätte.

   <details><summary>Antwort</summary>

   Der entfernte Name war ein Meta- oder Übergangspaket, das nur vom eigentlichen abhängt, oder
   ein anderes Paket liefert das Programm ebenfalls. `ok` sagt, dass das im Task genannte Paket
   fehlt, nicht, dass die Vorgabe erfüllt ist. Prüfe die Wirkung: Existiert die Datei, löst sich
   der Befehl auf? Dasselbe gilt für Dienste: Ein Programm kann gestoppt und trotzdem startbar sein.

   </details>

2. Was trennt gestoppt, deaktiviert und maskiert, und welches lässt eine andere Unit den Dienst
   noch starten?

   <details><summary>Antwort</summary>

   Gestoppt betrifft nur den laufenden Prozess, deaktiviert nur den Start beim Booten; keines von
   beiden hindert einen Administrator oder eine abhängige Unit, ihn wieder zu starten. Maskiert
   (systemd) verlinkt die Unit auf `/dev/null`, sodass ihn nichts starten kann, das Entfernen
   nimmt das Programm selbst weg. Maskieren braucht `systemd_service`; `service` deckt die ersten
   beiden auf systemd und OpenRC gleichermaßen ab.

   </details>

3. Wie prüfst du im Code, dass ein Dienst auf systemd-Hosts und auf alpine aktiviert ist?

   <details><summary>Antwort</summary>

   Auf systemd ist `ansible_facts.services[name].status` gleich `enabled`. OpenRC-Einträge haben
   kein `status`; sie tragen `runlevels`, und der Dienst gilt als aktiviert, wenn `default` in
   dieser Liste steht. Eine Bedingung, die nur `status` liest, sieht auf alpine nie einen
   aktivierten Dienst.

   </details>

4. Was setzt `mode: 644` (ohne Anführungszeichen), und warum ist `0000` für eine Systemdatei
   trotzdem ein sinnvoller Modus?

   <details><summary>Antwort</summary>

   YAML liest es als Dezimalzahl 644, das ist oktal `1204`: ein ungewöhnlicher Modus mit
   Sticky-Bit, nicht `rw-r--r--`. Setze Modi in Anführungszeichen, `ansible-lint` markiert die
   unquotierten Formen. `0000` ist sinnvoll, weil root die Lese- und Schreibbits gewöhnlicher
   Dateien übergeht, es kostet ihn also nichts und sperrt alle anderen aus.

   </details>

5. Zwei sshd-Drop-ins `10-a.conf` und `20-b.conf` setzen dasselbe Schlüsselwort auf verschiedene
   Werte. Welcher Wert gilt, welcher Befehl belegt es, und was würde es ändern?

   <details><summary>Antwort</summary>

   Der aus `10-a.conf`, weil sshd bei den meisten Schlüsselwörtern den ersten gelesenen Wert nimmt
   und die Drop-ins in lexikalischer Reihenfolge liest. `sshd -T` (als root) gibt den effektiven
   Wert aus. Eine Datei, die früher sortiert (`00-...`), oder ein verschobenes `Include` würde das
   Ergebnis ändern; ebenso ein `Match`-Block, der auf die Verbindung passt.

   </details>

6. Ein Reload von sshd endet ohne Fehler, und deine Sitzung läuft weiter. Warum kann der Host
   zehn Minuten später trotzdem nicht erreichbar sein?

   <details><summary>Antwort</summary>

   Ein Reload lässt aufgebaute Sitzungen in Ruhe und wendet die neue Konfiguration nur auf *neue*
   Verbindungen an. Eine syntaktisch gültige, aber falsche Konfiguration (verbotene
   Anmeldemethode, falscher Benutzer, falsche Schlüsseleinstellung) zeigt ihre Wirkung beim
   nächsten Login. Halte eine zweite Sitzung offen und mach einen Test-Login, bevor du die erste
   schließt.

   </details>

7. Wie unterscheiden sich die Reihenfolgeregeln der sudoers-Drop-ins von denen bei sshd, und was
   lässt ein Drop-in mit perfekter Syntax nichts bewirken?

   <details><summary>Antwort</summary>

   Beide lesen Dateien in lexikalischer Reihenfolge, aber bei sudo gewinnt der spätere
   `Defaults`-Eintrag und bei sshd der erste Wert. Sudo überspringt Dateinamen, die einen `.`
   enthalten oder auf `~` enden, ohne jede Meldung, also wird `30-site.conf` nie gelesen; nenne
   sie `30-site`.

   </details>

8. Eine Distribution macht `/etc/shadow` zu `root:root` mit Modus `0000`, eine andere nutzt
   `root:shadow` mit `0640`. Welche ist falsch?

   <details><summary>Antwort</summary>

   Keine. Root übergeht die Rechtebits, und die Gruppe der zweiten Variante lässt kleine
   Hilfsprogramme Passwörter prüfen, ohne root zu sein. Eine Empfehlung nennt eine Schranke ("so
   streng oder strenger, Besitzer root"), die richtige Änderung behält also die Konvention jeder
   Distribution bei und zieht nur an, was lockerer ist als sie. Eine Prüfung muss die Schranke
   testen, nicht einen einzelnen Wert.

   </details>

## Weiterführendes

- [Modul `ansible.builtin.package`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/package_module.html) und [Modul `ansible.builtin.service`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/service_module.html)
- [Modul `ansible.builtin.systemd_service`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/systemd_service_module.html) - `masked` und `daemon_reload`
- [Modul `ansible.builtin.service_facts`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/service_facts_module.html) und [Modul `ansible.builtin.stat`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/stat_module.html)
- [Modul `ansible.builtin.file`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/file_module.html) - `mode`, `owner`, `group`
- [`sshd_config(5)`](https://man.openbsd.org/sshd_config) - `Include`, `Match`, die Regel "erster Wert gewinnt"; [`sshd(8)`](https://man.openbsd.org/sshd) - `-T` und `-C`
- [`sudoers(5)`](https://www.sudo.ws/docs/man/sudoers.man/) - Include-Anweisungen, `Defaults`, Regeln für Dateinamen
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: attack surface, drop-in,
  management channel, mode (file), sshd effective value, sudoers
