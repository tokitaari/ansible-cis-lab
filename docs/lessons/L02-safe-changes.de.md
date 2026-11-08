# L02 - Sichere Änderungen: Check-Modus, validate, Handler und Bedingungen

*[English](L02-safe-changes.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 1.01, 1.02, 1.03, 1.04, 1.05 | 2.1, 2.2, 5.1, 5.2, 7.1 | ~25 Min. | L00 |

Eine Härtungsänderung, die auf acht Hosts gleichzeitig läuft, kann acht Hosts gleichzeitig
kaputt machen: ein falscher Modus auf einer Systemdatei, ein Tippfehler in einer
Dienstkonfiguration, ein Neustart, der nie stattfindet. Diese Lektion behandelt Änderungen, die du
vorhersagen kannst, bevor du sie machst, prüfen kannst, bevor sie wirken, und rückgängig machen
kannst, wenn sie schiefgehen - die Gewohnheiten, die ein Härtungs-Playbook von einem
Härtungs-Unfall unterscheiden.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] vorhersagen, was `--check --diff` für einen Task meldet, und die Fälle nennen, in denen es das nicht kann
- [ ] entscheiden, welche Tasks im Check-Modus trotzdem laufen müssen und welche Ausgabe nicht in den Diff gehört
- [ ] erklären, was `validate` an einer Datei beweist und was nicht
- [ ] wählen, ob ein Handler am Ende des Plays, sofort oder sogar nach einem Fehler laufen soll
- [ ] eine Bedingung schreiben, die einen Host überspringt, der keine Änderung braucht, statt zu scheitern
- [ ] eine riskante Änderung so ordnen, dass ein Fehler einen Host kostet und nicht alle

## Theorie

### Check-Modus: was er vorhersagen kann und was nicht

L00 hat `--check --diff` eingeführt. Der Mechanismus verdient einen genaueren Blick, weil
Härtungsarbeit von ihm abhängt. Im Check-Modus wird jedes Modul gefragt, was es tun *würde*.
Module wie `file`, `copy`, `template`, `package` und `service` vergleichen den aktuellen Zustand
mit dem gewünschten und antworten, ohne den Host anzufassen. Ein Modul, das seine Wirkung nicht
vorhersagen kann - `command`, `shell`, `raw`, sofern nicht `creates`/`removes` angegeben ist -,
wird **übersprungen**.

Ein übersprungener Task schlägt nicht fehl. Er liefert trotzdem ein registriertes Ergebnis, aber
eines ohne Ausgabe, und das ist die Falle:

```yaml
- name: Read-only probes in check mode
  hosts: targets
  become: true
  tasks:
    - name: Read the kernel release
      ansible.builtin.command: uname -r
      register: kernel
      changed_when: false
    - name: Report it
      ansible.builtin.debug:
        msg: "kernel {{ kernel.stdout }}, dry run: {{ ansible_check_mode }}"
```

Mit `--check` gibt das `kernel , dry run: True` aus: Der erste Task wurde übersprungen, also ist
`kernel.stdout` leer. Nichts ist fehlgeschlagen, die Antwort ist nur falsch. Ein Task, der nur
*liest*, kann gefahrlos echt laufen; das sagst du Ansible mit `check_mode: false` an diesem Task.
`ansible_check_mode` ist die Variable, die einem Task mitteilt, ob der Lauf ein Probelauf ist.

Das Gegenstück, `check_mode: true`, lässt einen einzelnen Task auch in einem normalen Lauf im
Check-Modus laufen - eine billige Art zu fragen "würde das etwas ändern?", ohne zu handeln.

`--diff` zeigt den Unterschied, den ein Modul berechnet: Dateiinhalt, Rechte, Zustand. Eine Datei
mit einem Geheimnis darf dort nicht erscheinen, denn der Diff geht ins Terminal, in CI-Logs und in
Chats. Schalte ihn pro Task ab:

```yaml
- name: Hide file contents from the diff
  hosts: targets
  become: true
  tasks:
    - name: Token file is in place
      ansible.builtin.copy:
        dest: /etc/lab-token
        content: "s3cret\n"
        mode: "0600"
      diff: false
```

Grenzen, die du im Kopf behalten solltest: Der Check-Modus sagt jeden Task einzeln voraus. Hängt
ein späterer Task vom *Ergebnis* eines früheren ab (eine Datei, die der frühere Task angelegt
hätte, ein Paket, das er installiert hätte), kann der Probelauf einen Fehler oder ein "changed"
zeigen, das der echte Lauf nicht erzeugt. Ein sauberes `--check` ist ein starkes Indiz, kein
Beweis; der Beweis ist der echte Lauf, gefolgt von einem zweiten Lauf mit `changed=0`.

