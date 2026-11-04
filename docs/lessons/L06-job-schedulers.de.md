# L06 - Job-Scheduler: wer führt was aus und wer darf planen

*[English](L06-job-schedulers.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 2.05 | 2.4 | ~25 Min. | L02, L03, L04 |

Ein Scheduler ist ein Programm von root, das Befehle später und unbeaufsichtigt startet, nach einer
Liste, die jemand anderes aufgeschrieben hat. Damit sind die Dateien, die er liest, eines der
wertvollsten Angriffsziele eines Hosts, und wer sie ergänzen darf, eine der ersten Fragen eines
Härtungsleitfadens. Diese Lektion behandelt, woher cron und seine Verwandten ihre Jobs lesen,
welche Dateien die Daemons ablehnen, wie die Allow- und Deny-Listen wirklich arbeiten und was
sich zwischen den drei cron-Implementierungen im Lab unterscheidet.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] die Orte nennen, aus denen cron Jobs liest, und sagen, mit wessen Rechten jeder Job läuft
- [ ] erklären, warum Schreibzugriff auf eine Datei, die der Daemon liest, ein Root-Recht ist
- [ ] aus Eigentümer, Modus und Name vorhersagen, ob ein Daemon eine Drop-in-Datei akzeptiert, und die Logzeile finden, wenn nicht
- [ ] sagen, was `cron.allow` und `cron.deny` entscheiden, in welcher Reihenfolge und was sie unberührt lassen
- [ ] Debian cron, cronie und BusyBox crond daran unterscheiden, was sie lesen und was sie prüfen
- [ ] einen Job mit `ansible.builtin.cron` so schreiben, dass ein zweiter Lauf nichts ändert

## Theorie

### Woher Jobs kommen und mit wessen Rechten sie laufen

Der Daemon (`cron` oder `crond`) läuft als root, liest Job-Definitionen und startet jede als der
Benutzer, den die Definition nennt. Eine Definition stammt aus einem von drei Orten:

- **System-Crontab und Drop-ins:** `/etc/crontab` und die Dateien in `/etc/cron.d`. Eine Zeile hat
  fünf Zeitfelder, dann ein *Benutzer*-Feld, dann den Befehl.
- **Benutzer-Crontabs:** eine Datei pro Benutzer in einem Spool-Verzeichnis, bearbeitet mit
  `crontab -e`. Die Zeilen haben kein Benutzer-Feld - der Eigentümer der Datei ist der Benutzer.
- **Periodische Verzeichnisse:** `/etc/cron.hourly`, `.daily`, `.weekly`, `.monthly`. Sie sind keine
  Crontabs: Eine Zeile in einer Crontab ruft `run-parts` auf, das die ausführbaren Dateien des
  Verzeichnisses startet. Das `run-parts` von Debian überspringt Dateien mit einem Punkt im Namen
  und Dateien, die nicht ausführbar sind (getestet mit Version 5.17).

BusyBox `crond` unter Alpine ist einfacher: Er liest ein Spool-Verzeichnis, `/etc/crontabs`, mit
einer Datei pro Benutzer. Die periodischen Verzeichnisse liegen in `/etc/periodic` und werden von
Zeilen in der Crontab von *root* gestartet.

Jede Definition ist ein Befehl, der als der genannte Benutzer läuft - bei Systemdateien als root.
Wer eine solche Datei ändern oder in ein vom Daemon gelesenes Verzeichnis eine neue legen kann,
führt Code mit dieser Identität aus, und dafür muss sich niemand anmelden. Deshalb kümmert sich
ein Benchmark um Eigentümer und Modi der cron-Dateien, und deshalb ist das nächste Konzept
wichtig.

`ansible.builtin.cron` verwaltet einen Eintrag pro Task. Es markiert seine Zeile mit dem Kommentar
`#Ansible: <name>` und findet den Eintrag über diesen Namen; deshalb meldet ein zweiter Lauf `ok`
(ein umbenannter Job erzeugt daher einen zweiten Eintrag; `state: absent` mit dem Namen entfernt
ihn). Ohne `cron_file` bearbeitet es eine Benutzer-Crontab über den Befehl `crontab`; mit
`cron_file` schreibt es ein Drop-in nach `/etc/cron.d` im Systemformat, deshalb ist `user`
Pflicht:

