# L10 - Compliance-Berichte: Audit-Modus, Enforce-Modus und Custom Facts

*[English](L10-compliance-reporting.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 4.01, 4.05, 5.01 | 1.1.1, 1.5, 1.6, 2.1, 2.2, 2.4, 3.3, 5.1, 5.2, 5.3.3, 5.4.1, 5.4.2, 5.4.3, 6.3, 7.1 | ~30 Min. | L02, L04, L07, L09 |

Eine Härtungsrolle, die Hosts nur ändern kann, ist ein halbes Werkzeug. Vor dem Änderungsfenster
fragt jemand, was sich ändern würde, danach, was jetzt in Ordnung ist, und bei hundert Hosts muss
die Antwort eine Datei sein, die auch lesen kann, wer das Playbook nie gesehen hat. Diese Lektion
behandelt diese zweite Aufgabe: denselben Code laufen lassen, um nachzusehen statt zu ändern,
das Gefundene zu Daten machen, die Daten in einen Bericht schreiben und einen Host sich mit
Custom Facts selbst beschreiben lassen.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] erklären, warum Remediation-Code als Audit-Code dienen kann und welche Ergebnisse „unbekannt“ bedeuten
- [ ] einen Block per Variable zwischen Audit und Enforce umschalten, ohne `--check` zu verlieren
- [ ] die Seiteneffekte nennen, die den Check-Modus ignorieren: Handler, Hintergrund-Tasks, Fact-Skripte
- [ ] ein Kontrollergebnis als ok, Abweichung oder nicht anwendbar modellieren und sagen, wodurch ein Score geteilt wird
- [ ] Ergebnisse pro Host auf dem Control Node sammeln und die Hosts ohne Ergebnis melden
- [ ] einen Bericht schreiben, der beim zweiten Lauf identisch ist, und sagen, was ein Zeitstempel kostet
- [ ] zwischen statischem und ausführbarem Fact wählen und sagen, wann und mit wessen Rechten jeder läuft
- [ ] vorhersagen, was `ansible_local` vor und nach einem erneuten Sammeln enthält, auch unter `--check`

## Theorie

### Ein Codepfad für Audit und Enforce

Eine Härtungsrolle läuft in zwei Situationen. Im Änderungsfenster muss sie Hosts ändern. Davor,
und danach nach einem Zeitplan, fragt jemand nur: „Was ist nicht in Ordnung?“ - ein Auditor, ein
Scheduler, ein Change-Manager, der den Wirkungsradius wissen will. Die naheliegende Antwort sind
zwei Codebasen: eine Rolle, die behebt, und ein Skript, das prüft. Sie laufen auseinander. Das
Skript prüft, was sein Autor für das Verhalten der Rolle hält, jede Regel steht doppelt, und ein
Fehler im einen zeigt sich nie im anderen.

Die Alternative nutzt etwas, das jedes idempotente Modul schon hat. Um `changed` zu melden,
vergleicht ein Modul den aktuellen Zustand mit dem gewünschten; im Check-Modus (L02) hört es nach
dem Vergleich auf. Ein Task, der etwas ändern *würde*, ist also eine Abweichung, und der
Remediation-Code ist der Audit-Code. Die Ergebnisse zu lesen braucht eine Regel pro Art von Task:

| Task im Check-Modus | Was das Ergebnis sagt | Lies es als |
|---|---|---|
| `copy`, `file`, `template`, `lineinfile`, `package`, `service` | `changed` ist true oder false | entschieden: Abweichung oder in Ordnung |
| `command`, `shell`, `raw` ohne `creates`/`removes` | übersprungen, `changed: false` | **unbekannt** - nichts wurde geprüft |
| `command` mit `creates` oder `removes` | `changed` true (mit einer Meldung, dass es gelaufen wäre) oder false | entschieden |
| `stat`, `slurp`, `package_facts`, ein `command` mit `check_mode: false` | das echte Ergebnis | auszuwertende Daten |

Die zweite Zeile ist die Falle. Zählt ein Audit nur `changed`, sieht ein Host, dessen einzige
Kontrolle ein übersprungenes `command` ist, perfekt aus. Audit-fähiger Code nutzt Module, die
entscheiden können, oder liest mit `check_mode: false` (L02) und vergleicht den Wert selbst.

Das Play unten hat zwei Kontrollen, eine Einstellungsdatei mit Inhalt und Modus und eine
Hinweisdatei, und eine Variable. Das `check_mode:` des Blocks ist ein Template. Lass es dreimal
laufen: Audit (der Default), Enforce, wieder Audit.