```bash
ansible-playbook change.yml --check --diff          # was würde sich wie ändern?
ansible-playbook change.yml --check --diff -l debian   # dasselbe für einen Host
```

### `validate`: die Datei testen, bevor sie existiert

Manche Dateien sind gefährlich, weil das Programm, das sie liest, bei einem Fehler nicht mehr
startet: eine Daemon-Konfiguration, eine sudo-Regel, eine PAM-Datei. Installiert deine Änderung
eine kaputte Datei und startet ein Handler den Daemon neu, steht der Dienst - und wenn der Dienst
dein Weg auf den Host ist, stehst du ebenfalls.

Die Module, die Dateien schreiben (`copy`, `template`, `lineinfile`, `blockinfile`), kennen
`validate`. Ansible schreibt den neuen Inhalt in eine **temporäre Datei**, führt deinen Befehl
mit dem Pfad dieser Datei anstelle von `%s` aus und installiert die Datei nur, wenn der Befehl
mit 0 endet:

```yaml
- name: Install a script only if it parses
  hosts: targets
  become: true
  tasks:
    - name: Helper script is valid shell
      ansible.builtin.copy:
        dest: /etc/lab-helper.sh
        content: |
          #!/bin/sh
          echo "hello"
        owner: root
        group: root
        mode: "0755"
        validate: /bin/sh -n %s
```

`sh -n` liest ein Skript und meldet Syntaxfehler, ohne es auszuführen. Baust du einen Fehler ein
(ein `if` ohne `fi`), scheitert der Task mit `failed to validate` und der Meldung der Shell; die
Datei auf dem Host bleibt unberührt. Lässt du `%s` weg, verweigert das Modul die Arbeit ganz.

Was `validate` beweist, ist wenig: **Die neue Datei ist für den Prüfer syntaktisch akzeptabel,
für sich allein gelesen.** Es beweist nicht, dass die Datei sich gegen andere Dateien durchsetzt,
die dasselbe Programm konfigurieren, dass die Einstellung tut, was du meinst, oder dass der Dienst
nach einem Neustart läuft. Konfiguration, die aus mehreren Dateien zusammengesetzt wird und bei
der Regeln bestimmen, welche Einstellung zählt, braucht eine zweite Prüfung des *wirksamen*
Ergebnisses - die meisten Daemons können es ausgeben. Viele Programme haben genau dafür einen
Testmodus; den passenden Aufruf zu finden, gehört zu den Übungen.

Der Prüfer läuft auf dem Target als `become`-Benutzer, ohne Shell: keine Pipes, kein `&&`, keine
Variablenexpansion in der Befehlszeile selbst. Brauchst du das, packe es in ein kleines Skript
und validiere mit dem Skript.

### Handler: nur handeln, wenn sich etwas geändert hat

Einen Dienst bei jedem Lauf neu zu starten ist laut und manchmal schädlich - Verbindungen brechen
ohne Grund ab. Ein **Handler** ist ein Task, der nur läuft, wenn ein Task `changed` gemeldet und
ihn mit `notify` genannt hat:

```yaml
- name: Handlers run once, at the end of the play
  hosts: targets
  become: true
  tasks:
    - name: First setting changes
      ansible.builtin.copy:
        dest: /etc/lab-a.conf
        content: "a=1\n"
        mode: "0644"
      notify: Announce change
    - name: Second setting changes
      ansible.builtin.copy:
        dest: /etc/lab-b.conf
        content: "b=1\n"
        mode: "0644"
      notify: Announce change
    - name: Run pending handlers now
      ansible.builtin.meta: flush_handlers
    - name: Runs after the handler
      ansible.builtin.debug:
        msg: "handlers are done"
  handlers:
    - name: Announce change
      ansible.builtin.debug:
        msg: "a config file changed"
```

Beide Tasks benachrichtigen denselben Handler, und er läuft **einmal**. Ohne die Zeile
`flush_handlers` liefe er nach dem letzten Task des Plays, nicht mittendrin. Das zählt immer dann,
wenn ein späterer Task von der Wirkung des Handlers abhängt: Eine Prüfung, die sich mit dem
neu gestarteten Dienst verbindet, muss nach dem Flush kommen, nicht davor. Beim zweiten Lauf ändert
sich nichts, der Handler läuft also gar nicht.

