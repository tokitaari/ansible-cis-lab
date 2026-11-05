# L09 - Auditing und Integrität: auditd, AIDE und langlaufende Tasks

*[English](L09-auditing-and-integrity.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 3.04, 4.08 | 6.1, 6.3 | ~35 Min. | L02, L04, L07 |

Vorbeugung versagt früher oder später, und dann entscheiden zwei Fragen, wie schlimm es wird: Was
ist passiert, und was wurde verändert? Das Audit-Framework des Kernels beantwortet die erste, ein
Dateiintegritätsprüfer wie AIDE die zweite. Beide sind billig zu konfigurieren und teuer im
Betrieb: Sie schreiben viel, sie scannen viel, und sie brauchen einen Prozess drumherum. Diese
Lektion behandelt das Audit-Subsystem und seine Regeldateien, was passiert, wenn das Log die
Platte füllt, wie eine Integritätsdatenbank funktioniert und den Ansible-Mechanismus, der
verhindert, dass ein mehrminütiger Scan ein Play blockiert: Hintergrund-Tasks.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] erklären, warum das Audit-Subsystem zum Kernel des Hosts gehört und was das für ein Play bedeutet, das es anfasst
- [ ] eine Watch-Regel und eine Syscall-Regel lesen und sagen, was ein Key, `auid` und `unset` sind
- [ ] sagen, wie aus den Dateien in `rules.d` der Regelsatz wird, in welcher Reihenfolge, und was `-e 2` für die Automatisierung ändert
- [ ] benennen, was `auditd.conf` tun kann, wenn eine Logdatei voll ist, der Platz knapp wird und die Platte voll ist, und den Zielkonflikt
- [ ] erklären, was eine AIDE-Datenbank enthält, warum eine Prüfung Hashes vergleicht, und den Exit-Code einer Prüfung lesen
- [ ] sagen, warum eine Baseline einen Prozess braucht: Patchen, Durchsicht und wo die Datenbank liegt
- [ ] vorhersagen, was `poll: 0` zurückgibt, wo der Fehler eines Hintergrund-Jobs sichtbar wird und wann `async` überhaupt hilft
- [ ] erklären, warum `poll: 0` zusammen mit `creates` bei jedem Lauf `changed` meldet

## Theorie

### Das Audit-Subsystem: der Kernel zeichnet auf, der Daemon speichert

Ein Log, das ein gewöhnliches Programm schreibt, ist ein schwacher Beleg: Wer das Programm ändern
kann, ändert auch sein Log. Das **Audit-Framework** von Linux verlegt die Aufzeichnung in den
Kernel. Eine Regel sagt dem Kernel, welche Ereignisse er festhalten soll; für jeden Treffer
schickt der Kernel einen Datensatz an den Daemon `auditd`, der ihn an eine Logdatei anhängt
(`/var/log/audit/audit.log` ist auf allen acht Lab-Hosts der Standard von `log_file`). Regeln
werden mit `auditctl` in den Kernel geladen; der Daemon empfängt und speichert nur.

Das Framework hat **keine Namespaces**: Ein Kernel hat einen Regelsatz, und ein Container läuft
auf dem Kernel des Hosts. Ein Play, das in einem Container Regeln lädt oder `auditd` startet,
verändert daher den Host (siehe [die Container-Grenzen](../CONTAINER_LIMITS.de.md)). Deshalb
markiert der Katalog auditd mit `container: config` (L01): Konfiguration schreiben, nichts
aktivieren. Nach der Paketinstallation scheiterte eine Statusabfrage (`auditctl -s`) aus einem
Target heraus hier auf allen acht Hosts: `Operation not permitted` auf vieren (audit 4.0.x),
`There was an error while processing parameters` auf den anderen vier (4.1 und neuer). Nach den
Gründen habe ich nicht gesucht.

Regeln gibt es in drei Arten (`audit.rules(7)`):

```
-D
-w /etc/motd -p wa -k banner_demo
-a always,exit -F arch=b64 -S unlink,unlinkat -F auid>=1000 -F auid!=unset -k delete_demo
```

- Eine **Control-Regel** konfiguriert das Audit-System, statt etwas zu beobachten: `-D` löscht
  alle geladenen Regeln, `-b` setzt den Backlog des Kernels, `-f` den Fehlermodus, `-e` das
  Enabled-Flag. Sie stehen am Anfang eines Regelsatzes (`-e` am Ende, siehe unten).
- Eine **Watch** (`-w Pfad -p Rechte -k Key`) zeichnet Zugriffe auf eine Datei auf: `r` lesen,
  `w` schreiben, `x` ausführen, `a` Attributänderung. Ein Verzeichnis wird rekursiv beobachtet,
  aber an Mount-Punkten hört die Watch auf.
- Eine **Syscall-Regel** (`-a Aktion,Liste -S Syscall -F Feld=Wert -k Key`) wird gegen jeden
  Systemaufruf jedes Programms geprüft. Das Handbuch rät daher zu Syscall-Regeln nur, wenn es
  sein muss, und zu mehreren Syscalls in einer Regel. `always,exit` heißt „aufzeichnen, wenn der
  Aufruf zurückkehrt". Auf Maschinen mit zwei Syscall-ABIs können die Nummern abweichen, deshalb
  schreibt man eine solche Regel einmal je `arch` (`b32`, `b64`).

