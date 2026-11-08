# L11 - Profile, Ausnahmen und datengetriebene Rollen: eine Rolle, viele Adressaten

*[English](L11-profiles-exceptions-and-data-driven-roles.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 4.02, 4.03 | 5.3.3, 5.4.1, 5.4.2, 5.4.3, 6.3 | ~35 Min. | L04, L07, L10 |

Eine Baseline-Rolle hat drei Adressaten. Der Betrieb will Level 1 auf den meisten Hosts und Level 2
auf wenigen. Der Auditor will jede bewusste Abweichung sehen, mit Begründung und Enddatum. Und die
Plattform will als das behandelt werden, was sie ist: Ein Host ohne PAM-Modul für die
Passwortqualität kann keine PAM-Richtlinie bekommen, und die Rolle muss das sagen, statt zu
scheitern oder so zu tun, als ginge es. Diese Lektion behandelt die drei Schalter dahinter - das
Profil, die Ausnahme und die Plattformdaten - und wie man sie von außen testet.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] ein Profil als einen geprüften Wert modellieren und sagen, was ein `when` an einem Block mit den Tasks darin macht
- [ ] erklären, warum ein Wert aus `-e` ein String sein kann und was das für einen numerischen Vergleich bedeutet
- [ ] eine Ausnahme als Datensatz mit Begründung und Enddatum beschreiben und sagen, wo er liegt und wie er geprüft wird
- [ ] vorhersagen, wie sich ein YAML-Datum, `to_datetime` und `now()` verhalten, auch an dem Tag, an dem eine Ausnahme endet
- [ ] Eingaben vor der ersten Änderung prüfen und sagen, was `argument_specs` prüfen kann und was nicht
- [ ] einen Plattformunterschied als Fähigkeits-Flag mit Fallback ausdrücken und sagen, wer ihn überschreiben kann
- [ ] zwischen dem Laden einer Datendatei und dem Schichten mehrerer wählen
- [ ] eine Rolle von außen testen: übersprungene Tasks aus dem JSON-Callback lesen und einen Umbau mit `--check` belegen

## Theorie

### Ein Profil ist ein Wert

Level 1 und Level 2 (L01) unterscheiden sich darin, wie viel die Rolle tut. Zwei Kopien einer
Rolle laufen auseinander, dasselbe Argument, das L10 gegen ein getrenntes Audit-Skript brachte.
Tags (L07) wählen Tasks auf der Kommandozeile, das Profil läge also in einer Gewohnheit: Wer
`--tags` vergisst, härtet auf dem falschen Level. Die bessere Antwort ist ein Wert, den die Rolle
liest. Er ist eine Schnittstelle und gehört deshalb nach `defaults/` (L07: Wenn ein Anwender einen
anderen Wert wollen kann, ist es ein Default); eine Flotte setzt ihn im Inventory (L04), ein
einzelner Lauf mit `-e`. Die Rolle entscheidet, was ein Level bedeutet, der Aufrufer nennt es nur.

Drei Details entscheiden, ob das funktioniert.

**Der Typ.** `-e name=value` kommt immer als String an. In einem Test war `-e lesson11_level=2`
ein `str` und `-e '{"lesson11_level": 2}'` ein `int`; eine Zahl in einer YAML-Datei wie
`defaults/main.yml` ist ein `int`. `when: lesson11_level >= 2` mit dem String bricht den Play ab
mit `'>=' not supported between instances of '_AnsibleTaggedStr' and 'int'` (ansible-core 2.21.6).
Konvertiere dort, wo du vergleichst, mit `| int`, dann geht die Kommandozeile in beiden Formen.

**Der Block.** Ein `when` an einem Block wird an jeden Task darin weitergegeben, und jeder Task
wertet es für sich aus. Übersprungene Tasks erscheinen als `skipping` und zählen in der Übersicht
als `skipped`. Weil jeder Task die Bedingung auswertet, lässt ein Task im Block, der eine
Variable der Bedingung ändert, die folgenden Tasks überspringen (mit `set_fact` getestet): Halte
die Eingaben einer Bedingung aus ihrem eigenen Block heraus.

**Der Wert.** `>= 2` ist auch für 3 wahr, und `l2 | int` ist 0 (getestet), ein Tippfehler wählt
also stillschweigend ein strengeres oder ein laxeres Profil. Ein Level, das die Rolle nicht kennt,
muss den Play stoppen, bevor etwas geändert wird. Die Demo hat zwei eigene Kontrollen, einen
Hinweis (Level 1) und zwei strenge Dateien (Level 2); `assert` (L02) bewacht das Level.

```bash
mkdir -p /tmp/lesson11 && cd /tmp/lesson11
```