Drei Eigenschaften verursachen die meisten Überraschungen:

- **Handler-Namen sind global** im Play und werden über den exakten Text gefunden. Ein Tippfehler
  in `notify` lässt den Lauf mit "handler not found" scheitern. Mit `listen: <Thema>` im Handler
  benachrichtigen Tasks das Thema statt des Namens, und mehrere Handler können es teilen.
- **Ein fehlgeschlagener Task überspringt die Handler.** Die bereits gemachte Änderung bleibt auf
  dem Host, und der *nächste* Lauf meldet sie als `ok` - der Handler, der folgen sollte, läuft also
  nie. Der Dienst läuft mit der alten Konfiguration weiter, bis es jemand merkt. `force_handlers:
  true` am Play führt die benachrichtigten Handler auch nach einem Fehler aus.
- **Handler laufen auch im Check-Modus**, und ihre Module werden wieder nur gefragt, was sie tun
  würden. Ein Probelauf zeigt daher, wo ein Neustart stattfinden *würde*.

```yaml
- name: Handlers after a failed task
  hosts: targets
  become: true
  force_handlers: true
  tasks:
    - name: Setting changes
      ansible.builtin.copy:
        dest: /etc/lab-a.conf
        content: "a=2\n"
        mode: "0644"
      notify: config changed
    - name: A later task fails
      ansible.builtin.command: "false"
      changed_when: false
  handlers:
    - name: Announce change
      listen: config changed
      ansible.builtin.debug:
        msg: "handler ran despite the failure"
```

`restarted` und `reloaded` sind unterschiedliche Versprechen: Ein Reload bittet den laufenden
Prozess, seine Konfiguration neu zu lesen, ein Restart beendet ihn und startet einen neuen. Was
richtig ist, hängt davon ab, was der Daemon unterstützt und was eine Unterbrechung kostet; die
Übungen lassen dich das entscheiden.

### Bedingungen: überspringen, was nicht zutrifft

Ein Play für `targets` läuft auf acht verschiedenen Systemen. Ein Task für einen Dienst, den nur
manche Hosts haben, darf auf den anderen nicht scheitern: "nicht installiert" ist ein normales
Ergebnis, kein Fehler. `when` nimmt einen Jinja2-Ausdruck, geschrieben **ohne** `{{ }}`, und
überspringt den Task, wenn er falsch ist.

Zwei Wege zu wissen, was installiert ist. `package_facts` sammelt die installierten Pakete in
`ansible_facts.packages`, einem Dictionary mit dem Paketnamen als Schlüssel:

```yaml
- name: Act only where the package exists
  hosts: targets
  become: true
  tasks:
    - name: Collect installed packages
      ansible.builtin.package_facts:
        manager: auto
    - name: Report the sudo version
      ansible.builtin.debug:
        msg: "sudo {{ ansible_facts.packages['sudo'][0].version }}"
      when: "'sudo' in ansible_facts.packages"
    - name: Report a package nobody installs
      ansible.builtin.debug:
        msg: "found it"
      when: "'lab-no-such-package' in ansible_facts.packages"
```

Der zweite Task wird auf jedem Host übersprungen. Setze hier das ganze `when` in
Anführungszeichen: Ein einfacher Skalar, der `': '` enthält oder mit einem Anführungszeichen
beginnt, verwirrt den YAML-Parser. Für eine Datei oder ein Verzeichnis ist `stat` mit `register`
und `when: result.stat.exists` das Gegenstück.

Das andere Werkzeug ist, einen Befehl nach seinem Ergebnis zu beurteilen. Ein Befehl, der "nichts
gefunden" mit Exit-Code 1 und einen echten Fehler mit Exit-Code 2 meldet, ist im ersten Fall kein
Fehlschlag:

```yaml
- name: Judge a command by its exit code
  hosts: targets
  become: true
  tasks:
    - name: Look for a marker in a file
      ansible.builtin.command: grep -q marker /etc/hostname
      register: probe
      changed_when: false
      failed_when: probe.rc > 1
    - name: React to the result
      ansible.builtin.debug:
        msg: "marker present: {{ probe.rc == 0 }}"
```

`failed_when` ersetzt Ansibles eigene Vorstellung von Fehlschlag (Exit-Code ungleich 0) durch
deine, und `changed_when` tut dasselbe für `changed`. Vergleiche das mit `ignore_errors: true`,
das das Play nach *jedem* Fehler weiterlaufen lässt, auch nach denen, die du nicht erwartet hast.
Bevorzuge eine genaue Bedingung gegenüber pauschalem Schweigen; ein Härtungs-Playbook, das Fehler
ignoriert, meldet Konformität, die es nicht gibt.