```yaml
- name: A drop-in job and what the module wrote
  hosts: targets:!alpine
  become: true
  gather_facts: false
  tasks:
    - name: Drop-in with one nightly job
      ansible.builtin.cron:
        name: lesson demo job
        cron_file: lesson-demo
        user: root
        minute: "30"
        hour: "3"
        job: "/bin/true"
    - name: Read the file back
      ansible.builtin.command: cat /etc/cron.d/lesson-demo
      register: dropin
      changed_when: false
      when: not ansible_check_mode
    - name: Show it
      ansible.builtin.debug:
        var: dropin.stdout_lines
      when: not ansible_check_mode
```

Die Datei enthält die Markierung und die Zeile `30 3 * * * root /bin/true`, geschrieben als
`root:root` mit Modus `0644`. Das Play überspringt alpine, weil `/etc/cron.d` nicht der Ort ist, an
dem BusyBox sucht; dort bearbeitet dasselbe Modul ohne `cron_file` die Crontab von root und
funktioniert (erster Lauf `changed`, zweiter `ok`). Der harmlose Demo-Job bleibt zurück: Entferne
ihn mit `rm /etc/cron.d/lesson-demo` oder `./lab.sh reset <host>` (`.\lab.ps1 reset <host>` unter
Windows).

### Was der Daemon akzeptiert: Rechte als Voraussetzung

Rechte an cron-Dateien lesen sich wie reine Härtung: je weniger schreiben dürfen, desto besser.
Bei cron sind sie zugleich eine **Voraussetzung**. Der Daemon prüft eine Datei, bevor er ihr
gehorcht, und lehnt jede ab, die jemand anderes geändert haben könnte. Dein Play bekommt davon
nichts mit: Der Task war erfolgreich, die Datei existiert, der Job läuft nie. Gemessen mit echten
Daemons:

| Daemon | Lehnt ein Drop-in ab, wenn ... |
|---|---|
| Debian cron 3.0 (Ubuntu 24.04) | der Eigentümer nicht root ist; Gruppe oder andere schreiben dürfen; die Datei einen zweiten Hardlink hat; der Name einen Punkt enthält |
| cronie 1.7.1 (Debian-Paket; rocky lehnte `0666` und `0700` genauso ab) | der Eigentümer nicht root ist; Gruppe oder andere schreiben dürfen; ein Execute-Bit gesetzt ist (`0700` wird abgelehnt, `0400`, `0600` und `0644` laufen). Ein Punkt im Namen oder ein zweiter Hardlink wird akzeptiert |
| BusyBox crond 1.36.1 und 1.37.0 | es gibt keine Modusprüfung; die Spool-Datei muss nach einem existierenden Benutzer benannt sein - eine Datei im Besitz dieses Benutzers wurde ohne Meldung übersprungen, eine root-eigene lief (auf beiden Versionen geprüft) |

`/etc/crontab` folgt denselben Regeln: Mit Modus `0666` ignorierten Debian cron und cronie sie, mit
`0644` lief derselbe Job. Drei Folgerungen: **Eigentümer root und kein Schreibbit für Gruppe oder
andere genügt jedem Daemon**; zusätzliche Bits können schaden (ein Execute-Bit deaktiviert ein
cronie-Drop-in); und Namen aus Buchstaben, Ziffern, `-` und `_` sind überall sicher, denn die
Punkt-Regel gibt es nur bei Debian.

Eine Ablehnung landet im Log des Daemons, nicht bei Ansible. cronie schreibt
`BAD FILE MODE (<Pfad>)` oder `WRONG FILE OWNER (<Pfad>)` ins Journal; keines der sieben
systemd-Targets hat eine Datei `/var/log/cron*`. Wo und mit welchem Text das cron von Debian eine
Ablehnung meldet, habe ich nicht erfasst. Der Unit-Name unterscheidet sich je Familie (siehe die
Tabelle unten):