```yaml
- name: A profile switch
  hosts: targets
  gather_facts: false
  vars:
    lesson11_level: 1
  tasks:
    - name: Make sure the demo directory exists
      ansible.builtin.file:
        path: /tmp/lesson11
        state: directory
        mode: "0755"
      # Vorbereitung der Demo, keine Kontrolle
      check_mode: false

    - name: Refuse levels the role does not know
      ansible.builtin.assert:
        that: lesson11_level | int in [1, 2]
        fail_msg: "lesson11_level must be 1 or 2, got {{ lesson11_level }}"
        quiet: true

    - name: Demo-notice | Level 1 baseline
      ansible.builtin.copy:
        dest: /tmp/lesson11/notice.txt
        content: "authorised use only\n"
        mode: "0644"

    - name: Demo-strict | Level 2 additions
      when: lesson11_level | int >= 2
      block:
        - name: Demo-strict | Strict settings file
          ansible.builtin.copy:
            dest: /tmp/lesson11/strict.conf
            content: "max_retries 3\n"
            mode: "0600"

        - name: Demo-strict | Strict marker file
          ansible.builtin.copy:
            dest: /tmp/lesson11/strict.marker
            content: "strict\n"
            mode: "0644"
```

Speichere sie als `/tmp/lesson11/profile.yml` und führe sie aus:

```bash
ansible-playbook profile.yml                          # Level 1: der Hinweis
ansible-playbook profile.yml -e lesson11_level=2      # ergänzt die beiden strengen Dateien
ansible-playbook profile.yml -e lesson11_level=2      # zweiter Lauf: changed=0
ansible-playbook profile.yml                          # wieder Level 1: changed=0
ansible-playbook profile.yml -e lesson11_level=3      # stoppt am assert
```

Die `2` von der Kommandozeile ist ein String und funktioniert trotzdem, weil die Bedingung
konvertiert. Der vierte Lauf zeigt, was ein Profil nicht tut: Es geht nicht zurück. Ein Lauf auf
Level 1 nach Level 2 ist `changed=0`, und die strengen Dateien bleiben (getestet). Ein Profil sagt
nur, was anzuwenden ist; nach unten zu gehen braucht also Entfernen-Tasks oder einen frischen
Host, und die Dokumentation der Rolle sollte das sagen.

### Ausnahmen sind Datensätze, und Eingaben werden geprüft, bevor etwas läuft

Keine Organisation setzt einen Benchmark vollständig um (L01). Was eine gesteuerte Abweichung von
einer Lücke trennt, ist, wie sie festgehalten wird. Ein gelöschter Task oder ein `when: false` hat
keine Begründung, keinen Verantwortlichen und kein Ende. Als Daten hat eine Ausnahme alle drei:
welche Kontrolle, warum (eine Ticketnummer ist eine gute Begründung), bis wann und in einer
echten Umgebung wer sie genehmigt hat. Halte die Liste neben dem Inventory, in der
Versionsverwaltung, und ändere sie nur per Review; der Diff ist die Spur für das Audit. Es ist
eine Liste von Datensätzen, nicht von Ids, weil sich eine Id allein nicht prüfen lässt.

Tasks brauchen etwas Einfaches zum Testen. Eine Filterkette (L04) macht aus den Datensätzen eine
Liste von Ids, und ein `when` kann dann fragen, ob die Id einer Kontrolle darin steht. Ein Lauf
sollte auch *sagen*, welche Kontrollen ausgenommen wurden, mit Begründung und Enddatum: Eine
ausgenommene Kontrolle ist weder in Ordnung noch eine Abweichung, sondern ein eigener Zustand
(L10 erwähnt ihn, 5.01 berichtet ihn).

#### Datumsangaben

Ein Enddatum nützt nur, wenn der Play es versteht. Die Demo benutzt Datensätze mit eigenen
Feldnamen und gibt aus, was Ansible aus den Daten macht.

```yaml
- name: Exception records and their dates
  hosts: targets
  gather_facts: false
  run_once: true
  vars:
    lesson11_waivers:
      - control: demo-notice
        why: legacy application needs the old notice
        until: 2027-01-31
      - control: demo-strict
        why: the same date, quoted
        until: "2027-01-31"
  tasks:
    - name: Say which controls are excepted
      ansible.builtin.debug:
        msg: "EXCEPTED {{ item.control }} until {{ item.until }}: {{ item.why }}"
      loop: "{{ lesson11_waivers }}"
      loop_control:
        label: "{{ item.control }}"

    - name: Show the type of each date
      ansible.builtin.debug:
        msg: "{{ item.control }}: {{ item.until | type_debug }}"
      loop: "{{ lesson11_waivers }}"
      loop_control:
        label: "{{ item.control }}"

    - name: A date as text becomes a datetime at midnight
      ansible.builtin.debug:
        msg: "{{ lesson11_waivers[0].until | string | to_datetime('%Y-%m-%d') }}"

    - name: Is today, taken as a date, already in the past
      ansible.builtin.debug:
        msg: "{{ (now().strftime('%Y-%m-%d') | to_datetime('%Y-%m-%d')) < now() }}"

    - name: The ids a condition can test
      ansible.builtin.debug:
        msg: "{{ lesson11_waivers | map(attribute='control') | list }}"
```