### Ein Weg zurück: das Risiko ordnen

Auch mit `validate` und einem guten Handler lassen sich manche Änderungen nur am echten System
beurteilen. Der billige Schutz ist, den Wirkungsradius schrittweise zu erweitern:

```bash
ansible-playbook change.yml --check --diff -l debian   # einen Host ansehen
ansible-playbook change.yml -l debian                  # einen Host ändern
ansible targets -m ansible.builtin.ping                # erreichen wir noch alle?
ansible-playbook change.yml --step -l ubuntu           # vor jedem Task nachfragen
ansible-playbook change.yml                            # alle
```

`--step` fragt vor jedem Task nach - langsam, aber richtig für eine Änderung, der du noch nicht
traust. Halte während der Arbeit eine zweite Verbindung zu einem Testhost offen, damit dir bei
einem Aussperren eine offene Sitzung bleibt. Lektion L14 behandelt die geplante Fassung dieser
Idee (`serial`, Canary-Hosts).

Für eine Änderung mit klarem Erfolgstest behält `backup: true` bei `copy`/`template` die vorherige
Datei, und `block`/`rescue` führt Wiederherstellungs-Tasks aus, wenn im Block etwas scheitert:

```yaml
- name: Change with a way back
  hosts: targets
  become: true
  tasks:
    - name: Apply the setting, restore the old file if the check fails
      block:
        - name: Install new settings
          ansible.builtin.copy:
            dest: /etc/lab-settings.conf
            content: "mode=relaxed\n"
            mode: "0644"
            backup: true
          register: new_settings
        - name: Verify the setting
          ansible.builtin.command: grep -qx 'mode=strict' /etc/lab-settings.conf
          changed_when: false
      rescue:
        - name: Put the previous file back
          ansible.builtin.copy:
            src: "{{ new_settings.backup_file }}"
            dest: /etc/lab-settings.conf
            remote_src: true
            mode: "0644"
          when: new_settings.backup_file is defined
        - name: Stop and say why
          ansible.builtin.fail:
            msg: "verification failed on {{ inventory_hostname }}"
```

Die Prüfung scheitert hier absichtlich (die Datei sagt `relaxed`), also stellt `rescue` die alte
Datei wieder her, wo es eine gab, und lässt den Host dann sichtbar scheitern. `backup_file`
existiert nur, wenn es eine vorherige Datei zu sichern gab - daher das `when`. Der
`rescue`-Abschnitt ist kein Freibrief für Nachlässigkeit: Er deckt die Fehler ab, an die du
gedacht hast.

## CIS-Hintergrund

Dienste und Clients sind Angriffsfläche, und die Empfehlungen in den Abschnitten 2.1 (Server-
Dienste) und 2.2 (Client-Dienste) lauten meist "entfernen, oder mindestens stoppen und
deaktivieren". Diese Änderungen sind pro Host risikoarm, aber die *Bedingung* zählt: Dasselbe Play
trifft Hosts mit dem Paket und Hosts ohne (Controls 2.1 und 2.2 im
[Control-Katalog](../../cis/controls.yml)).

Die Abschnitte 5.1 (SSH-Server) und 5.2 (Rechteausweitung) sind die Controls, die dich aussperren
können: Beide konfigurieren die Programme, über die du den Host verwaltest. Sie sind Level 1 und
gehören überall angewendet, die Schutzmaßnahmen dieser Lektion sind für sie also nicht optional.
Abschnitt 7.1 (Rechte von Systemdateien) ist billig zu beheben und leicht falsch zu machen - ein
zu strenger Modus kann einen Dienst genauso zerstören wie ein zu lockerer.

In der Produktion ist es ein Abwägen zwischen Tempo und Gewissheit. `--check --diff` zuerst, im
Wartungsfenster, auf einem Host, kostet Minuten; ein Aussperren kostet den Weg zur Konsole.

## Plattformunterschiede

| os_family | Hosts | sshd-Dienstname | Init-System | `package_facts`-Backend |
|---|---|---|---|---|
| Debian | debian, ubuntu | `ssh` | systemd | apt |
| RedHat | rocky, alma, fedora | `sshd` | systemd | rpm |
| Suse | opensuse | `sshd` | systemd | rpm |
| Alpine | alpine | `sshd` | openrc | apk |
| Archlinux | arch | `sshd` | systemd | pacman |