```bash
# Rocky: Die Unit heißt crond; Debian und openSUSE: cron; Arch: cronie
ansible rocky -b -m ansible.builtin.command -a "journalctl -u crond --no-pager -n 20"
```

Du kannst auch prüfen, bevor es der Daemon tut. Dieses Play schreibt vier Demo-Dateien mit
verschiedenen Modi in ein Scratch-Verzeichnis und listet zusammen mit dem echten `/etc/cron.d`
jede Datei auf, die nicht root gehört oder in die Gruppe oder andere schreiben dürfen:

```yaml
- name: Which drop-ins would the daemon refuse?
  hosts: targets:!alpine
  become: true
  gather_facts: false
  tasks:
    - name: Directory for the demo files
      ansible.builtin.file:
        path: /tmp/lesson-cron.d
        state: directory
        owner: root
        group: root
        mode: "0755"
    - name: One demo file per mode
      ansible.builtin.copy:
        dest: "/tmp/lesson-cron.d/{{ item.key }}"
        content: "# demo file, no job\n"
        owner: root
        group: root
        mode: "{{ item.value }}"
      loop: "{{ {'plain': '0644', 'private': '0600', 'group-writable': '0664', 'world-writable': '0666'} | dict2items }}"
      loop_control:
        label: "{{ item.key }}"
    - name: Collect the demo files and the real drop-in directory
      ansible.builtin.find:
        paths:
          - /tmp/lesson-cron.d
          - /etc/cron.d
        file_type: file
      register: found
    - name: Files that others can write or that root does not own
      vars:
        safe: "{{ found.files | rejectattr('wgrp') | rejectattr('woth') | selectattr('uid', 'equalto', 0) | map(attribute='path') | list }}"
      ansible.builtin.debug:
        msg: "{{ found.files | map(attribute='path') | difference(safe) | sort }}"
```

`find` liefert pro Datei Stat-Daten (`uid`, `wgrp`, `woth`, ...); der Filter behält, was beide
Daemons akzeptieren, und das Play gibt den Rest aus. Es bildet die Regeln nach, die die Daemons
gemeinsam haben, nicht die eines einzelnen: Weder die Punkt-Regel noch das Execute-Bit kennt es.
Entferne die Demo-Dateien mit `rm -r /tmp/lesson-cron.d`.

### Wer planen darf: Allow- und Deny-Listen

Solange nichts es einschränkt, darf ein Benutzer `crontab -e` ausführen und Jobs als sich selbst
planen. Der Befehl `crontab` befragt zwei Listendateien, in dieser Reihenfolge:

1. Existiert `/etc/cron.allow`, dürfen nur die dort genannten Benutzer `crontab` verwenden.
2. Sonst dürfen alle außer den in `/etc/cron.deny` genannten Benutzern, falls diese Datei existiert.
3. Existiert keine von beiden, entscheidet die Implementierung.

Gemessen mit Debian cron und cronie: root ist immer erlaubt, eine Allow-Datei schlägt eine
Deny-Datei, und eine *leere* Allow-Datei bedeutet: niemand außer root. Fall 3 unterscheidet sich:
Debian cron lässt alle `crontab` benutzen, das cronie-Paket von Debian nur root. Pakete der
RPM-Familie umgehen die Frage, indem sie eine leere `cron.deny` mitliefern (geprüft auf rocky, alma
und fedora), die alle zulässt. `at` hat dieselben zwei Dateien, `at.allow` und `at.deny`, aber ohne
beide darf nur root es benutzen (getestet mit `at` 3.2.5 von Debian).

Was die Listen **nicht** tun, ist ebenso wichtig (getestet mit Debian cron und cronie):

- Sie entscheiden, wer den *Befehl `crontab` benutzen* darf. Ein Benutzer, der nicht auf der
  Allow-Liste steht, behält jede bereits vorhandene Crontab, und deren Jobs laufen weiter.
- Sie wirken nicht auf `/etc/crontab`, `/etc/cron.d` und die periodischen Verzeichnisse.
- BusyBox liest keine der beiden Dateien: Die Zeichenketten `cron.allow` und `cron.deny` kommen in
  den BusyBox-Binaries 1.36.1 und 1.37.0 nicht vor (geprüft mit `grep -c -a`), also ist unter
  Alpine eine Listendatei wirkungslos.