Speichere sie als `waivers.yml` und führe `ansible-playbook waivers.yml` aus. Vier Tatsachen
ergeben sich daraus (alle mit ansible-core 2.21.6 gemessen):

- Das unquotierte `2027-01-31` ist ein **Datum**-Objekt, das quotierte ein **String**.
  `to_datetime` will Text: Beim Datum scheitert es mit `strptime() argument 1 must be str, not
  _AnsibleTaggedDate`. Quotiere Daten in den Daten, oder konvertiere vor dem Parsen in einen
  String.
- Das Format ist streng. `'31.01.2027'` mit `'%Y-%m-%d'` scheitert mit `time data '31.01.2027'
  does not match format '%Y-%m-%d'`: Lege ein Format fest und schreibe es auf.
- Das Ergebnis ist **Mitternacht zu Beginn** des Tages: `2027-01-31T00:00:00`. Mit `now()`
  verglichen, liegt ein Enddatum von *heute* schon in der Vergangenheit, und die letzte Demo-Task
  gibt `True` aus. Entscheide, ob `until` der erste nicht mehr gültige oder der letzte gültige
  Tag ist, und vergleiche entsprechend.
- `now()` ist ein naives Datetime in der Ortszeit des **Control Nodes**; `now(utc=true)` ist die
  UTC-Zeit, ebenfalls naiv, und beide ließen sich mit dem geparsten Datum vergleichen. Uhr und
  Zeitzone des Targets spielen keine Rolle.

#### Prüfen vor der ersten Änderung

Ausnahmen kommen aus vielen Händen: Inventory, CI-Variablen, `-e`. Tippfehler scheitern *offen*.
Eine falsch geschriebene Kontroll-Id macht die Ausnahme wirkungslos, die Kontrolle läuft also,
obwohl das Team sie ausgenommen glaubte - auf einem Produktionshost kann das ein Ausfall sein.
Eine leere Begründung ist eine undokumentierte Ausnahme, ein fehlendes Enddatum eine ewige, und
ein Level `3` verhält sich wie `2`. Die Regel lautet: schnell scheitern, vor dem ersten Task, der
etwas ändert, mit einer Meldung, die den fehlerhaften Datensatz nennt. Zwei Werkzeuge leisten das.

Ein `assert` in einem Preflight-Task läuft auch unter `--check` (getestet: Level 3 stoppte einen
`--check`-Lauf am assert). Schreibe eine Bedingung pro Regel in `that:`, damit ein Fehler auf eine
Regel zeigt, und laufe mit einem `loop_control.label` über die Datensätze, damit die Meldung den
Datensatz nennt.

`meta/argument_specs.yml` deklariert die Schnittstelle einer Rolle: Typen, erlaubte Werte,
Pflichtschlüssel und für eine Liste von Mappings die Optionen jedes Elements. Ansible prüft die
Eingabe vor dem ersten Task der Rolle, auch unter `--check`; die Prüfung erscheint als eigener
Task, mit `always` getaggt, ganz oben in `--list-tasks`. Die Demo-Rolle `demo_gate` hat zwei
Eingaben:

```bash
mkdir -p /tmp/lesson11/roles/demo_gate/{meta,defaults,tasks} && cd /tmp/lesson11
cat > roles/demo_gate/defaults/main.yml <<'EOF'
---
demo_gate_level: 1
demo_gate_waivers: []
EOF
cat > roles/demo_gate/tasks/main.yml <<'EOF'
---
- name: Report what the role received
  ansible.builtin.debug:
    msg: "level {{ demo_gate_level }} ({{ demo_gate_level | type_debug }}), {{ demo_gate_waivers | length }} waivers"
EOF
cat > gate.yml <<'EOF'
- name: Use the demo role
  hosts: debian
  gather_facts: false
  roles:
    - role: demo_gate
EOF
```

```yaml
---
argument_specs:
  main:
    short_description: The two inputs of the demo role
    options:
      demo_gate_level:
        type: int
        choices: [1, 2]
        description: Profile level.
      demo_gate_waivers:
        type: list
        elements: dict
        description: Recorded deviations.
        options:
          control:
            type: str
            required: true
            choices: [demo-notice, demo-strict]
          why:
            type: str
            required: true
          until:
            type: str
            required: true
```

Speichere die Spezifikation als `roles/demo_gate/meta/argument_specs.yml` und probiere fünf
Eingaben:

```bash
ansible-playbook gate.yml                                  # Defaults
ansible-playbook gate.yml -e demo_gate_level=2             # geht durch - die Rolle sieht weiter einen String
ansible-playbook gate.yml -e demo_gate_level=3             # gestoppt vor dem ersten Task der Rolle
ansible-playbook gate.yml -e '{"demo_gate_waivers": [{"control": "demo-notic", "why": "x", "until": "2027-01-01"}]}'
ansible-playbook gate.yml -e '{"demo_gate_waivers": [{"control": "demo-notice", "why": "", "until": "soon"}]}'
```