`ansible.builtin.service` verbirgt das Init-System, aber nicht den Dienst-*Namen*: Derselbe Daemon
heißt je nach Familie anders, deshalb braucht ein Handler, der ihn neu startet, pro Host den
richtigen Namen. Namen als Daten zu behandeln ist das Thema von L04.

### In den Lab-Containern

- `package_facts` mit `manager: auto` braucht auf dem Target die passenden Python-Bindings (für
  apt und rpm). Die Lab-Images bringen sie mit; Alpine nutzt den Befehl `apk` und braucht nur das
  Python, das Übung 0.02 installiert.
- Die Dienste laufen unter einem echten Init-System (systemd, OpenRC), also verhalten sich
  `service` und Handler wie auf einer VM. Hosts ohne das Paket oder den Dienst haben die Unit
  schlicht nicht: Dafür sind die Bedingungen da.
- `lab check` führt dein Playbook zweimal aus und erwartet beim zweiten Mal `changed=0`; ein
  Handler, der beim zweiten Lauf läuft, verweist auf einen Task, der nicht idempotent ist.

## Stolperfallen

| Symptom | Ursache | Abhilfe |
|---|---|---|
| Ein Wert ist in einem `--check`-Lauf leer, nichts ist fehlgeschlagen | der Task, der ihn erzeugt, ist `command`/`shell` und wird im Check-Modus übersprungen | `check_mode: false` an lesenden Tasks |
| `validate must contain %s` | dem Befehl fehlt der Platzhalter `%s` | `%s` dorthin setzen, wo der Dateipfad hingehört |
| `validate` besteht, aber das Programm verhält sich trotzdem falsch | `validate` prüft die Datei allein, nicht die wirksame Konfiguration | das wirksame Ergebnis nach der Änderung prüfen |
| Der Dienst hat die neue Konfiguration nie übernommen | ein späterer Task ist gescheitert, der Handler wurde übersprungen, der nächste Lauf meldet `ok` | `force_handlers: true`, oder riskante Tasks hinter den Handler-Flush legen |
| Eine Prüfung direkt nach der Änderung läuft gegen den alten Dienst | der Handler ist noch nicht gelaufen, er wartet auf das Ende des Plays | `ansible.builtin.meta: flush_handlers` vor der Prüfung |
| "The requested handler was not found" | der `notify`-Text weicht vom Handler-`name` ab | den exakten Namen kopieren oder `listen` mit einem Thema nutzen |
| Ein `when` mit `{{ var }}` löst eine Deprecation-Warnung aus | `when` ist bereits ein Jinja2-Ausdruck | `when: var` schreiben, ohne Klammern |
| `ansible_facts.packages` ist nicht definiert | `package_facts` ist für diesen Host in diesem Play nicht gelaufen | `package_facts` zuerst ausführen, im selben Play oder davor |
| Ein echter Fehler taucht in der Zusammenfassung nie auf | `ignore_errors: true` schluckt ihn | `failed_when` mit den Exit-Codes, die akzeptabel sind |
| Der Diff zeigt ein Passwort | `--diff` gibt Dateiinhalt aus | `diff: false` an diesem Task |

## Übungen

| Übung | Was diese Lektion dafür vorbereitet |
|---|---|
| [1.01](../../exercises/stage1-beginner/1.01-remove-telnet/README.de.md) | was `--check --diff` für ein Paket zeigt, das es vielleicht nicht gibt; übersprungen versus fehlgeschlagen |
| [1.02](../../exercises/stage1-beginner/1.02-passwd-group-permissions/README.de.md) | einen Rechte-Diff in `--check --diff` lesen; prüfen, ob eine Datei existiert (`stat` und `when`); die Modi selbst folgen in [L03](L03-base-hardening.de.md) |
| [1.03](../../exercises/stage1-beginner/1.03-ssh-root-login/README.de.md) | `validate`, `notify` und Handler, die Grenzen von `validate`, eine Änderung, die dich aussperren kann |
| [1.04](../../exercises/stage1-beginner/1.04-disable-ftp-server/README.de.md) | `package_facts` mit `when`, ein Task für systemd und OpenRC, übersprungene Hosts |
| [1.05](../../exercises/stage1-beginner/1.05-sudo-hardening/README.de.md) | `validate` als Schutz vor dem Aussperren, eine riskante Änderung ordnen |