```yaml
- name: One code path for audit and enforce
  hosts: targets
  gather_facts: false
  vars:
    lesson10_mode: audit
  handlers:
    - name: Mark that the demo service was reloaded
      ansible.builtin.copy:
        dest: /tmp/lesson10/reloaded
        content: "reloaded\n"
        mode: "0644"
      # ein Handler hat keinen eigenen Check-Modus: mit dem Modus absichern
      when: lesson10_mode == 'enforce'
  tasks:
    - name: Make sure the demo directory exists
      ansible.builtin.file:
        path: /tmp/lesson10
        state: directory
        mode: "0755"
      # Vorbereitung der Demo, keine Kontrolle
      check_mode: false

    - name: Controls of the demo baseline
      # Trockenlauf beim Audit und immer dann, wenn --check angegeben ist
      check_mode: "{{ ansible_check_mode or lesson10_mode == 'audit' }}"
      block:
        - name: Demo settings file has the wanted content and mode
          ansible.builtin.copy:
            dest: /tmp/lesson10/demo.conf
            content: "max_retries 3\n"
            mode: "0600"
          register: lesson10_conf
          notify: Mark that the demo service was reloaded

        - name: Demo notice file has the wanted content and mode
          ansible.builtin.copy:
            dest: /tmp/lesson10/notice.txt
            content: "authorised use only\n"
            mode: "0644"
          register: lesson10_notice

    - name: Say what was found
      ansible.builtin.debug:
        msg: >-
          {{ lesson10_mode }}: {{ [lesson10_conf, lesson10_notice] | selectattr('changed') | list | length }}
          of 2 controls not met
```

```bash
ansible-playbook baseline.yml                              # Audit: 2 of 2 controls not met
ansible-playbook baseline.yml -e lesson10_mode=enforce     # beheben
ansible-playbook baseline.yml                              # Audit: 0 of 2 controls not met
```

Das erste Audit hinterlässt auf dem Host nur das Demo-Verzeichnis: kein `demo.conf`, kein
`notice.txt`, kein `reloaded`. Seine Zusammenfassung zählt die zwei nicht erfüllten Kontrollen als
`changed` (beim allerersten Lauf kommt das Verzeichnis dazu). Nach dem Enforce-Lauf findet das
Audit nichts, und ein zweiter Enforce-Lauf ist `changed=0`. Diese Abfolge - messen, ändern,
beweisen - ist der Weg, eine Baseline in Produktion einzuführen.

Warum `ansible_check_mode or ...`? Mit dem einfacheren Keyword `"{{ lesson10_mode == 'audit' }}"`
ist der Block beim Audit ein Trockenlauf - und beim Enforce `false`. `false` heißt nicht „keine
Meinung“: es überschreibt `--check`. In einem Test schrieb `-e lesson10_mode=enforce --check` mit
diesem Keyword beide Dateien wirklich. Das `or` lässt den Trockenlauf von der Kommandozeile
maßgeblich bleiben.

**Was der Check-Modus nicht aufhält.** Vier Dinge in einem geprüften Block wirken trotzdem oder
antworten falsch:

- **Handler.** Ein Handler hat kein eigenes Keyword. Von einem Block mit `check_mode:` benachrichtigt,
  lief er in einem Test wirklich und schrieb seine Datei, obwohl der benachrichtigende Task nur
  geprüft wurde. Sichere ihn mit der Modus-Variable ab, wie oben (L02: bei einem globalen `--check`
  werden Handler mitgeprüft; ein Keyword an Tasks erreicht sie nicht).
- **Hintergrund-Tasks.** `async` mit `poll: 0` (L09) meldet im Check-Modus `changed` und `started`,
  und der Job hat in einem Test trotzdem nichts angelegt. Er zählte bei jedem Audit als Abweichung;
  entscheide stattdessen in einem Vordergrund-Task.
- **Das Flag.** `ansible_check_mode` ist das *Kommandozeilen*-Flag. Im geprüften Block blieb es in
  einem Test `False`, also schützt `when: not ansible_check_mode` dort keinen Task. Teste die
  Modus-Variable.