Ein kurzes Play benennt das Modell, für das jeder Host eingerichtet ist. Es liest nur und ist
deshalb überall sicher:

```yaml
- name: Which access model does this host use?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Look for the list files of cron and at
      ansible.builtin.stat:
        path: "/etc/{{ item }}"
      loop:
        - cron.allow
        - cron.deny
        - at.allow
        - at.deny
      register: lists
    - name: Name the model for each scheduler
      vars:
        present: "{{ lists.results | selectattr('stat.exists') | map(attribute='item') | list }}"
        cron_model: "{{ 'allow list' if 'cron.allow' in present else ('deny list' if 'cron.deny' in present else 'no list') }}"
        at_model: "{{ 'allow list' if 'at.allow' in present else ('deny list' if 'at.deny' in present else 'no list') }}"
      ansible.builtin.debug:
        msg: "cron: {{ cron_model }}, at: {{ at_model }}"
```

Die Ausgabe nennt, welche *Dateien* existieren, nicht die wirksame Richtlinie: `no list` heißt „die
Implementierung entscheidet", und genau auf diesen Fall solltest du dich nicht verlassen.

### Weitere Orte, an denen sich Jobs verstecken

Cron ist einer von mehreren Schedulern, und eine Host-Prüfung muss nach den anderen fragen:

- **`at`** führt einen Job einmal aus. Eingereihte Jobs laufen nur, solange der Dienst `atd` läuft:
  Ohne ihn nimmt `at` den Job an und warnt mit `No atd running?` (getestet). Das Paket ist nicht
  immer installiert; `command -v at` zeigt es. `ansible.posix.at` plant aus einem Play.
- **systemd-Timer** starten eine `.service`-Unit nach Zeitplan. Keine cron-Datei und keine Liste
  regelt sie; `systemctl list-timers` zeigt, was aktiv ist (funktioniert auf allen sieben
  systemd-Targets).
- **anacron** führt die täglichen, wöchentlichen und monatlichen Jobs von Hosts aus, die nicht
  immer laufen. Unter Debian treten die drei passenden Zeilen in `/etc/crontab` zurück, wenn
  `/usr/sbin/anacron` existiert.

## CIS-Hintergrund

Abschnitt **2.4** des [Control-Katalogs](../../cis/controls.yml) ist Level 1: Der Scheduler ist
aktiviert und läuft (geplante Wartung und Prüfungen müssen stattfinden), seine Dateien und
Verzeichnisse lassen sich von anderen nicht ändern, und die Nutzung von `crontab` ist auf benannte
Benutzer beschränkt. Die letzten beiden schließen zwei verschiedene Wege für einen Angreifer:
eine Definition *ändern*, der root schon vertraut, und eine unter eigenem Namen *hinzufügen*.
Ältere Benchmarks fassen cron und `at` in einer Empfehlung zusammen; neuere führen sie getrennt.
Der Katalog deckt nur cron ab; `at` und Timer gehören in eine Prüfung, nicht in die Übung.

Die Kosten sind gering - root und ein paar benannte Dienstkonten planen Jobs - und sie fallen im
Deployment an: Jobs einer Anwendung gehören in ein geprüftes Drop-in, nicht in eine
Benutzer-Crontab. Eine Empfehlung kann auch **nicht anwendbar** sein: BusyBox hat keine
Listendatei, die gelesen wird, die Empfehlung lässt sich also nicht wie beschrieben erfüllen. Das
ist eine dokumentierte Ausnahme, keine fehlende Zeile (L01 zu Ausnahmen, 4.01 dazu, wie eine
Prüfung `n/a` meldet).

## Plattformunterschiede

| os_family | Hosts | Implementierung (Paket) | Dienst | Benutzer-Spool | Listendateien bei Auslieferung |
|---|---|---|---|---|---|
| Debian | debian, ubuntu | Debian cron (`cron`) | `cron` | `/var/spool/cron/crontabs` | keine |
| RedHat | rocky, alma, fedora | cronie (`cronie`) | `crond` | `/var/spool/cron` | leere `cron.deny` |
| Suse | opensuse | cronie (`cronie`) | `cron` | `/var/spool/cron` | `cron.deny`, nicht leer |
| Alpine | alpine | BusyBox `crond` | `crond` (OpenRC) | `/etc/crontabs` | keine; keine Listendatei wird gelesen |
| Archlinux | arch | cronie (`cronie`) | `cronie` | `/var/spool/cron` | `cron.deny`, nicht leer |