Eine Übung startest du mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Ein `--check`-Lauf deines Playbooks zeigt `changed=0` auf einem Host, der nicht konform ist.
   Nenne zwei mögliche Gründe.

   <details><summary>Antwort</summary>

   Ein Task, der die Änderung machen würde, wird im Check-Modus übersprungen
   (`command`/`shell`/`raw` ohne `creates` oder `removes`), oder ein späterer Task hängt vom
   Ergebnis eines früheren ab, das nur vorhergesagt wurde, sodass der Probelauf den Unterschied
   nicht sieht. Eine dritte Möglichkeit ist ein `when`, das einen registrierten Wert aus einem
   übersprungenen Task liest. Ein sauberer Check ist ein Indiz; der Test ist der zweite echte
   Lauf mit `changed=0`.

   </details>

2. `validate` ist für deine neue Daemon-Konfiguration erfolgreich, du startest den Daemon über
   einen Handler neu, und der Dienst kommt nicht zurück. Wie ist das möglich?

   <details><summary>Antwort</summary>

   `validate` testet die temporäre Datei für sich: Syntax und Werte, die der Prüfer akzeptiert.
   Es kann nicht wissen, dass eine andere Datei die Einstellung überschreibt, dass ein Wert gültig,
   aber für dieses System falsch ist (ein belegter Port, ein nicht vorhandener Pfad) oder dass der
   laufende Dienst von den Annahmen des Prüfers abweicht. Prüfe nach der Änderung die wirksame
   Konfiguration und den Dienst selbst, und halte einen Weg zurück bereit.

   </details>

3. Zwei Tasks benachrichtigen denselben Handler. Task 2 scheitert. Was passiert mit dem Handler,
   und was meldet der nächste Lauf?

   <details><summary>Antwort</summary>

   Ohne `force_handlers` läuft der Handler nicht, weil das Play stehen geblieben ist. Die Änderung
   von Task 1 ist bereits auf dem Host, also meldet der nächste Lauf sie als `ok`, es gibt keine
   Benachrichtigung, und der Handler läuft für diese Änderung nie. Mit `force_handlers: true`
   läuft er nach dem Fehler.

   </details>

4. Wann brauchst du `meta: flush_handlers`, statt auf das Ende des Plays zu warten?

   <details><summary>Antwort</summary>

   Immer wenn ein späterer Task im selben Play von der Wirkung des Handlers abhängt: ein
   Verbindungstest gegen den neu gestarteten Dienst, eine Prüfung der laufenden Konfiguration oder
   ein Task, der nicht gegen den alten Dienst laufen darf. Ohne den Flush läuft der Handler nach
   dem letzten Task, zu spät für diese Fälle.

   </details>

5. Ein Play für `targets` entfernt einen Dienst, scheitert aber auf zwei Hosts mit "Could not
   find the requested service". Was ist falsch, und was prüfst du vor dem Task?

   <details><summary>Antwort</summary>

   Das Service-Modul findet auf Hosts, auf denen das Paket nicht installiert ist, keine Unit, und
   das wird als Fehler gemeldet. Die Bedingung gehört an den Task: `package_facts` ausführen und
   `when` auf den Paketnamen anwenden, damit Hosts ohne das Paket übersprungen werden. "Nicht
   installiert" ist ein normaler Zustand, kein Fehler.

   </details>

6. Du musst eine riskante Änderung auf acht Hosts anwenden und kannst sie nirgends vorher testen.
   Welche Reihenfolge begrenzt den Schaden?

   <details><summary>Antwort</summary>

   `--check --diff` auf einem Host, die echte Änderung auf diesem Host, ein Erreichbarkeitstest der
   ganzen Gruppe, dann die nächsten Hosts oder der Rest. `--step` und `backup: true` mit
   `block`/`rescue` helfen bei einer Änderung, der du weniger traust, und eine zweite offene
   Sitzung bewahrt dich vor dem Aussperren. Geplante Rollouts mit `serial` und Canary-Hosts folgen
   in L14.

   </details>

## Weiterführendes

- [Validating tasks: check mode and diff mode](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html)
- [Handlers: running operations on change](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html)
- [Conditionals](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_conditionals.html)
- [Blocks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html) und [Error handling in playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_error_handling.html)
- [Modul `ansible.builtin.copy`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html) - `validate` und `backup`
- [Modul `ansible.builtin.package_facts`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/package_facts_module.html)
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: `block` / `rescue` / `always`,
  check mode, diff mode, handler, `register`, `validate`, `when`