- **Dynamische Includes.** Eine Rolle führt ihre Kontrollen meist über Includes aus (L07).
  `include_tasks` wird zur Laufzeit ausgewertet und akzeptiert das Keyword gar nicht:
  `'check_mode' is not a valid attribute for a TaskInclude`. Was die eingebundenen Tasks erreicht
  (alles getestet): ein statisches `import_tasks`, ein umgebender Block und `apply:` am Include,
  das Keywords an die eingebundenen Tasks weitergibt (L07 nutzte es für Tags). Welches zu einer
  Schleife über viele Kontrollen passt und was das Include danach festhalten muss, ist eine
  Entwurfsentscheidung von 5.01.

### Befunde sind Daten, keine Fehler

Ein fehlgeschlagener Task ist der falsche Weg, eine Abweichung zu melden. `assert` stoppt einen
Host beim ersten Fehlgriff (getestet), ein Host mit fünf Abweichungen zeigt also eine, und die
Zusammenfassung sagt „failed“ zu etwas, das ein Befund ist - das macht echte Fehler (nicht
erreichbarer Host, kaputtes Modul) schwerer sichtbar. `ignore_errors` hält den Lauf am Laufen,
versteckt aber, welche Fehler erwartet waren. Werte stattdessen aus: Zustand mit lesenden Tasks
erfassen, das Ergebnis als Wert berechnen, die Werte in einer Liste sammeln.

Eine Kontrolle hat drei Ergebnisse:

| Status | Bedeutung | Im Score |
|---|---|---|
| `ok` | gilt, erfüllt | als erfüllt gezählt |
| `deviation` | gilt, nicht erfüllt | als nicht erfüllt gezählt |
| `not_applicable` | die Kontrolle gibt es auf dieser Plattform nicht | nicht gezählt |

Werkzeuge verwenden Wörter wie pass, fail und not applicable; die Demo hat eigene. `not_applicable`
getrennt zu halten ist wichtig, weil die Alternativen verzerren: als ok gezählt bläht es den
Score auf, als Abweichung gezählt bestraft es die Plattform. Ein Score ist `ok` geteilt durch die
Kontrollen, die gelten. Eine echte Liste braucht einen vierten Wert für eine Kontrolle, die nicht
ausgewertet werden konnte (eine Eingabe war nicht lesbar) - nie `ok`; die Demo hat keinen.

```yaml
- name: Evaluate the demo controls without ever failing
  hosts: targets
  gather_facts: true
  tasks:
    - name: Stat the demo settings file
      ansible.builtin.stat:
        path: /tmp/lesson10/demo.conf
      register: lesson10_st

    - name: Stat the systemd unit directory
      ansible.builtin.stat:
        path: /etc/systemd/system
      register: lesson10_units

    - name: Read the demo settings file
      ansible.builtin.slurp:
        src: /tmp/lesson10/demo.conf
      register: lesson10_body
      # eine fehlende Datei ist eine Antwort, kein Fehler
      failed_when: false

    - name: Evaluate the controls
      vars:
        lesson10_text: "{{ lesson10_body.content | default('') | b64decode }}"
      ansible.builtin.set_fact:
        lesson10_results:
          - id: demo-mode
            title: Settings file is mode 0600
            status: "{{ 'ok' if lesson10_st.stat.exists and lesson10_st.stat.mode == '0600' else 'deviation' }}"
          - id: demo-retries
            title: Settings file allows at most 3 retries
            status: "{{ 'ok' if lesson10_text is search('(?m)^max_retries\\s+[0-3]$') else 'deviation' }}"
          - id: demo-units
            title: Unit directory exists (systemd hosts only)
            status: >-
              {{ 'not_applicable' if ansible_facts.service_mgr != 'systemd'
                 else 'ok' if lesson10_units.stat.isdir | default(false)
                 else 'deviation' }}

    - name: Show the results
      ansible.builtin.debug:
        var: lesson10_results
```

Lass es nach dem Enforce-Lauf von oben laufen: zwei `ok` und ein `not_applicable` auf dem
Alpine-Target (OpenRC, der Fact `service_mgr` ist dort `openrc`), drei `ok` auf den anderen.
Lösche `/tmp/lesson10/demo.conf` und lass es noch einmal laufen: das `slurp` schlägt still fehl (in
einem Test fehlte dann sein `content`, daher das `default`), und beide Dateikontrollen werden zu
`deviation`. Nichts brach ab. Die Anwendbarkeit kommt aus einem Fact, nicht aus Hostnamen (L04).

### Von den Ergebnissen pro Host zu einem Bericht