Der dritte und der vierte Lauf stoppen mit `argument_errors`, die das Problem nennen: `value of
demo_gate_level must be one of: 1, 2, got: 3` und `value of control must be one of: demo-notice,
demo-strict, got: demo-notic found in demo_gate_waivers`. Ein Datensatz ohne `why` wird als
fehlendes Pflichtargument gemeldet, und eine Option, die nicht in der Spezifikation steht, wird
mit der Liste der unterstützten abgelehnt. Der fünfte geht durch: Ein **leeres** `why` und das
Datum `soon` erfüllen `type: str` und `required: true`. Eine Spezifikation prüft die Form, nicht
die Bedeutung - sie kann weder nicht leeren Text noch ein Datumsformat noch ein Datum in der
Zukunft verlangen, und sie kann zwei Felder nicht zueinander in Beziehung setzen. Sie **prüft
außerdem, konvertiert aber nicht**: Der zweite Lauf gab für das Level `str` aus, und ein
YAML-Datum aus `-e @file` besteht `type: str` und bleibt ein Datum. Die Konvertierungen der beiden
vorigen Teile bleiben in den Tasks. Die beiden Werkzeuge ergänzen sich also: die Spezifikation
für Form und erlaubte Ids, `assert` für die Regeln über den Inhalt.

### Plattformdaten und Fähigkeits-Flags

L04 hat Plattformunterschiede in Daten verlegt. Die nächste Frage ist, welche Art von Daten.
„Diese Kontrolle gilt auf Alpine nicht“ lässt sich als Bedingung auf das System schreiben
(`when: os_family != ...`) oder als Wert aus einer Datendatei, der eine Fähigkeit benennt:
`demo_acl_supported: false`. Die Bedingung sagt, was, nicht, warum. Sie wiederholt sich in jedem
Task, der das Feature berührt, und für eine neue Plattform muss man jede Task-Datei öffnen, um
Logik zu ändern. Ein Fähigkeits-Flag sagt, was die Plattform kann; Tasks stellen die Frage nach
der Fähigkeit; die Plattformdatei beantwortet sie einmal, mit einem Kommentar zur kompensierenden
Maßnahme oder zur dokumentierten Lücke. Wo sich die Fähigkeit auf dem Host prüfen lässt - ein
Befehl, den es gibt oder nicht -, schlägt Prüfen eine Tabelle von Versionsnummern.

Welche Datei gelesen wird, entscheidet `first_found` (L07): der erste vorhandene Name aus einer
Liste, die vom Spezifischsten zu einer allgemeinen Datei läuft. Drei Eigenschaften zählen, und
eine Demo, die über eine Variable statt über einen Fact gewählt wird, zeigt alle. Lege zuerst die
Daten an:

```bash
mkdir -p /tmp/lesson11/vars && cd /tmp/lesson11
cat > vars/default.yml <<'EOF'
# konservativ: ein unbekannter Flavour bekommt nichts, dessen er nicht sicher sein kann
demo_acl_supported: false
demo_xattr_supported: false
EOF
cat > vars/blue.yml <<'EOF'
demo_acl_supported: true
EOF
cat > vars/blue-2.yml <<'EOF'
demo_xattr_supported: true
EOF
```

```yaml
- name: Platform data - one file or layers
  hosts: debian
  gather_facts: false
  vars:
    lesson11_flavour: blue
    lesson11_release: "2"
    demo_acl_supported: set by the play
  tasks:
    - name: Load the most specific data file only
      ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', lesson11_candidates) }}"
      vars:
        lesson11_candidates:
          files:
            - "{{ lesson11_flavour }}-{{ lesson11_release }}.yml"
            - "{{ lesson11_flavour }}.yml"
            - default.yml
          paths:
            - vars

    - name: Show the flags
      ansible.builtin.debug:
        msg: "acl={{ demo_acl_supported }} xattr={{ demo_xattr_supported | default('not set') }}"
```

```yaml
- name: Platform data - layers instead of one file
  hosts: debian
  gather_facts: false
  tasks:
    - name: Load the general file first, the specific one second
      ansible.builtin.include_vars: "{{ item }}"
      loop:
        - vars/blue.yml
        - vars/blue-2.yml

    - name: Show the flags
      ansible.builtin.debug:
        msg: "acl={{ demo_acl_supported }} xattr={{ demo_xattr_supported }}"
```

Speichere sie als `data.yml` und `layers.yml` und führe aus:

```bash
ansible-playbook data.yml                                # nur blue-2.yml
ansible-playbook data.yml -e lesson11_release=1          # kein blue-1.yml: blue.yml
ansible-playbook data.yml -e lesson11_flavour=zeta       # nichts passt: default.yml
ansible-playbook data.yml -e demo_acl_supported=forced   # die Kommandozeile
ansible-playbook layers.yml                              # beide Dateien, der Reihe nach
```