Debian cron und cronie lesen `/etc/crontab`, `/etc/cron.d` und die periodischen Verzeichnisse;
BusyBox liest nur sein Spool-Verzeichnis (die Binaries von 1.36.1 und 1.37.0 enthalten keinen
Verweis auf `cron.d`, geprüft mit `grep -c -a`). Die Dienstnamen unterscheiden sich auch dort, wo
die Implementierung gleich ist (`cron` unter openSUSE, `cronie` unter Arch); halte sie deshalb in
Daten (L04). Das `crontab` von BusyBox bricht für einen normalen Benutzer mit
`must be suid to work properly` ab, im 1.36.1-Build, den ich getestet habe; unter Alpine habe ich
das nicht verifiziert. Den Inhalt der nicht leeren `cron.deny`-Dateien habe ich mir nicht
angesehen.

### In den Lab-Containern

- Cron läuft in allen acht Targets wirklich, als Teil des Containers; ein dort gestarteter Job
  tut deinem Host nichts (siehe [die Container-Grenzen](../CONTAINER_LIMITS.md)).
- Die systemd-Targets loggen ins Journal (`journalctl -u <Dienst>`); es gibt kein
  `/var/log/cron*`.
- Die Beispiele brauchen Python auf dem Target, also braucht alpine zuerst 0.02 - die zwei
  Beispiele, die Drop-ins schreiben, überspringen es mit `targets:!alpine`.
- Demo-Dateien bleiben, bis du sie entfernst oder den Host zurücksetzt.

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| Das Play ist grün, der Job läuft nie | der Daemon hat die Datei abgelehnt (Eigentümer, Modus, Name) | das Journal lesen (`BAD FILE MODE`, `WRONG FILE OWNER`); Eigentümer root, kein Schreibbit für Gruppe oder andere |
| Ein Drop-in `cron_file: backup.job` wird unter Debian ignoriert | Debian cron überspringt Namen mit Punkt | nur Buchstaben, Ziffern, `-` und `_` |
| Ein cronie-Drop-in wird ignoriert, obwohl nur root es schreiben kann | ein Execute-Bit ist gesetzt (`0700`) | `0644` oder `0600` |
| Nach dem Anlegen von `cron.allow` laufen die Jobs eines Benutzers weiter | die Listen steuern nur den Befehl `crontab` | die Crontab dieses Benutzers entfernen oder den Job in ein geprüftes Drop-in verlegen |
| `You (alice) are not allowed to use this program (crontab)` | eine Allow-Liste existiert und alice steht nicht darauf | sie aufnehmen oder per Drop-in planen |
| Ein Host ohne Listendateien ist auf einer Distribution „offen" und auf einer anderen „zu" | der Standard für Fall 3 gehört der Implementierung | die Absicht mit einer Listendatei ausdrücklich machen |
| Das Umbenennen von `name:` erzeugt einen zweiten Eintrag | das Modul erkennt seinen Eintrag am Namen in der Markierung `#Ansible:` | Namen stabil halten; den alten Namen mit `state: absent` entfernen |
| Eine Datei in `/etc/crontabs` unter Alpine bewirkt nichts | der Eigentümer ist der Benutzer, oder es gibt den Benutzer nicht | im Besitz von root, benannt nach einem existierenden Benutzer |
| `at` nimmt den Job an und nichts passiert | `atd` läuft nicht | den Dienst aktivieren und starten |

## Übungen

| Übung | Wofür diese Lektion vorbereitet |
|---|---|
| [2.05](../../exercises/stage2-building-blocks/2.05-cron-hardening/README.de.md) | was die Daemons lesen und akzeptieren, wie die Listendateien funktionieren und welche Implementierung sie beachtet, warum dieselbe Absicht auf verschiedenen Hosts verschiedene Dateien braucht |