Die Ergebnisse liegen in Variablen jedes Hosts. Ein Play auf `localhost` liest sie über `hostvars`
(L00) und schleift über `groups['targets']`. Variablen aus einem früheren Play sind im späteren
Play desselben Laufs noch da (getestet). Ein Host, der ausfiel, nicht erreichbar war oder per `-l`
ausgelassen wurde, hat diese Variable nicht, und ein ungeschütztes Lesen stoppt das Berichts-Play
mit `object of type 'HostVarsVars' has no attribute '...'` (der Wortlaut stammt aus ansible-core
2.21). Schütze das Lesen - und überspringe solche Hosts nicht einfach: ein Bericht, der einen Host
stillschweigend auslässt, liest sich wie „alles in Ordnung“. Führe sie als *no data* auf.

```yaml
- name: Write the report on the control node
  hosts: localhost
  gather_facts: false
  vars:
    lesson10_done: >-
      {{ groups['targets'] | map('extract', hostvars) | selectattr('lesson10_results', 'defined')
         | map(attribute='inventory_hostname') | sort }}
    lesson10_missing: "{{ groups['targets'] | difference(lesson10_done) | sort }}"
    lesson10_report:
      hosts: "{{ dict(lesson10_done | zip(lesson10_done | map('extract', hostvars, 'lesson10_results'))) }}"
      no_data: "{{ lesson10_missing }}"
  tasks:
    - name: Make sure the report directory exists
      ansible.builtin.file:
        path: /tmp/lesson10/reports
        state: directory
        mode: "0755"

    - name: Write the JSON report
      ansible.builtin.copy:
        dest: /tmp/lesson10/reports/demo.json
        content: "{{ lesson10_report | to_nice_json }}\n"
        mode: "0644"

    - name: Write the Markdown report
      ansible.builtin.copy:
        dest: /tmp/lesson10/reports/demo.md
        content: |
          | Host | ok | deviation | not applicable |
          |---|---|---|---|
          {% for h, res in lesson10_report.hosts.items() %}
          {% set ok = res | selectattr('status', 'equalto', 'ok') | list | length %}
          {% set bad = res | selectattr('status', 'equalto', 'deviation') | list | length %}
          {% set na = res | selectattr('status', 'equalto', 'not_applicable') | list | length %}
          | {{ h }} | {{ ok }} | {{ bad }} | {{ na }} |
          {% endfor %}
          {% for h in lesson10_report.no_data %}
          | {{ h }} | no data | no data | no data |
          {% endfor %}
        mode: "0644"
```

Hänge dieses Play an die Datei des vorigen Beispiels an, um echte Zahlen zu sehen. Für sich läuft es
trotzdem und meldet dann jeden Host als *no data* - genau den Fall, den es behandeln soll. Der
Bericht landet in `/tmp/lesson10/reports` des Control Nodes, als JSON für Maschinen und als
Markdown-Tabelle für Menschen, aus denselben Daten.

Zwei Eigenschaften machen einen Bericht über die Zeit brauchbar. Er muss **deterministisch** sein:
`to_nice_json` sortiert Schlüssel (getestet), Hosts sind sortiert, und ein zweiter Lauf schreibt
dieselben Bytes, der Lauf ist also `changed=0`. Ein Zeitstempel im Inhalt zerstört das; in einem
Test war die einzige Datei, die sich im zweiten Lauf änderte, die mit dem Zeitstempel. Dann sieht
jeder Lauf nach einer Änderung aus, Drift verschwindet im Rauschen, und die Versionsverwaltung
füllt sich mit Diffs. Ist die Zeit wichtig, gehört sie in den Dateinamen oder ins Log des Runners.
Und er ist eine **Ausgabe**, kein verwalteter Zustand. Ein Play auf `localhost` hat seine eigene
Recap-Zeile, die Targets bleiben also bei `changed=0`; ein Task mit `delegate_to: localhost` und
`run_once` wird stattdessen beim ersten Ziel-Host gezählt (getestet: `changed: [t1 -> localhost]`).
Unter `--check` schreibt ein `copy` nichts; ein Bericht, der im Trockenlauf erscheinen soll, braucht
`check_mode: false` an seinen Tasks (getestet: nur der Task mit dem Keyword schrieb seine Datei).

### Custom Facts: Hosts, die sich selbst beschreiben

Der Bericht oben wird von außen berechnet, zur Audit-Zeit. Manchmal soll der Host seine eigene
Beschreibung tragen, die jedes spätere Play lesen kann, ohne die Kontrollen neu laufen zu lassen:
welche Baseline angewendet wurde und was gerade gilt. Das Sammeln von Facts unterstützt das. Dateien
namens `*.fact` in einem Verzeichnis auf dem Host (standardmäßig `/etc/ansible/facts.d`, auf allen
acht Targets nicht vorhanden) erscheinen als `ansible_local.<Dateiname>`:

| | Statischer Fact | Ausführbarer Fact |
|---|---|---|
| Datei | JSON- oder INI-Text, nicht ausführbar | ausführbar, gibt JSON aus |
| Antwortet | was angewendet wurde | was jetzt gilt |
| Berechnet | beim Deployment, von Ansible | bei jedem Sammeln, auf dem Host |
| Kosten | keine | läuft jedes Mal und bremst jedes Play |
| Unter `--check` | gelesen | **läuft wirklich** |

```yaml
- name: Hosts that describe themselves with custom facts
  hosts: targets
  gather_facts: false
  vars:
    lesson10_fact_dir: /tmp/lesson10/facts.d
  tasks:
    - name: Make sure the fact directory exists
      ansible.builtin.file:
        path: "{{ lesson10_fact_dir }}"
        state: directory
        mode: "0755"

    - name: Static fact - what was applied
      ansible.builtin.copy:
        dest: "{{ lesson10_fact_dir }}/applied.fact"
        content: "{{ {'profile': 'demo', 'revision': 3} | to_nice_json }}\n"
        mode: "0644"

    - name: Executable fact - what is true now
      ansible.builtin.copy:
        dest: "{{ lesson10_fact_dir }}/live.fact"
        content: |
          #!/bin/sh
          # read-only: facts are gathered in every run, also in --check
          count=$(ls -1 /tmp/lesson10 2>/dev/null | wc -l)
          printf '{"entries": %d, "shell": "%s"}\n' "$count" "$(basename "$(readlink -f /bin/sh)")"
        mode: "0755"

    - name: Gather the local facts again
      ansible.builtin.setup:
        fact_path: "{{ lesson10_fact_dir }}"
        gather_subset: min
        filter: ansible_local

    - name: Show what the host says about itself
      ansible.builtin.debug:
        var: ansible_local
      when: not ansible_check_mode
```

Die Lab-Beispiele nutzen `/tmp/lesson10/facts.d` über die Option `fact_path` von `setup`; in
Produktion ist der Standardpfad der, den das normale Sammeln von Facts liest. Der zweite Lauf des
Plays ist `changed=0`; der ausführbare Fact meldet die Einträge von `/tmp/lesson10` und welche
Shell `/bin/sh` ist. Vier Eigenschaften entscheiden, ob Facts verlässlich sind:

- **Das Sammeln geschieht, bevor deine Dateien existieren.** Nach dem Deployment ist `ansible_local`
  veraltet (in einem Test leer, `{}`), bis ein `setup` mit `filter: ansible_local` erneut sammelt.
  Unter `--check` wurde nichts geschrieben, es bleibt also leer - deshalb wird dort das `debug`
  übersprungen. Dieselben Daten sind `ansible_facts.ansible_local`. Ein `gather_subset` von
  `!all,!min` überspringt lokale Facts: in einem Test lief das Skript nicht.
- **Typen überleben in JSON, nicht in INI.** JSON behält Zahlen und Schlüsselschreibung
  (`revision: 3` bleibt eine Ganzzahl). INI liefert jeden Wert als String und schreibt die
  Optionsnamen klein (`Mixed_Case` wurde zu `mixed_case`; Abschnittsnamen behielten ihre
  Schreibung).
- **Ein kaputter Fact ist Text, kein Fehler.** Ungültiges JSON, ein Exit-Code ungleich null oder
  ein Skript ohne Ausführungsbit hinterlassen alle einen String in `ansible_local` (`error loading
  facts as JSON or ini ...`, `Failure executing fact script ..., rc: 3`), und das Play läuft
  weiter. Der Verbraucher muss prüfen, dass er ein Mapping bekommen hat.
- **Rechte.** Ein Fact-Skript läuft auf dem Host mit den Rechten des Tasks, der sammelt. In einem
  Test liefen die Skripte ohne `become` als Verbindungsbenutzer (uid 1000, 1001 auf ubuntu) und
  mit `become: true` als root (uid 0), auf allen acht Targets - mit einem expliziten `setup`-Task
  und mit dem impliziten Sammeln am Anfang eines Plays (`become` am Play). Ein Skript, das Dateien liest, die
  nur root lesen darf, braucht das privilegierte Sammeln. Das Verzeichnis ist außerdem ein Ort, an
  dem Code als dieser Benutzer läuft: wer dort schreiben darf, führt beim nächsten privilegierten
  Lauf Code als root aus. Halte die Dateien auf `root:root` und das Verzeichnis für andere
  geschlossen.