Ein **Key** ist freier Text, der an jeden Datensatz der Regel gehängt wird. `ausearch -k <Key>`
und `aureport --key --summary` wählen danach aus; ein guter Key beantwortet also eine Frage („wer
hat diese Datei angefasst?"), und das Log wird durchsuchbar. Das Handbuch empfiehlt einen Key an
jeder Regel.

`auid` ist die **Audit-User-ID**, auch *loginuid*: die ID, mit der sich eine Person angemeldet
hat, einmal je Anmeldung vom PAM-Modul `pam_loginuid` in Einstiegsdiensten wie `login`, `sshd`
oder `crond` gesetzt. Laut Handbuch sollen `sudo` und `su` es nicht verwenden, weil es die ID
durch das gerade gewechselte Konto ersetzen würde. Ein ungesetzter Wert heißt `unset`, entspricht
-1 und wird als 4294967295 ausgegeben - deshalb sagt eine Regel, die echte Benutzer auswählt,
`-F auid>=1000 -F auid!=unset`: Der ungesetzte Wert ist eine riesige vorzeichenlose Zahl und
besteht den ersten Test.

```yaml
- name: Who are you, as far as the kernel knows?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Compare the effective user with the login user
      ansible.builtin.command: sh -c 'echo "uid=$(id -u) loginuid=$(cat /proc/self/loginuid)"'
      register: who
      changed_when: false
      check_mode: false
    - name: Show both numbers
      ansible.builtin.debug:
        msg: "{{ who.stdout }}"
```

Das Play liest `/proc/self/loginuid`, wofür kein Paket nötig ist. Auf den sieben systemd-Hosts
gibt es `uid=0` und die ID des Kontos aus, mit dem Ansible sich angemeldet hat (1000, auf ubuntu
1001); auf alpine `loginuid=4294967295`. L08 fand in der `sshd_config` von alpine keine
`UsePAM`-Zeile; ob deshalb die Anmeldung den Wert ungesetzt lässt, habe ich nicht geprüft. Lässt
du es ohne `become` laufen, ändert sich die erste Zahl und die zweite nicht.

### Regeldateien, Lade-Reihenfolge und die Sperre

Regelsätze liegen als Dateien vor. Jede Datei in `/etc/audit/rules.d`, deren Name auf `.rules`
endet, ist ein Baustein; `augenrules` fügt sie in natürlicher Sortierung zusammen (`ls -v`, also
kommt `100-` nach `60-`), entfernt Kommentare und Leerzeilen und schreibt das Ergebnis nach
`/etc/audit/audit.rules` (`augenrules(8)`). Dateien mit anderer Endung werden ignoriert. Das
Handbuch nennt drei Regeln zur Position: Das letzte `-D` ohne Option wird zuerst ausgegeben,
dann das letzte `-b` und `-f`, und **das letzte `-e` wird immer als letzte Zeile ausgegeben**.
Ich habe es mit audit 3.1.2 getestet: Ein `-e 2` in einer Datei `05-early.rules` landete in
`audit.rules` ganz am Ende, hinter den Regeln von `100-late.rules`; eine `*.conf`-Datei im
Verzeichnis wurde ignoriert. Derselbe Test zeigte eine Falle für Skripte: `augenrules --check`
gibt `Rules have changed and should be updated` oder `No change` aus, sein Exit-Code ist aber in
beiden Fällen 0 (audit 3.1.2; andere Versionen nicht getestet). Eine Task muss also den Text
lesen.

Zwei Zustände muss man auseinanderhalten. Die Dateien sind *Konfiguration*; die *geladenen*
Regeln leben im Kernel. Eine Datei zu schreiben auditiert nichts: `augenrules --load` (oder der
Start des Dienstes, unten) schickt den zusammengefügten Satz an den Kernel, und `auditctl -l`
listet, was geladen ist. Welche Unit das Laden übernimmt, hängt von der Version ab. Auf den
sieben systemd-Hosts des Labs (audit 4.0 und neuer) gibt es neben `auditd.service` eine zweite
Unit `audit-rules.service`; auf opensuse hat `auditd.service` noch
`ExecStartPost=-/sbin/augenrules --load`. `systemctl cat` zeigt, was ein Host tut. Auch die
Startpunkte der Pakete unterscheiden sich: debian, ubuntu, rocky und alma liefern eine
`rules.d/audit.rules` mit `-D`, `-b 8192`, `--backlog_wait_time 60000` und `-f 1`; fedora und
opensuse liefern `-D` und `-a task,never`; auf alpine und arch ist das Verzeichnis leer.

Das Enabled-Flag hat drei Werte (`auditctl(8)`): `-e 0` schaltet das Auditing aus, `-e 1` ein,
`-e 2` **sperrt** die Konfiguration. Eine gesperrte Konfiguration lehnt jede Änderung ab, der
Versuch wird auditiert, und nur ein Neustart hebt die Sperre auf. Das ist der Sinn (ein Angreifer
mit root kann die Regeln nicht einfach löschen) und ein Preis für die Automatisierung: Ein Fehler
in einem gesperrten Regelsatz wird mit einem Neustart behoben, und ein Play, das Regeln auf einem
gesperrt laufenden Host ändern will, kann das nicht. Teste die Regeln entsperrt, sperre nur den
endgültigen Satz und plane den Neustart ein.

#### Wenn das Log wächst: `auditd.conf`

Audit-Logs wachsen ohne Grenze, bis jemand eine setzt, und eine volle Platte ist ein schlechter
Moment, um zu entscheiden, was der Daemon tun soll. `/etc/audit/auditd.conf` ist eine
`key = value`-Datei (`auditd.conf(5)`) mit drei Stufen:

| Stufe | Einstellung | Der Daemon kann ... |
|---|---|---|
| eine Logdatei hat ihre Größe erreicht | `max_log_file` (MB), `max_log_file_action` | `ignore`, `syslog`, `suspend`, `rotate` (`num_logs` Dateien behalten, die älteste wird überschrieben), `keep_logs` (wie `rotate`, aber nichts wird je gelöscht) |
| der Platz wird knapp | `space_left`, `space_left_action` | `ignore`, `syslog`, `rotate`, `email`, `exec <Skript>`, `suspend`, `single`, `halt` |
| letzte Chance vor der vollen Platte | `admin_space_left` (die kleinere Zahl), `admin_space_left_action` | dieselbe Liste |
| Platte voll oder Schreibfehler | `disk_full_action`, `disk_error_action` | `ignore`, `syslog`, `exec`, `suspend`, `single`, `halt` (`rotate` bei voller Platte) |

`email` schickt eine Nachricht an `action_mail_acct` und an syslog und braucht ein Mailsystem
(laut Handbuch muss `/usr/lib/sendmail` existieren). `suspend` hält den Daemon am Leben, aber
er schreibt nicht mehr - das Audit-Log hat eine Lücke. `single` und `halt` halten die Maschine
an: Es gehen keine Ereignisse verloren, aber auch die Verfügbarkeit wird nicht geschont.
`keep_logs` verliert von sich aus nichts, lässt aber die Platte volllaufen und löst damit die
nächste Stufe aus; das Handbuch nennt es am besten kombiniert mit einem Skript, das Logs
archiviert.

Die ausgelieferten Standardwerte sind auf allen acht Lab-Hosts identisch (und auf dem
Ubuntu-24.04-Host, mit dem ich getestet habe): 8 MB je Datei, `rotate` mit 5 Dateien, eine
`syslog`-Warnung bei 75 MB frei, `suspend` bei 50 MB frei und bei voller Platte oder
Schreibfehler. Sie legen die Maschine nie lahm, und sie verlieren Datensätze: `rotate`
überschreibt die älteste Datei, und `suspend` hinterlässt eine Lücke. Eine gehärtete Einstellung
wählt, welchen der beiden Fehler du in Kauf nimmst - Vollständigkeit des Audits oder
Verfügbarkeit -, und die Wahl gehört in die Ausnahmeliste aus L01, nicht in einen Kommentar.

### AIDE: Baseline, Prüfung, Update

Audit-Datensätze sagen, wer etwas getan hat. Sie sagen nicht, ob die Binärdatei in `/usr/bin`
noch die ist, die das Paket geliefert hat. **AIDE** (Advanced Intrusion Detection Environment)
beantwortet das: Es hält Attribute und Hashes ausgewählter Dateien in einer **Datenbank** fest,
der *Baseline*, und eine spätere **Prüfung** vergleicht das Dateisystem damit.

Was festgehalten wird, bestimmt die Konfiguration (`aide.conf(5)`). Eine **Regel** ist ein
benannter Satz von Attributen, mit `+` und `-` gebaut; `p` sind Rechte, `u` Besitzer, `g`
Gruppe, `s` Größe, `m` mtime, und ein Prüfsummenname wie `sha256` fügt den Inhalts-Hash hinzu.
**Auswahlzeilen** hängen eine Regel an Pfade: `/pfad Regel` nimmt alles auf, dessen Pfad auf den
regulären Ausdruck passt, `!/pfad` lässt es weg, `=/pfad` nimmt nur diese Ebene auf (die
Kinder eines Verzeichnisses nur, wenn der Ausdruck auf `/` endet). Ein regulärer Ausdruck muss
mit `/` beginnen und ist am Anfang des Pfads verankert. An einem kleinen Baum getestet: Ein mit
`!` ausgeschlossener Pfad erzeugte keine Meldung, als er sich änderte, und eine Datei, deren
Inhalt bei gleicher Größe geändert und deren alte mtime zurückgesetzt wurde, meldete eine Regel
mit `sha256` - eine Regel nur mit `p+u+g+s+m` meldete sie **nicht**. Darum vergleicht eine
Prüfung Hashes: Größe und mtime stellt ein Angreifer als Erstes wieder her.

Drei Einstellungen benennen die Datenbanken: `database_in` liest eine Prüfung und ein Update,
`database_out` schreiben `--init` und `--update`, `database_new` ist die zweite Datenbank von
`--compare`. Daraus folgt ein Schritt, den man gern vergisst: `--init` schreibt `database_out`
und lässt `database_in` in Ruhe, die neue Datenbank muss also unter den Namen `database_in`
**übernommen** werden, bevor die erste Prüfung funktioniert (`aide(1)`). Debian fügt einen
Wrapper hinzu, `aideinit`, der die Datenbank baut und anbietet, die alte zu ersetzen; die
Red-Hat-Familie hat keinen.

Eine Prüfung meldet ihr Ergebnis im **Exit-Code**, aus drei Bits gebildet: 1, wenn Dateien
hinzugekommen sind, 2, wenn Dateien entfernt wurden, 4, wenn Dateien sich geändert haben,
summiert (`aide(1)`). Hinzugekommen und geändert ist 5, entfernt und geändert 6. Codes ab 14 sind
Fehler; eine fehlende Datenbank ergab in meinem Test 18. Ein Aufrufer muss 1 bis 7 deshalb als
„Unterschiede gefunden" behandeln, nicht als „das Werkzeug ist gescheitert", und nur 0 ist ein
sauberes Ergebnis. `--update` liefert dieselben Codes: Es meldet die Unterschiede *und* schreibt
eine neue Datenbank, weiterhin nach `database_out` (getestet), die dann wie die erste übernommen
werden muss.

Der Mechanismus ist der leichte Teil; der **Prozess** entscheidet, ob es eine Kontrolle ist:

- **Durchsicht vor der Übernahme.** Nach jedem Patch-Lauf weicht das Dateisystem von der Baseline
  ab. Ein Update, das ohne Lesen des Berichts übernommen wird, akzeptiert alles, was sich sonst
  noch geändert hat - einen Einbruch eingeschlossen. Ein Patch-Ablauf bekommt zwei Schritte:
  prüfen und lesen, dann aktualisieren und übernehmen.
- **Wo die Datenbank liegt.** Ein Angreifer mit root auf dem Host kann die Dateien *und* die
  Datenbank umschreiben. Eine Baseline, auf die es ankommt, wird vom Host weg kopiert oder dort
  abgelegt, wo der überwachte Host nicht schreiben kann. Das Lab tut das nicht; ein echter Host
  sollte es.
- **Kosten.** Die Initialisierung liest jede ausgewählte Datei, ein ganzes Dateisystem braucht
  also Minuten, proportional zu seiner Größe. Auswahlzeilen sollten flüchtige Pfade auslassen
  (Logs, Caches); einen Bericht voller erwarteter Änderungen liest niemand.

Eine Prüfung, die niemand startet, schützt nichts, also läuft sie nach Zeitplan. Auf einem
systemd-Host besteht ein Zeitplan aus **zwei Units**: einem *Timer*, der sagt wann, und einem
*Service*, der sagt was. Der Timer trägt `OnCalendar=` (ein Kalenderausdruck, `systemd.time(7)`),
`Persistent=true` (der Zeitpunkt des letzten Laufs wird auf der Platte gehalten, und ein Lauf, der
verpasst wurde, weil der Host aus war, findet beim nächsten Start statt) und oft
`RandomizedDelaySec=` (eine zufällige Verzögerung, damit viele Hosts nicht im selben Moment
starten). Der Service ist vom `Type=oneshot`: Er gilt als aktiv, bis sein Hauptprozess endet, und
ist dann einfach tot, was für eine Prüfung richtig ist, die läuft und endet
(`systemd.timer(5)`, `systemd.service(5)`). systemd hält Unit-Dateien im Speicher, eine auf der
Platte geänderte Unit wird also erst nach `systemctl daemon-reload` gesehen. Ein Kalenderausdruck
ist leicht falsch und billig zu testen, denn `systemd-analyze` wertet ihn ohne jede Unit aus:

```yaml
- name: When would a timer with this expression fire?
  hosts: targets:!alpine
  gather_facts: false
  tasks:
    - name: Evaluate a calendar expression
      ansible.builtin.command: systemd-analyze calendar '*-*-* 05:30:00' --iterations=3
      register: calendar
      changed_when: false
      check_mode: false
    - name: Show the next three runs
      ansible.builtin.debug:
        var: calendar.stdout_lines
```

Die ausgelieferten Pakete unterscheiden sich: Debian und Ubuntu installieren
`dailyaidecheck.timer` und einen passenden Service (debian 13 und ubuntu 26.04 zusätzlich
`dailyaidecheck-buildcache.service`); die Red-Hat-Familie liefert weder Timer noch Cron-Datei,
nur eine logrotate-Datei (eine Suche in den Dateien `systemd/system`, `/etc/cron*` und
`/etc/default` des Pakets fand keine).

Dieses Play baut eine Baseline auf einem winzigen Baum mit eigener Konfiguration, läuft also in
Sekunden und lässt das AIDE des Hosts in Ruhe. Es installiert AIDE auf den fünf Hosts von 4.08,
ändert eine Datei **nach** der Baseline und prüft:

```yaml
- name: Baseline, tamper, check - on a tiny tree
  hosts: debian_family:redhat_family
  become: true
  vars:
    demo: /tmp/lesson09
  tasks:
    - name: Refresh the apt index (the Debian images ship without one)
      ansible.builtin.apt:
        update_cache: true
      changed_when: false
      check_mode: false
      when: ansible_facts.os_family == 'Debian'
    - name: Install AIDE
      ansible.builtin.package:
        name: aide
        state: present
    - name: Create the directories for the files and the database
      ansible.builtin.file:
        path: "{{ demo }}/{{ item }}"
        state: directory
        mode: "0700"
      loop: [data, db]
    - name: Create the watched file once
      ansible.builtin.copy:
        dest: "{{ demo }}/data/app.conf"
        content: "level=1\n"
        force: false
        mode: "0644"
    - name: Write a minimal AIDE configuration
      ansible.builtin.copy:
        dest: "{{ demo }}/aide.conf"
        content: |
          database_in=file:{{ demo }}/db/aide.db
          database_out=file:{{ demo }}/db/aide.db.new
          database_new=file:{{ demo }}/db/aide.db.new
          report_url=stdout
          Hash = p+u+g+s+m+sha256
          {{ demo }}/data Hash
        mode: "0644"
    - name: Build the new database
      ansible.builtin.command:
        cmd: "aide --init --config {{ demo }}/aide.conf"
        creates: "{{ demo }}/db/aide.db.new"
    - name: Promote it to the baseline (never overwrite an existing one)
      ansible.builtin.copy:
        src: "{{ demo }}/db/aide.db.new"
        dest: "{{ demo }}/db/aide.db"
        remote_src: true
        force: false
        mode: "0600"
      when: not ansible_check_mode
    - name: Change the file after the baseline
      ansible.builtin.copy:
        dest: "{{ demo }}/data/app.conf"
        content: "level=9\n"
        mode: "0644"
    - name: Check against the baseline
      ansible.builtin.command: "aide --check --config {{ demo }}/aide.conf"
      register: aide_check
      changed_when: false
      failed_when: aide_check.rc > 7
      check_mode: false
      when: not ansible_check_mode
    - name: Read the result
      ansible.builtin.debug:
        msg:
          rc: "{{ aide_check.rc }}"
          summary: "{{ aide_check.stdout_lines | select('search', '(Added|Removed|Changed) entries') | list }}"
      when: not ansible_check_mode
```

Der Exit-Code ist 4: eine Datei geändert, keine hinzugekommen oder entfernt. Ein zweiter Lauf
ändert nichts (die Datei sagt schon `level=9`) und meldet wieder 4, weil die Baseline noch
`level=1` sagt. Unter `--check` werden Übernahme und Prüfung übersprungen: Auf einem frischen
Host gibt es noch keine Datenbank. Entferne die Demo mit `rm -rf /tmp/lesson09` (das Paket
bleibt) oder `./lab.sh reset <Host>` (`.\lab.ps1 reset <Host>` unter Windows).

### Langlaufende Tasks: `async`, `poll` und `async_status`

Eine normale Task hält die Verbindung zu ihrem Host, bis das Modul zurückkehrt. Ein Scan von
Minuten macht das sichtbar: Das Play wartet, die Verbindung muss das Warten überstehen, und der
Host belegt einen von Ansibles parallelen Plätzen (`forks`, 10 in der `ansible.cfg` des Labs).
**Asynchrone Tasks** übergeben die Arbeit an einen Hintergrundprozess auf dem Target und lassen
die Verbindung los:

- `async: N` ist das **Zeitlimit** in Sekunden für den Job, keine Verzögerung. Ein Job, der es
  überschreitet, wird gestoppt und als `Timeout exceeded` gemeldet (getestet).
- `poll: N` mit N über null lässt Ansible **warten**: Es fragt alle N Sekunden nach dem Zustand,
  hält den Host belegt, und die Task endet mit dem echten Ergebnis des Jobs. Die Hosts laufen
  weiter nebeneinander, soweit `forks` es erlaubt.
- `poll: 0` ist **fire and forget**: Die Task kehrt zurück, sobald der Job *gestartet* ist, mit
  einer Job-ID und `started: true`, und das Play geht weiter. Das Ergebnis einzusammeln ist eine
  eigene Task, `ansible.builtin.async_status`, die nach der Job-ID fragt und `finished: false`
  meldet, bis der Job fertig ist. Eine Schleife mit `until: result.finished`, `retries` und
  `delay` ist der übliche Weg zu warten.

Auf dem Target schreibt der Job seinen Zustand in eine Datei unter dem Home des ausführenden
Benutzers, `~/.ansible_async/<Job-ID>` (`/root/.ansible_async/...` mit `become`), die
`async_status` liest. `mode: cleanup` entfernt sie.

```yaml
- name: Start a slow job, then collect it
  hosts: targets
  gather_facts: false
  tasks:
    - name: Start a job that takes a few seconds
      ansible.builtin.command: sh -c 'sleep 5; echo finished > /tmp/lesson09-job.txt'
      async: 60
      poll: 0
      register: slow_job
      changed_when: false
    - name: The play moves on at once
      ansible.builtin.debug:
        msg: "job {{ slow_job.ansible_job_id }} runs in the background, state in {{ slow_job.results_file }}"
    - name: Wait for the job
      ansible.builtin.async_status:
        jid: "{{ slow_job.ansible_job_id }}"
      register: slow_result
      until: slow_result.finished
      retries: 10
      delay: 2
      changed_when: false
    - name: Show the outcome
      ansible.builtin.debug:
        msg: "rc={{ slow_result.rc }} after {{ slow_result.attempts }} attempts"
```

Die Wait-Task gibt `FAILED - RETRYING`-Zeilen aus, solange der Job läuft; sie bedeuten „noch
nicht fertig", nicht Fehler. Beide `changed_when: false` halten das Play wiederholbar: Ohne sie
erscheint ein Job in der Zusammenfassung als **zwei** Änderungen, weil `async_status` das eigene
`changed` des Jobs übernimmt (getestet).

Vier Eigenschaften bestimmen, wie du solche Tasks schreibst:

- **Ein Fehler bleibt unsichtbar, bis du ihn einsammelst.** Die Start-Task ist `changed`, was
  immer der Job tun wird. In einem Test ließ ein Job, der mit 3 endete, die Zusammenfassung bei
  `failed=0`; der Fehler erschien erst, als `async_status` den Job las (`finished: true`,
  `failed: true`, `rc: 3`, die stderr). Ein Job, den niemand einsammelt, kann ohne jede Spur im
  Lauf scheitern.
- **Ein Job überlebt das Play.** Ein mit `poll: 0` gestarteter und nie eingesammelter Job lief
  nach dem Ende des Plays noch zu Ende (getestet). Was vom Ergebnis abhängt, muss es einsammeln.
- **Mehrere Elemente, mehrere Jobs.** Eine Task mit `loop` und `poll: 0` startet einen Job je
  Element und gibt eine Liste zurück; die einsammelnde Task läuft über `results`.
- **Es macht den Job nicht schneller.** Was der Job tut, dauert, solange es dauert. Mit vier
  Hosts und 3 Sekunden Schlaf brauchte die Vordergrund-Task 3,9 s mit `forks=10` und 7,1 s mit
  `forks=2`; dasselbe mit `poll: 0` und Wait-Schleife brauchte 5,1 s und 5,9 s, und mit `poll: 1`
  9,1 s bei `forks=2` (je ein einzelner Lauf, auf einer Maschine). Passen alle Hosts in `forks`,
  ist eine gewöhnliche Task so parallel wie eine Hintergrund-Task. `async` lohnt sich, wenn es
  mehr Hosts gibt als `forks`, wenn das Play Anderes tun soll, während der Job läuft, oder wenn
  der Job nicht davon abhängen darf, dass eine Verbindung steht.

### Hintergrund-Jobs und Idempotenz

L00 hat die Regel eingeführt: Ein zweiter Lauf ändert nichts. Eine `command`-Task erreicht das
mit `creates:`, das den Befehl überspringt, wenn eine Datei existiert. Mit `poll: 0` bricht das.
Das Ergebnis der Task ist nur „Job gestartet", und das Modul - samt seinem `creates:`-Test -
läuft später im Hintergrund, nachdem der Status der Start-Task schon entschieden war. Dieses Play
startet einen Job, der eine Marker-Datei per `creates:` absichert; lass es **zweimal** laufen:

```yaml
- name: Why creates is not enough with poll 0
  hosts: targets
  gather_facts: false
  tasks:
    - name: Start the job, guarded only by creates
      ansible.builtin.command:
        cmd: sh -c 'sleep 1; echo built > /tmp/lesson09-marker'
        creates: /tmp/lesson09-marker
      async: 30
      poll: 0
      register: marker_job
    - name: Collect the job
      ansible.builtin.async_status:
        jid: "{{ marker_job.ansible_job_id }}"
      register: marker_result
      until: marker_result.finished
      retries: 10
      delay: 1
    - name: What the job itself reported
      ansible.builtin.debug:
        msg: "changed={{ marker_result.changed }} {{ marker_result.msg }}"
```

Erster Lauf: `changed=2` in der Zusammenfassung (Start und Einsammeln). Zweiter Lauf: Der Marker
existiert, der Job meldet `changed=False Did not run command since '/tmp/lesson09-marker'
exists` - und die Zusammenfassung sagt trotzdem `changed=1`, weil die Start-Task schon `changed`
war. Unter `--check` ist es dasselbe: Die Start-Task meldet `changed`, obwohl der Job im
Check-Modus nichts tut (der Marker wurde in einem Test auf einem frischen Host nicht angelegt).
Das Play ist nicht idempotent, und ein Prüfer, der ein zweites Mal läuft, wird das sagen. Die
Ursache zeigt den Ausweg: Die Entscheidung „brauchen wir diesen Job überhaupt?" muss **vor** dem
Start des Jobs fallen, von einer Task, die im Vordergrund läuft und ein ehrliches eigenes
`changed` hat. Was diese Task ist, ist der Teil von 4.08, den du selbst baust. `creates:` bleibt
nützlich als Wächter *im* Job, falls zwei Läufe sich überschneiden.

Entferne den Marker und die Job-Datei mit `rm -f /tmp/lesson09-marker /tmp/lesson09-job.txt`.

## CIS-Hintergrund

Abschnitt **6.3** des [Kontrollkatalogs](../../cis/controls.yml) ist Level 2 und mit
`container: config` markiert; Abschnitt **6.1** ist Level 1 und `container: full`. 6.3 verlangt,
dass die wichtigen Ereignisse eines Hosts dort aufgezeichnet werden, wo ein Angreifer sie nicht
löschen kann: Änderungen daran, wer mit administrativen Rechten handeln darf, als anderer Benutzer
ausgeführte Befehle, Änderungen der Uhr (die den Abgleich von Logs durcheinanderbringt),
Änderungen an Konten und an den Dateien, die über die Prüfung einer Anmeldung entscheiden, und die
Anmeldeprotokolle selbst; dass der Regelsatz gegen Änderung gesperrt ist; und dass das Log eine
Aufbewahrungsregel hat. 6.1 verlangt die andere Hälfte: einen Prüfer, der weiß, wie die Dateien
aussehen sollen, mit initialisierter Datenbank und regelmäßiger Prüfung.

Die Kosten sind der Grund, warum 6.3 Level 2 ist. Auditing braucht Plattenplatz, CPU für
Syscall-Regeln und Menschen, die die Ausgabe lesen; ein unveränderlicher Regelsatz braucht für
jede Änderung einen Neustart; und `single`/`halt` bei voller Platte tauscht Verfügbarkeit gegen
Audit. AIDE kostet I/O beim Scan und Aufmerksamkeit bei jedem Patch-Fenster. Ein Level-1-AIDE
ohne Durchsichtsprozess erzeugt Berichte, die niemand liest, und ein Audit-Log, das niemand
durchsucht, ist Speicherplatz. Benchmarks nummerieren das unterschiedlich (L01), und manche
aktuellen Benchmarks legen die beiden Themen an verschiedene Stellen; die Katalog-IDs sind die
des Labs. Das Lab kann auditd konfigurieren, aber nicht betreiben (siehe unten), und AIDE kann es
vollständig betreiben.

## Plattformunterschiede

| os_family | Hosts | Audit-Paket (gemessene Version) | In `rules.d` ausgelieferte Regeln | Units nach der Installation | AIDE |
|---|---|---|---|---|---|
| Debian | debian (13), ubuntu (26.04) | `auditd` (4.0.2, 4.1.2) | `-D`, `-b 8192`, `--backlog_wait_time 60000`, `-f 1` | `auditd.service`, `audit-rules.service`, beide aktiviert | `aide` und `aide-common` (0.19.1, 0.19.2), `/etc/aide/aide.conf`, Datenbank `/var/lib/aide/aide.db`, Wrapper `aideinit`, `dailyaidecheck.timer` |
| RedHat | rocky (10.2), alma (10.2), fedora (44) | `audit` (4.0.3, 4.0.3, 4.2.1) | rocky und alma: die vier Zeilen von Debian; fedora: `-D`, `-a task,never` | beide aktiviert; `auditd` war auf rocky `activating`, auf alma und fedora `failed` | `aide` (0.19.2), `/etc/aide.conf`, Datenbank `/var/lib/aide/aide.db.gz`, kein `aideinit`, kein Timer |
| Suse | opensuse (Leap 16.0) | `audit` (4.0) | `-D`, `-a task,never` | beide aktiviert, `auditd` inaktiv; `auditd.service` führt nach dem Start `augenrules --load` aus | nicht in 4.08; `aide` war nicht installiert, nach dem Paket habe ich nicht gesucht |
| Alpine | alpine (3.24) | `audit` (4.1.2) | keine (`rules.d` ist leer) | OpenRC-Skript `/etc/init.d/auditd`, gestoppt | nicht in 4.08, kein `aide` |
| Archlinux | arch | `audit` (4.2.1) | keine (`rules.d` ist leer) | beide Units vorhanden und deaktiviert | nicht in 4.08, kein `aide` |

Alle Werte wurden auf den Targets des Labs nach der Paketinstallation gemessen (die
Debian-Familie mit unterdrücktem Dienststart, deshalb ist ihr `is-active` nicht angegeben).
`auditd.conf` ist `/etc/audit/auditd.conf` mit denselben zehn Standardwerten auf allen acht Hosts
(siehe oben); `augenrules`, `auditctl` und `ausearch` sind überall vorhanden, wo das Paket ist,
auch auf alpine. Welche Unit die Regeln lädt, hängt von der Version ab: Lies
`systemctl cat auditd.service audit-rules.service`, bevor du etwas annimmst. Die AIDE-Optionsnamen
(`database_in` und so weiter) sind in beiden Konfigurationen gleich; die Red-Hat-Datei baut ihre
Pfade aus `@@define DBDIR` und komprimiert die Datenbank (`gzip_dbout=yes`, `.gz`), die
Debian-Datei listet drei `@@x_include`-Zeilen.

### In den Lab-Containern

- Das Audit-Subsystem gehört zum Kernel des Hosts, deshalb **konfiguriert** das Lab auditd nur
  ([Container-Grenzen](../CONTAINER_LIMITS.de.md)): Dateien werden geschrieben, nichts wird
  geladen und absichtlich kein Dienst gestartet. Die Referenzlösungen sichern das mit
  `lab_in_container` ab (L05). Auf einer VM oder Bare Metal aktiviert und startet dieselbe Rolle
  auch den Dienst. Nach einer reinen Paketinstallation hatten die RPM-Hosts oben `auditd` schon
  aktiviert, und drei von ihnen hatten versucht, ihn zu starten; im Lab hängt nichts davon ab.
- AIDE läuft vollständig: Es scannt das Dateisystem des Containers. Eine erste Datenbank eines
  ganzen Targets braucht Minuten, was der Grund für den `async`-Teil von 4.08 ist.
- Die `async`-Beispiele brauchen nur die Voraussetzung aus 0.02; `systemd-analyze` gibt es nur
  auf den sieben systemd-Hosts, daher `targets:!alpine`. Das AIDE-Beispiel braucht Netzzugang für
  das Paket und die fünf Hosts von 4.08.

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| Eine Regeldatei liegt in `rules.d` und nichts wird auditiert | die Dateien sind Konfiguration; die Regeln gelten erst, wenn sie geladen sind | laden (`augenrules --load` oder den Dienst starten) - auf einem echten Host, nie im Lab |
| Eine Regeldatei wird ignoriert | der Name endet nicht auf `.rules` | umbenennen; das zusammengefügte Ergebnis in `/etc/audit/audit.rules` lesen |
| Regeln werden in unerwarteter Reihenfolge zusammengefügt | natürliche Sortierung der Dateinamen: `100-` nach `60-`, `5-` vor `50-` | numerische Präfixe fester Breite verwenden |
| `augenrules --check` ist „erfolgreich", obwohl sich die Regeln geändert haben | sein Exit-Code ist in beiden Fällen 0 | seinen Text lesen oder die erzeugte Datei vergleichen |
| Eine Regeländerung auf einem laufenden Host bleibt wirkungslos | der Satz wurde mit `-e 2` gesperrt | neu starten oder die Sperre beim Testen weglassen |
| Das Audit-Log hat eine Lücke | `suspend` (oder eine volle Platte mit `suspend`) stoppt das Schreiben | die Aktionen bewusst wählen und den freien Platz beobachten |
| `aide --check` scheitert in einem Play, obwohl es funktionierte | jeder Unterschied ergibt einen Code ungleich null (1 bis 7) | 1 bis 7 als „Unterschiede" akzeptieren, nur bei höheren Codes scheitern |
| `aide --check` nach `--init` meldet eine fehlende Datenbank | `--init` schreibt `database_out`, die Prüfung liest `database_in` | die neue Datei unter den Namen `database_in` übernehmen |
| Ein AIDE-Bericht ist nach dem Patchen voller Änderungen | die Baseline ist älter als das Update | den Bericht lesen, dann aktualisieren und die neue Datenbank übernehmen |
| `FAILED - RETRYING` erscheint in der Ausgabe | `async_status` hat `finished` noch nicht gesehen | nichts - es ist die Wait-Schleife; sie scheitert erst, wenn die Retries aufgebraucht sind |
| Ein Hintergrund-Job ist gescheitert und der Lauf ist grün | die Start-Task sagt nur „gestartet" | mit `async_status` einsammeln und `failed` oder `rc` prüfen |
| Eine `poll: 0`-Task mit `creates:` ist bei jedem Lauf `changed` | das Modul und sein `creates:` laufen später im Hintergrund | vor dem Start des Jobs entscheiden |

## Übungen

| Übung | Worauf diese Lektion vorbereitet |
|---|---|
| [3.04](../../exercises/stage3-intermediate/3.04-auditd-rules/README.de.md) | was das Audit-Subsystem ist und warum das Lab es nur konfiguriert, Regelarten, Keys, `rules.d` und das Zusammenfügen, `-e 2`, die Aktionen in `auditd.conf` |
| [4.08](../../exercises/stage4-advanced/4.08-aide-async/README.de.md) | Baseline, `database_in`/`database_out`, Exit-Codes, Timer- und Service-Units, `async`, `poll: 0`, `async_status` und die Idempotenz-Falle |

Starte eine Übung mit `lab start <id>`; `lab show <id>` gibt ihre README aus.

## Selbstkontrolle

1. Eine Datei `/etc/audit/rules.d/50-demo.rules` enthält eine Regel, und der Host wurde vor einer
   Stunde installiert. Wird etwas auditiert? Was würdest du prüfen, und wo?

   <details><summary>Antwort</summary>

   Nicht unbedingt: Die Dateien sind Konfiguration, und die Regeln zählen erst, wenn sie in den
   Kernel geladen sind. `auditctl -l` listet die geladenen Regeln; `/etc/audit/audit.rules` ist
   die zusammengefügte Datei, und die Units des Init-Systems (`auditd.service`, in neueren
   Versionen auch `audit-rules.service`) übernehmen das Laden.

   </details>

2. `rules.d` enthält `100-late.rules`, `60-watch.rules` und `05-lock.rules`, und nur die letzte
   hat `-e 2`. In welcher Reihenfolge werden die Dateien zusammengefügt, und wo steht das `-e 2`
   in `/etc/audit/audit.rules`?

   <details><summary>Antwort</summary>

   In natürlicher Sortierung: `05-lock.rules`, `60-watch.rules`, `100-late.rules` (eine reine
   alphabetische Sortierung würde `100-` an den Anfang stellen). Das letzte `-e` des
   Zusammenfügens wird unabhängig von seiner Position als letzte Zeile der erzeugten Datei
   ausgegeben, das Lock steht also hinter den Regeln von `100-late.rules`.

   </details>

3. Warum sagt eine Regel, die echte Benutzer auswählt, `-F auid>=1000 -F auid!=unset`, und was
   gibt das Demo-Play für `uid` und `loginuid` mit `become: true` aus?

   <details><summary>Antwort</summary>

   Eine ungesetzte loginuid ist -1, was das Audit-System als vorzeichenlose Zahl behandelt
   (4294967295); sie besteht `>=1000` und muss gesondert ausgeschlossen werden. Mit `become` ist
   die uid 0 und die loginuid die ID des Kontos, mit dem Ansible sich angemeldet hat (alpine:
   ungesetzt).

   </details>

4. Die Platte mit dem Audit-Log ist fast voll. Was passiert mit `rotate`, `suspend`, `single` und
   `keep_logs` als Aktion, und was kostet jede?

   <details><summary>Antwort</summary>

   `rotate` entfernt die ältesten Datensätze, um Platz zu schaffen: Der Host läuft weiter und
   verliert Beweise. `suspend` hält den Daemon am Leben, aber er schreibt nicht mehr: eine Lücke
   im Log. `single` versetzt die Maschine in den Einzelbenutzermodus: nichts geht verloren, und
   der Dienst ist unten. `keep_logs` löscht nichts, ist also keine Antwort auf eine volle Platte,
   nur ein Grund, dass die nächste Stufe auslöst.

   </details>

5. Eine AIDE-Prüfung endet mit Exit-Code 6, eine andere mit 0. Was sagen die Zahlen, und warum
   sollte ein Play bei 6 nicht scheitern?

   <details><summary>Antwort</summary>

   0 heißt keine Unterschiede. 6 ist 2 + 4: Dateien wurden entfernt und Dateien geändert; der
   Code ist eine Summe aus drei Bits (1 hinzugekommen, 2 entfernt, 4 geändert). Die Codes 1 bis 7
   bedeuten „das Werkzeug hat funktioniert und Unterschiede gefunden", was seine Aufgabe ist;
   dabei zu scheitern verbirgt den Bericht. Scheitere bei Codes über 7, das sind Fehler.

   </details>

6. Nach einem Patch-Lauf meldet AIDE 40 geänderte Dateien. Du führst `--update` aus und legst die
   neue Datenbank an ihren Platz, ohne den Bericht zu lesen. Was hast du aufgegeben?

   <details><summary>Antwort</summary>

   Die Baseline enthält jetzt alles, was sich sonst noch geändert hat - eine ausgetauschte
   Binärdatei unter den 40 Dateien eingeschlossen. Lies zuerst den Bericht (passt die Liste zu den
   aktualisierten Paketen?), dann aktualisiere und übernimm. Die Prüfung ist nur so gut wie die
   Durchsicht vor der Übernahme.

   </details>

7. Eine Task startet einen Job mit `async: 600` und `poll: 0`; der Job scheitert nach einer
   Sekunde. Was zeigt die Zusammenfassung, wo siehst du den Fehler, und was ändert sich, wenn das
   Play direkt nach dem Start endet?

   <details><summary>Antwort</summary>

   Die Start-Task ist `changed`, und die Zusammenfassung zeigt keinen Fehler. Der Fehler ist nur
   über `async_status` für die Job-ID sichtbar (`failed: true`, `rc`, stderr). Endet das Play, ohne
   einzusammeln, liest niemand das Ergebnis und der Lauf ist grün; und ein Job, der noch läuft,
   läuft nach dem Play weiter.

   </details>

8. Dieselbe Task hat `creates: /var/lib/x/db`, die Datei existiert, und das Play meldet trotzdem
   bei jedem Lauf `changed`, auch mit `--check`. Warum, und wohin muss die Entscheidung wandern?

   <details><summary>Antwort</summary>

   Mit `poll: 0` ist die Start-Task entschieden, bevor das Modul läuft: Sie meldet, dass ein Job
   gestartet wurde. Das Modul und sein `creates:`-Test laufen später im Hintergrund, und nur das
   eigene Ergebnis des Jobs (`async_status`) sagt „nicht ausgeführt, Datei existiert". Die
   Entscheidung muss vor dem Start des Jobs fallen, in einer Vordergrund-Task, die ihren eigenen
   Zustand meldet.

   </details>

## Weiterführendes

- [`ansible.builtin.async_status`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/async_status_module.html) und [Asynchronous actions and polling](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_async.html) - der Mechanismus und seine Grenzen
- [`ansible.builtin.command`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html) - `creates` und `removes`
- [`audit.rules(7)`](https://man.archlinux.org/man/audit.rules.7) und [`auditctl(8)`](https://man.archlinux.org/man/auditctl.8) - Regelsyntax, Felder, das Enabled-Flag
- [`augenrules(8)`](https://man.archlinux.org/man/augenrules.8) und [`auditd.conf(5)`](https://man.archlinux.org/man/auditd.conf.5) - Zusammenfügen der Regeldateien und Einstellungen des Daemons
- [`pam_loginuid(8)`](https://man.archlinux.org/man/pam_loginuid.8) - woher die Login-ID kommt
- [`aide(1)`](https://manpages.debian.org/unstable/aide/aide.1.en.html) und [`aide.conf(5)`](https://manpages.debian.org/unstable/aide/aide.conf.5.en.html) - Befehle, Exit-Codes, Regeln und Auswahlzeilen
- [`systemd.timer(5)`](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html) und [`systemd.service(5)`](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html) - Timer und `Type=oneshot`