Die Meldungen lauten `acl=set by the play xattr=True`, `acl=True xattr=not set`, `acl=False
xattr=False`, `acl=forced xattr=True` und `acl=True xattr=True`. Lies sie so.

- **Eine Datei.** `first_found` liefert eine Datei. `blue-2.yml` definiert
  `demo_acl_supported` nicht, das Flag kommt also von wo auch immer es sonst definiert ist - hier
  vom Play. Beim Ein-Datei-Lookup muss jede Datei vollständig sein, sonst gehört die Lücke
  jemand anderem. Zum Schichten lädst du mehrere Dateien der Reihe nach, die allgemeine zuerst;
  die spätere gewinnt für die Namen, die sie definiert. Eine fehlende Datei in so einer Liste ist
  ein Fehler (`Could not find or access`), anders als der Fallback von `first_found`.
- **Ein Fallback.** Ohne `default.yml` endet ein unbekannter Flavour in `No file was found when
  using first_found` (L07). Mit einer stellt sich die Frage, was darin steht. Eine
  Härtungsrolle sollte auf Werte zurückfallen, die nichts aktivieren, dessen sie nicht sicher
  sein kann, und der Bericht (L10) muss die übersprungenen Kontrollen als nicht anwendbar zeigen.
  Ein stilles Überspringen ist eine Lücke, und ein Default, der alles aktiviert, zerstört den
  ersten Host einer Plattform, die niemand getestet hat.
- **Rangfolge.** Ein mit `include_vars` geladener Wert schlug die Play-Variable (und im Test
  `group_vars`); nur `-e` schlug ihn. Das ist richtig für Flags, die Tatsachen der Plattform
  sind, und falsch für alles, was ein Anwender pro Host setzen können soll - das gehört nach
  `defaults/` (L07).

### Eine Rolle von außen testen

Den Code einer Rolle zu lesen sagt, was der Autor meinte. Ob Level 1 die Level-2-Tasks wirklich
überspringt und ob eine ausgenommene Kontrolle wirklich übersprungen wird, zeigt der Lauf. Ein
Lauf mit `--check` (L02) ändert nichts und lässt sich daher mit verschiedenen Eingaben
wiederholen, und der JSON-Callback macht das Ergebnis zu Daten: ein Dokument mit pro Task und Host
`skipped`, einem `skip_reason` und der `false_condition` (gemessen). Dieser Leser gibt den Zustand
jedes Tasks aus:

```python
import json, sys

text = sys.stdin.read()
data = json.loads(text[text.index("{"):])
for play in data["plays"]:
    for task in play["tasks"]:
        for host, result in task["hosts"].items():
            state = "skipped" if result.get("skipped") else "ran"
            print(f'{host}: {state:8} {task["task"]["name"]}')
```

Speichere ihn als `ran.py` und füttere ihn mit der Demo des ersten Konzepts, einmal pro Level:

```bash
ANSIBLE_STDOUT_CALLBACK=ansible.posix.json ansible-playbook profile.yml -l debian --check -e '{"lesson11_level": 1}' | python3 ran.py
ANSIBLE_STDOUT_CALLBACK=ansible.posix.json ansible-playbook profile.yml -l debian --check -e '{"lesson11_level": 2}' | python3 ran.py
```

```text
debian: ran      Make sure the demo directory exists
debian: ran      Refuse levels the role does not know
debian: ran      Demo-notice | Level 1 baseline
debian: skipped  Demo-strict | Strict settings file
debian: skipped  Demo-strict | Strict marker file
```

Das ist die Ausgabe für Level 1; bei Level 2 steht in jeder Zeile `ran`. Drei Folgerungen. Die
**Task-Namen sind eine Schnittstelle**: Der Test findet eine Kontrolle über ihren Namen, eine
Konvention, die die Id der Kontrolle an den Anfang jedes Task-Namens setzt, macht die Auswahl
mechanisch, und ein Task umzubenennen ist ein Bruch. Ein Task mit **Schleife** ist ein Eintrag:
Als ein Umbau der Demo ihre Dateien in einem Task mit Schleife schrieb, erschienen die
übersprungenen Elemente nur in den `results` des Tasks (jedes mit einem `skip_reason`), und der
Task selbst war nicht als übersprungen markiert - ein Task pro Kontrolle hält das Ergebnis
lesbar. Und `--list-tasks` ist kein Ersatz: Es listet jeden Task, auch die strengen auf Level 1,
weil es `when` nicht auswertet (getestet). Es zeigt Struktur, nicht Verhalten.