Ein statischer Fact ist verwalteter Zustand wie jede Datei: kein Zeitstempel darin, sonst ist der
zweite Lauf nie `changed=0`. Ein ausführbarer Fact ist Code auf jedem Host und in jedem Play: halte
ihn schnell, lesend (er läuft unter `--check`), ohne Netzwerkzugriff und in reinem POSIX-`sh` - die
Shell unterscheidet sich je Plattform (siehe unten).

## CIS-Hintergrund

Jede Empfehlung eines Benchmarks hat eine Audit-Prozedur und eine Remediation-Prozedur (L01), und
diese Lektion ist die Ansible-Seite, beide zusammenzuhalten: der Audit-Modus einer Rolle ist die
Audit-Prozedur, der Enforce-Modus die Remediation. Übung 5.01 umfasst die Level-1-Abschnitte der
Stufen davor (der Kopf listet die, die der Katalog ihr zuordnet) und als Level 2 den Abschnitt 6.3
(auditd, L09).

Ein Bericht ist ein Nachweis, deshalb verlangen Auditoren und Versicherer einen (L01). Lies ihn mit
seinen Grenzen im Kopf. „Alles ok“ heißt: alle *umgesetzten* Kontrollen sind ok: manuelle
Empfehlungen, Kontrollen, die die Rolle nicht hat, und als nicht anwendbar markierte Kontrollen
liegen außerhalb der Zahl, so wie die *Manual*-Empfehlungen außerhalb eines CIS-CAT-Scores liegen.
Ausgenommene Kontrollen und Kontrollen des anderen Profils sind eigene Berichtszustände; wie eine
Rolle sie entscheidet (`when`, `cis_level`, dokumentierte Ausnahmen), behandelt L11. Und Compliance
ist weiterhin nicht Sicherheit (L01).

Der Audit-Modus macht auch Drift sichtbar. Ein geplanter Audit-Lauf, dessen Berichte als Reihe
aufbewahrt werden, zeigt, wann ein Host die Baseline verlassen hat - der Grund, das Audit frei von
Seiteneffekten und den Bericht frei von Zeitstempeln in verwalteten Dateien zu halten.

## Plattformunterschiede

| os_family | Hosts | `/bin/sh` (für Fact-Skripte) | Fact `service_mgr` | `/etc/systemd/system` |
|---|---|---|---|---|
| Debian | debian, ubuntu | dash | `systemd` | vorhanden |
| RedHat | rocky, alma, fedora | bash | `systemd` | vorhanden |
| Suse | opensuse | bash | `systemd` | vorhanden |
| Alpine | alpine | BusyBox ash (`/bin/sh` ist `/bin/busybox`) | `openrc` | nicht vorhanden |
| Archlinux | arch | bash | `systemd` | vorhanden |

Gemessen auf den Targets des Labs. Ein Fact-Skript muss deshalb POSIX-`sh` sein: keine Arrays, kein
`[[ ]]` und nur Werkzeuge, die auch BusyBox hat - das Beispiel lief in einem Test nur mit
BusyBox-Applets durch. Das Facts-Verzeichnis `/etc/ansible/facts.d` fehlte auf allen acht Hosts, ein
Play legt es also an. Die Schlüsselwörter, die `sshd -T` ausgibt, unterscheiden sich in der
Schreibung zwischen Hosts (siehe L03), was wichtig wird, sobald ein Bericht sie vergleicht.

### In den Lab-Containern

- Ein Audit liest den Container, keine Maschine. Bei Kernel-Parametern ist das die Sicht des
  Containers: ein `net.*`-Schlüssel gilt je Netzwerk-Namespace, ein `kernel.*`-Schlüssel gehört dem
  Host (L05).
- Das Lab verbindet sich als Benutzer `ansible` (uid 1000, 1001 auf ubuntu) ohne `become`: Tasks,
  die root brauchen, und das Sammeln von Facts, das nur root-lesbare Dateien liest, brauchen
  `become: true`.