Starte eine Übung mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Warum ist Schreibzugriff auf eine Datei in `/etc/cron.d` so gut wie eine Root-Shell?

   <details><summary>Antwort</summary>

   Der Daemon läuft als root und startet jede Definition unbeaufsichtigt als den Benutzer, der
   darin steht. Eine Zeile mit `root` im Benutzer-Feld läuft in der nächsten passenden Minute als
   root; die Datei zu ändern - oder eine Datei hinzuzufügen, die der Daemon akzeptiert -, heißt
   also, Code als root auszuführen.

   </details>

2. Ein Drop-in hat Modus `0664`; das Play, das es schrieb, war grün, und der Job lief nie. Wo
   schaust du nach, und was änderst du?

   <details><summary>Antwort</summary>

   Der Daemon hat die Datei abgelehnt, weil Gruppenmitglieder sie schreiben dürfen; die Ablehnung
   steht in seinem Log (`journalctl -u <Dienst>`, cronie meldet `BAD FILE MODE`), nicht im Play.
   Setze den Eigentümer auf root und entferne die Schreibbits für Gruppe und andere - `0644` oder
   `0600`.

   </details>

3. Nenne zwei Dinge, die Debian cron ablehnt und cronie akzeptiert, und eines, das cronie ablehnt
   und Debian cron akzeptiert.

   <details><summary>Antwort</summary>

   Debian cron lehnt einen Namen mit Punkt und einen zweiten Hardlink ab; cronie akzeptiert beides.
   cronie lehnt ein Drop-in mit Execute-Bit (`0700`) ab; Debian cron führte es aus. Beide lehnen
   einen Eigentümer außer root und Schreibbits für Gruppe oder andere ab.

   </details>

4. `cron.allow` enthält nur `deploy`. Alice hat eine Crontab mit einem nächtlichen Job. Läuft der
   Job, darf sie ihn mit `crontab -e` bearbeiten, und darf root es?

   <details><summary>Antwort</summary>

   Der Job läuft weiter: Die Listen steuern den Befehl `crontab`, nicht vorhandene Crontabs. Alice
   darf ihn nicht bearbeiten, weil sie nicht auf der Allow-Liste steht. Root darf es - er ist immer
   erlaubt.

   </details>

5. Weder `cron.allow` noch `cron.deny` existiert. Darf ein normaler Benutzer `crontab -e`
   ausführen? Was folgerst du für einen gehärteten Host?

   <details><summary>Antwort</summary>

   Das hängt von der Implementierung ab: Debian cron erlaubt es allen, das cronie-Paket von Debian
   nur root, und Pakete der RPM-Familie liefern eine leere `cron.deny` mit, die alle zulässt. Ein
   gehärteter Host sollte sich nicht auf den Standard verlassen, sondern seine Absicht in einer
   Listendatei festhalten.

   </details>

6. Warum beschränkt eine Datei `cron.allow` unter Alpine niemanden, und welche Frage ersetzt „ist
   die Liste da?"

   <details><summary>Antwort</summary>

   `crond` und `crontab` von BusyBox lesen sie nie - die Binaries enthalten keinen Verweis auf den
   Dateinamen -, also steuert eine Listendatei dort nichts, so zufrieden ein Scanner damit auch
   sein mag. Die nützliche Frage ist, welche Dateien und Verzeichnisse der Daemon *wirklich* liest
   und wer sie ändern darf: die ersten beiden Konzepte dieser Lektion.

   </details>

## Weiterführendes

- [`ansible.builtin.cron`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/cron_module.html) und [`ansible.posix.at`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/at_module.html) - alle Optionen
- [`crontab(1)`](https://man.archlinux.org/man/crontab.1) und [`crontab(5)`](https://man.archlinux.org/man/crontab.5) - die Allow- und Deny-Dateien, das Systemformat mit seinem Benutzer-Feld
- [`at(1)`](https://man.archlinux.org/man/at.1) - `at.allow`, `at.deny` und die Warteschlange
- [`systemd.timer(5)`](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html) - Timer als der andere Scheduler auf systemd-Hosts