Dieselbe Idee belegt einen Umbau. Angenommen, du strukturierst eine Rolle um und willst dasselbe
Verhalten. Erzwinge mit der alten Version und lasse dann die neue mit `--check --diff` laufen:
`changed=0` heißt, dass die Hosts schon haben, was der neue Code verlangt. In einem Test ergab ein
Umbau der Demo auf eine Schleife `changed=0`, und ein Umbau, der einen Dateimodus änderte,
`changed=1` mit den beiden Modi im Diff. Der Beleg deckt nur ab, was der neue Code verwaltet. Hat
er eine Kontrolle fallen lassen, merkt es niemand; lass es auch andersherum laufen, die alte
Version in `--check`, nachdem die neue erzwungen hat, und die fallen gelassene Kontrolle erscheint
als Änderung (getestet). Ein zweiter Lauf mit `changed=0` (L00) und die Checks der früheren
Übungen, die 4.03 als Regressionstests ausführt, sind dasselbe Sicherheitsnetz.

## CIS-Hintergrund

Die Level (L01) sind der Grund für das Profil: Level 1 ist die Baseline, die keinen Dienst
brechen soll, Level 2 kauft Schutz mit Kosten, etwa mit mehr Auditing, als jemand liest (L09). Im
[Kontrollkatalog](../../cis/controls.yml) ist 6.3, der auditd-Abschnitt, der Level-2-Inhalt, den
der Katalog beiden Übungen zuordnet; 5.3.3 (Passwortqualität), 5.4.1 (Passwortalterung) sowie
5.4.2 und 5.4.3 (Konten, Shell-Umgebung) sind die Level-1-Kontrollen, die 4.03 auf jeder
Plattform zusammenführt. Wie das Level gewählt wird, steht nicht im Benchmark; das entscheidet
die Rolle.

Eine Empfehlung kann für einen Dienst ungeeignet sein, und eine dokumentierte Ausnahme ist der
Weg, wie eine Organisation zeigt, dass sie bewusst entschieden hat - was ein Auditor sehen will.
Drei Eigenschaften machen sie vertretbar: eine Begründung, eine Person, die das Risiko
akzeptiert hat, und ein Ende. Das Ende hat einen Preis: Eine Ausnahme, die abläuft, kann am Tag
selbst eine Pipeline stoppen, was der Zweck ist, und ein Grund, vorher zu warnen (der Bonus von
4.02). In einem Bericht (L10) zählt eine ausgenommene Kontrolle weder als konform noch als
Fehler; sie wird mit Begründung und Datum aufgeführt.

Plattformlücken sind Ausnahmen, die die Plattform entscheidet, nicht eine Person. 5.3.3 braucht
ein Modul für die Passwortqualität, und das Alpine-Target hat keins (L08). Die Rolle hält die
Lücke in den Plattformdaten mit der kompensierenden Maßnahme fest, und der Bericht zeigt sie als
nicht anwendbar, statt sie stillschweigend durchzuwinken.

## Plattformunterschiede

Die Plattformdaten einer Rolle werden über Facts gewählt, und die Facts unterscheiden sich genau
dort, wo ein versionsspezifischer Dateiname nützlich oder nutzlos wäre. Gemessen auf den Targets
des Labs (die Werte ändern sich, wenn ein Image neu gebaut wird):

| os_family | Hosts | `distribution` | `distribution_major_version` | Spezifischster Dateiname |
|---|---|---|---|---|
| Debian | debian, ubuntu | Debian, Ubuntu | 13, 26 | `Debian-13.yml`, `Ubuntu-26.yml` |
| RedHat | rocky, alma, fedora | Rocky, AlmaLinux, Fedora | 10, 10, 44 | `Rocky-10.yml`, `AlmaLinux-10.yml`, `Fedora-44.yml` |
| Suse | opensuse | `openSUSE Leap` (mit Leerzeichen) | 16 | `openSUSE Leap-16.yml` |
| Alpine | alpine | Alpine | 3 (die Version ist 3.24.3) | `Alpine-3.yml`, passt auf jede 3.x |
| Archlinux | arch | Archlinux | 20261101 (ein Datum) | keiner, der hält |

Ubuntu gehört zur Debian-Familie, eine Familiendatei bedient also beide. Die Hauptversion ist ein
String (mit dem Fact auf dem Session-Host getestet): Vergleiche sie mit `| int`, wie im ersten
Konzept. Der Name mit Leerzeichen funktioniert in `first_found` (mit einer Datei dieses Namens
getestet), ist aber in einem Repository unhandlich; die Familiendatei `Suse.yml` deckt ihn ab.
Arch ist rollierend, seine „Hauptversion“ ist also das Datum des Images, und eine
versionsspezifische Datei dafür würde nie wieder passen: Nimm dort die Distributions- oder die
Familiendatei.

### In den Lab-Containern

- Die Facts kommen aus den eigenen Release-Dateien jedes Images, ein neu gebautes Image kann also
  andere Versionen zeigen als die Tabelle. Die Playbooks, die Demo-Rolle, die Datendateien und
  `ran.py` bleiben auf dem Control Node, wo du `ansible-playbook` ausführst; `profile.yml`
  schreibt unter `/tmp/lesson11` auf den Targets und braucht 0.02 (Python auf Alpine), die
  anderen Plays benutzen `debian` oder nur `debug`.