- Alle Beispiele nutzen `hosts: targets` und brauchen daher 0.02 (Python auf Alpine). Sie schreiben
  unter `/tmp/lesson10` jedes Targets und des Control Nodes; entferne es mit `rm -rf /tmp/lesson10`
  (auf den Targets zum Beispiel `ansible targets -m ansible.builtin.file -a 'path=/tmp/lesson10
  state=absent'`).

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| Das Audit nennt einen falschen Host in Ordnung | die Prüfung ist ein `command`- oder `shell`-Task, im Check-Modus übersprungen, und nur `changed` wird gezählt | ein Modul nehmen, das entscheidet, oder mit `check_mode: false` lesen und vergleichen |
| `--check` mit dem Enforce-Modus schrieb Dateien | das Keyword ist `{{ mode == 'audit' }}`, beim Enforce `false` und überschreibt `--check` | `ansible_check_mode or ...` |
| `when: not ansible_check_mode` schützt einen geprüften Task nicht | die Variable ist das Kommandozeilen-Flag, nicht das Keyword | die Modus-Variable testen |
| Ein Audit-Lauf hat einen Dienst neu geladen | ein Handler, von einem geprüften Block benachrichtigt, läuft wirklich | den Handler mit dem Modus absichern |
| Ein Hintergrund-Job ist bei jedem Audit eine Abweichung | `poll: 0` meldet `changed`, wenn der Job startet, auch im Check-Modus | in einem Vordergrund-Task entscheiden (L09) |
| `has no attribute` im Berichts-Play | ein Host hat kein Ergebnis: er fiel aus, war nicht erreichbar oder wurde per `-l` ausgelassen | mit `defined` schützen und den Host als no data aufführen |
| Der Bericht ändert sich bei jedem Lauf | ein Zeitstempel oder unsortierter Inhalt | beides aus dem Inhalt halten; Zeit im Dateinamen oder im Log |
| `ansible_local` ist nach einem Deployment leer oder alt | die Facts wurden vor den Dateien gesammelt, oder `--check` schrieb nichts | mit `setup` erneut sammeln; mit `default` lesen |
| Ein Fact ist ein String wie `error loading facts` | ungültiges JSON, Exit-Code ungleich null oder kein Ausführungsbit | das Skript von Hand ausführen; prüfen, dass der Wert ein Mapping ist |

## Übungen

| Übung | Was diese Lektion vorbereitet |
|---|---|
| [4.01](../../exercises/stage4-advanced/4.01-audit-only-report/README.de.md) | lesende Auswertung mit `check_mode: false` an den Lesern, Ergebnisse als Daten mit einem Status je Kontrolle, `n/a` außerhalb des Scores, Sammeln über `hostvars`, Hosts ohne Daten, ein deterministischer JSON- und Markdown-Bericht |
| [4.05](../../exercises/stage4-advanced/4.05-custom-facts/README.de.md) | `facts.d`, statische und ausführbare Facts, `ansible_local` und das erneute Sammeln, die Rechte und die Kosten eines Fact-Skripts, keine Zeitstempel in verwalteten Dateien |
| [5.01](../../exercises/stage5-capstone/5.01-capstone-cis-role/README.de.md) | der Check-Modus als Audit-Motor hinter einer Modus-Variable, was er nicht aufhält (Handler, Hintergrund-Tasks), warum ein Include das Keyword nicht tragen kann, der Bericht einer Rolle |

Starte eine Übung mit `lab start <id>`; `lab show <id>` gibt ihre README aus.

## Selbstkontrolle

1. Ein Kollege hat bereits ein nächtliches Audit-Skript. Warum würdest du der Remediation-Rolle
   trotzdem einen Audit-Modus geben?

   <details><summary>Antwort</summary>

   Zwei Codebasen laufen auseinander: das Skript prüft, was sein Autor für das Verhalten der Rolle
   hält, jede Regel gibt es doppelt, und ein Fehler im einen zeigt sich nie im anderen. Im
   Audit-Modus entscheiden die eigenen Tasks der Rolle, was nicht in Ordnung ist, das Audit kann
   der Remediation also nicht widersprechen. Außerdem kostet es einen Schalter statt einer zweiten
   Codebasis.

   </details>

2. In einem Audit-Lauf wird eine als `command` umgesetzte Kontrolle übersprungen, und der Host
   erscheint voll konform. Warum, und was kannst du tun?

   <details><summary>Antwort</summary>

   Ein `command`-Task kann seine Wirkung nicht vorhersagen, der Check-Modus überspringt ihn also:
   `changed` ist false, und nichts wurde geprüft. Das ist „unbekannt“, nicht „ok“. Nimm ein Modul,
   das entscheidet (`stat`, `copy`, `lineinfile` und so weiter), oder lies den Zustand mit einem
   Task mit `check_mode: false` und werte den Wert selbst aus.

   </details>

3. Der Enforce-Modus deines Plays setzt `check_mode: "{{ mode == 'audit' }}"` an einem Block.
   Jemand startet es mit `-e mode=enforce --check`. Was passiert, und welcher Ausdruck ist sicher?

   <details><summary>Antwort</summary>

   Der Ausdruck ist `false`, und `false` überschreibt `--check`: die Tasks des Blocks ändern den
   Host wirklich. `ansible_check_mode or mode == 'audit'` bleibt ein Trockenlauf, wenn eines von
   beiden einen verlangt.

   </details>

4. Ein geprüfter Block benachrichtigt einen Handler. Das Audit lässt den Host unverändert, doch
   der Dienst wurde neu geladen. Wie, und wie verhinderst du es?

   <details><summary>Antwort</summary>

   Das Keyword gilt nur für die Tasks des Blocks. Der Handler hat keins und läuft wirklich, sobald
   ein geprüfter Task `changed` meldet. Sichere den Handler mit `when:` auf der Modus-Variable ab.

   </details>

5. Die Gruppe hat zwölf Hosts, der JSON-Bericht enthält elf. Was könnte der zwölfte sein, und was
   muss der Bericht damit tun?

   <details><summary>Antwort</summary>

   Ein Host, der ausfiel, bevor er ein Ergebnis lieferte, nicht erreichbar war oder per `-l`
   ausgelassen wurde: er hat keine Ergebnis-Variable. Ein Bericht, der ihn stillschweigend
   auslässt, liest sich wie „alles in Ordnung“. Er führt den Host ausdrücklich als *no data* auf,
   und der Schutz beim Sammeln (`defined`) verhindert, dass das Lesen fehlschlägt.

   </details>

6. Ein Berichts-Template gibt die Zeit des Laufs aus. Was bewirkt das für den Lauf, und wohin
   gehört die Zeit?

   <details><summary>Antwort</summary>

   Die Datei unterscheidet sich bei jedem Lauf, der Lauf ist also nie `changed=0`, echte Drift geht
   im Rauschen unter, und die Versionsverwaltung füllt sich mit Diffs. Halte verwaltete Dateien
   eine reine Funktion ihrer Eingaben; die Zeit gehört in den Dateinamen oder ins Log des Runners.

   </details>

7. „Welche Baseline-Revision wurde angewendet?“ und „ist der Root-Login gerade aus?“ - welches ist
   ein statischer und welches ein ausführbarer Fact, und was kostet jeder?

   <details><summary>Antwort</summary>

   Die Revision ist *was angewendet wurde*: ein statischer Fact, beim Deployment geschrieben, danach
   kostenlos. Der Zustand des Root-Logins ist *was jetzt gilt*: ein ausführbarer Fact, der bei jedem
   Sammeln läuft, jedes Play bremst, auch unter `--check` läuft (also lesend sein muss) und die
   richtigen Rechte braucht, um zu sehen, was er misst. Ein statischer Fact kann veraltet sein; ein
   ausführbarer kann langsam sein oder fehlschlagen.

   </details>

8. Du legst mitten in einem Play eine Fact-Datei an und liest direkt danach `ansible_local.x`: es
   ist nicht definiert. Nach einem `setup` mit `filter: ansible_local` ist es da - außer unter
   `--check` auf einem frischen Host. Warum?

   <details><summary>Antwort</summary>

   Facts werden einmal gesammelt, bevor die Datei existierte, die Variable ist also bis zum
   erneuten Sammeln veraltet. Unter `--check` schreibt das `copy` nichts, also findet selbst das
   neue Sammeln keine Datei. Verbraucher brauchen ein `default` oder ein Überspringen, wenn
   `ansible_check_mode` wahr ist.

   </details>

## Weiterführendes

- [Validating tasks: check mode and diff mode](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html) - das Keyword, das Flag und `check_mode: false`
- [Blocks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html) und [Handlers](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html) - was die Keywords eines Blocks erreichen und wann ein Handler läuft
- [Discovering variables: facts and magic variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_vars_facts.html) - lokale Facts und `hostvars`
- [`ansible.builtin.setup`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/setup_module.html) - `fact_path`, `gather_subset` und `filter`
- [Special variables](https://docs.ansible.com/ansible/latest/reference_appendices/special_variables.html) - `hostvars`, `groups` und `ansible_check_mode`
- [Using filters to manipulate data](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html) - `to_nice_json`, `selectattr`, `difference`