- Entferne die Demo-Dateien mit `ansible targets -m ansible.builtin.file -a 'path=/tmp/lesson11
  state=absent'` und auf dem Control Node mit `rm -rf /tmp/lesson11`.

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| `'>=' not supported between instances of '..Str' and 'int'` | der Wert kam aus `-e name=value` und ist ein String | mit `\| int` vergleichen, oder JSON übergeben |
| Level 3 wirkt als Level 2, `l2` als Level 1 | `>= 2` ist für 3 wahr, und `'l2' \| int` ist 0 | das Level mit `assert` prüfen, bevor etwas geändert wird |
| Nach einem Lauf auf niedrigerem Level sind die strengeren Dateien noch da | ein Profil wählt, was anzuwenden ist, es macht nichts rückgängig | Entfernen-Tasks oder ein frischer Host |
| Die Tasks nach dem ersten in einem Block werden unerwartet übersprungen | das `when` des Blocks wird pro Task ausgewertet, und ein Task darin hat seine Eingabe geändert | die Eingaben der Bedingung aus dem Block heraushalten |
| `strptime() argument 1 must be str, not ..Date` | ein unquotiertes `2027-01-31` ist ein YAML-Datumsobjekt | Daten in den Daten quotieren, oder vor `to_datetime` in einen String konvertieren |
| `time data '..' does not match format` | das Datum ist in einem anderen Format geschrieben | ein dokumentiertes Format und eine lesbare Meldung, wenn es nicht passt |
| Eine Ausnahme endet einen Tag zu früh | `to_datetime` liefert Mitternacht, *heute* liegt also schon hinter `now()` | festlegen, was `until` bedeutet, und entsprechend vergleichen |
| Eine Ausnahme bewirkt nichts | die Id ist falsch geschrieben und passt nie | Ids gegen die Liste bekannter Kontrollen prüfen (`choices` oder `assert`) |
| Die Spezifikation besteht, aber der Task scheitert an einem String oder Datum | `argument_specs` prüft, es konvertiert nicht | im Task konvertieren |
| Ein Flag aus der Plattformdatei lässt sich in `group_vars` nicht ändern | `include_vars` schlägt Play- und Inventory-Variablen; nur `-e` gewinnt | überschreibbare Werte gehören nach `defaults/` |
| `Archlinux-20261101.yml` passt nie wieder | die Hauptversion eines rollierenden Systems ist ein Datum | die Distributions- oder die Familiendatei nehmen |
| Der Test sagt, ein Task mit Schleife `ran`, obwohl Elemente übersprungen wurden | der JSON-Callback hat einen Eintrag pro Task, übersprungene Elemente stehen in `results` | ein Task pro Kontrolle, oder `results` lesen |

## Übungen

| Übung | Was diese Lektion vorbereitet |
|---|---|
| [4.02](../../exercises/stage4-advanced/4.02-profiles-and-exceptions/README.de.md) | ein Profil als geprüfter Wert, `when` an Blöcken, Ausnahmen als Datensätze mit Begründung und Enddatum, `to_datetime` und `now()`, Prüfung vor der ersten Änderung, übersprungene Tasks aus dem JSON-Callback lesen |
| [4.03](../../exercises/stage4-advanced/4.03-data-driven-multi-platform-role/README.de.md) | Fähigkeits-Flags statt Systembedingungen, eine Datendatei oder Schichten, ein konservativer Fallback, die Rangfolge geladener Daten, Regressions- und Umbau-Beleg mit `--check` |

Starte eine Übung mit `lab start <id>`; `lab show <id>` gibt ihre README aus.

## Selbstkontrolle

1. `-e level=2` ist gesetzt, und ein Task hat `when: level >= 2`. Er scheitert, obwohl
   `-e '{"level": 2}'` funktioniert. Warum, und was ist die Lösung?

   <details><summary>Antwort</summary>

   Ein Wert aus `key=value` auf der Kommandozeile ist ein String, und Jinja vergleicht keinen
   String mit einer Ganzzahl; JSON liefert eine echte Ganzzahl. Vergleiche mit
   `level | int >= 2`, das mit beiden funktioniert, und prüfe den Wert, damit `l2` oder `3` den
   Play stoppt.

   </details>

2. Ein Host wurde auf Level 2 gehärtet. Du führst die Rolle erneut auf Level 1 aus. Was passiert
   mit den Level-2-Einstellungen, und was heißt das für den Rückweg?

   <details><summary>Antwort</summary>

   Nichts: Der Lauf auf Level 1 ist `changed=0`, und die strengen Dateien bleiben, weil ein
   Profil nur wählt, was anzuwenden ist. Zurückzugehen braucht ausdrückliche Entfernen-Tasks
   (oder einen frischen Host), und die Dokumentation der Rolle sollte sagen, dass ein niedrigeres
   Level ein höheres nicht rückgängig macht.

   </details>

3. Ein Block hat `when: flag | default(true)`, und sein erster Task setzt `flag: false` mit
   `set_fact`. Was tun die übrigen Tasks des Blocks?

   <details><summary>Antwort</summary>

   Sie werden übersprungen. Das `when` eines Blocks wird an jeden Task weitergegeben und für jeden
   ausgewertet, die geänderte Variable sehen also die Tasks nach dem ersten. Halte die Eingaben
   einer Bedingung aus dem Block heraus, den sie bewacht.

   </details>

4. Eine Ausnahme hat `until: 2026-11-06` als unquotiertes Datum und wird um 14:00 an diesem Tag
   mit `to_datetime` und `now()` geprüft. Nenne zwei Probleme.

   <details><summary>Antwort</summary>

   Ein unquotiertes Datum ist ein YAML-Datumsobjekt, und `to_datetime` scheitert daran, wenn es
   nicht zuerst in einen String konvertiert wird. Wird es konvertiert, ist das Ergebnis
   Mitternacht zu Beginn des Tages, die Ausnahme gilt um 14:00 also schon als abgelaufen.
   Entscheide, ob `until` der letzte gültige oder der erste ungültige Tag ist, und vergleiche
   entsprechend.

   </details>

5. Was davon kann `argument_specs` abfangen: ein Level 3, eine falsch geschriebene Kontroll-Id,
   ein leeres `why`, ein Datum in der Vergangenheit, ein Datum in der Form `31.01.2027`? Was
   deckt den Rest ab?

   <details><summary>Antwort</summary>

   Das Level (mit `choices`) und die falsch geschriebene Id (mit `choices` an der Option des
   Elements); außerdem fehlende Schlüssel und unbekannte Optionsnamen. Nicht abgefangen werden
   ein leerer Text, ein Datum in der Vergangenheit und ein falsches Datumsformat, weil sie die
   Form prüft, nicht den Inhalt, und nichts konvertiert. Diese Regeln gehören in `assert`-Tasks
   in einem Preflight, vor der ersten Änderung.

   </details>

6. Ein in einer Plattformdatei definiertes Flag, die mit `include_vars` geladen wird, lässt sich in
   `group_vars` nicht ändern. Warum, und was tust du, wenn Anwender es können sollen?

   <details><summary>Antwort</summary>

   Mit `include_vars` geladene Variablen haben eine höhere Rangfolge als Play- und
   Inventory-Variablen; nur `-e` ist stärker. Ein Wert, den Anwender pro Host setzen können
   wollen, ist eine Schnittstelle und gehört nach `defaults/` der Rolle. Die Plattformdatei ist
   für Tatsachen der Plattform.

   </details>

7. Eine Plattform, die keine Datendatei kennt, landet bei `default.yml`. Was soll darin stehen,
   und was muss der Bericht zeigen?

   <details><summary>Antwort</summary>

   Konservative Werte: Nichts wird aktiviert, dessen Funktion dort nicht sicher ist, damit der
   erste Host einer ungetesteten Plattform nicht kaputtgeht. Die dadurch übersprungenen
   Kontrollen müssen im Bericht als nicht anwendbar (L10) mit Begründung erscheinen; ein stilles
   Überspringen sähe wie Compliance aus.

   </details>

8. Du hast eine Rolle umgeschrieben. Wie zeigst du, dass sich das Verhalten nicht geändert hat,
   was sieht das nicht, und warum ist `--list-tasks` dafür nicht das Werkzeug?

   <details><summary>Antwort</summary>

   Erzwinge mit der alten Version und lasse dann die neue mit `--check --diff` laufen:
   `changed=0` heißt, die Hosts entsprechen schon dem neuen Code. Eine Kontrolle, die der neue
   Code fallen ließ, sieht das nicht, lass danach also auch die alte Version in `--check`
   laufen. `--list-tasks` wertet `when` nicht aus, listet also jeden Task und zeigt Struktur,
   nicht, was tatsächlich läuft.

   </details>

## Weiterführendes

- [Role argument validation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html) - `meta/argument_specs.yml`, Typen, `choices` und verschachtelte `options`
- [Conditionals](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_conditionals.html) und [Blocks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html) - `when` und was ein Block an seine Tasks weitergibt
- [Using variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html) - die vollständige Rangfolge
- [`ansible.builtin.include_vars`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/include_vars_module.html) - Datendateien zur Laufzeit laden
- [`ansible.builtin.first_found`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/first_found_lookup.html) - der Lookup hinter der Fallback-Kette
- [`ansible.builtin.assert`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/assert_module.html) - `that`, `fail_msg` und `quiet`
- [Using filters to manipulate data](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html) - `to_datetime`, `map` und `type_debug`
- [`ansible.posix.json` callback](https://docs.ansible.com/ansible/latest/collections/ansible/posix/json_callback.html) - der Callback hinter dem Vertragstest
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: `assert`, capability flag, exception,
  `first_found`, `include_vars`, Level 1 / Level 2, platform data, profile (CIS)
