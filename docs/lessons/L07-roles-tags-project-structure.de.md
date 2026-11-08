# L07 - Rollen, Tags und Projektstruktur: eine Baseline, viele Schalter

*[English](L07-roles-tags-project-structure.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 3.01 | 1.1.1, 1.5, 1.6, 2.1, 2.2, 2.4, 3.3, 5.1, 5.2, 7.1 | ~35 Min. | L02, L04 |

Eine Härtungs-Baseline besteht aus Hunderten von Tasks. Auf ein Playbook pro Thema verteilt,
werden sie kopiert, laufen auseinander und lassen sich nur als Ganzes ausführen. Eine Rolle gibt
ihnen ein Zuhause mit festem Aufbau, sichtbarer Schnittstelle und Schaltern, um einen Teil
auszuführen. Diese Lektion behandelt, woraus eine Rolle besteht, welche ihrer Werte ein Benutzer
ändern darf, wie man ihre Tasks aufteilt und auswählt und wie `ansible-lint` das Ergebnis in Form
hält.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] die Verzeichnisse einer Rolle aufzählen und sagen, welche Ansible von selbst lädt
- [ ] entscheiden, ob ein Wert nach `defaults/` oder `vars/` gehört, und vorhersagen, welche Ebene gewinnt
- [ ] erklären, warum Rollenvariablen und registrierte Ergebnisse ein Präfix brauchen
- [ ] zwischen `import_tasks` und `include_tasks` wählen und den Unterschied in `--list-tasks` lesen
- [ ] Tasks mit Tags auswählen und die Tasks, von denen andere abhängen, mit `always` markieren
- [ ] sagen, was jedes `ansible-lint`-Profil hinzufügt, und eine Verletzung lesen
- [ ] erklären, wie man zeigt, dass ein Refactoring das Verhalten nicht verändert hat

## Theorie

### Eine Rolle ist ein Verzeichnis mit einem Vertrag

Das Problem: Ein Playbook, das über eine Bildschirmseite hinauswächst, vermischt drei Dinge - was
zu tun ist, welche Werte gelten und welche Dateien erzeugt werden. Kopierst du es in ein zweites
Projekt, pflegst du zwei Versionen. Eine Rolle trennt sie per **Konvention**: Ansible sucht
innerhalb eines Verzeichnisses feste Namen und lädt, was es findet, der Aufbau ist also die
Schnittstelle.

| Pfad in der Rolle | Geladen | Typischer Inhalt |
|---|---|---|
| `tasks/main.yml` | immer, der Einstiegspunkt | Tasks oder Importe weiterer Task-Dateien |
| `defaults/main.yml` | immer | Werte, die ein Benutzer ändern darf; niedrigste Rangfolge |
| `vars/main.yml` | immer | interne Daten; hohe Rangfolge |
| `handlers/main.yml` | immer | Handler, die die Tasks benachrichtigen |
| `meta/main.yml` | immer | Galaxy-Metadaten, Rollenabhängigkeiten |
| `templates/`, `files/` | bei Bedarf | werden von `template` und `copy` per *Name* gefunden |

`ansible-galaxy role init <name>` schreibt ein Grundgerüst: `README.md`, `defaults/`,
`handlers/`, `meta/`, `tasks/`, `tests/` und `vars/` (geprüft mit ansible-core 2.21; ohne
`templates/` und `files/`). Leere Dateien sind in Ordnung: Eine Rolle, deren `defaults/main.yml`
leer ist, nur `---` enthält oder nur einen Kommentar, läuft trotzdem.

Die Beispiele dieser Lektion verwenden eine kleine Demo-Rolle, `demo_stamp`. Sie erzeugt eine
Datei, deren Vorlage vom Host abhängt, und berichtet, was sie getan hat. Baue sie in einem
Scratch-Verzeichnis auf dem Control-Node (das Skript ist lang, weil es die Rolle ist; lies die
Kommentare, nicht jede Zeile):

```bash
mkdir -p /tmp/lesson07/roles/demo_stamp/{defaults,vars,tasks,handlers,templates}
cd /tmp/lesson07/roles/demo_stamp

# Werte, die ein Benutzer ändern darf
cat > defaults/main.yml <<'EOF'
---
demo_stamp_path: /tmp/lesson-stamp.conf
demo_stamp_mode: "0644"
demo_stamp_note: baseline
demo_stamp_level: 1
EOF

# interne Daten
cat > vars/main.yml <<'EOF'
---
demo_stamp_header: managed by the demo_stamp role
EOF

# drei Templates: allgemein, eines für eine ganze Familie, eines für eine Distribution
cat > templates/stamp.conf.j2 <<'EOF'
header={{ demo_stamp_header }}
note={{ demo_stamp_note }}
EOF
cat > templates/stamp.Debian.conf.j2 <<'EOF'
header={{ demo_stamp_header }}
note={{ demo_stamp_note }}
family=Debian
EOF
cat > templates/stamp.Fedora.conf.j2 <<'EOF'
header={{ demo_stamp_header }}
note={{ demo_stamp_note }}
distribution=Fedora
EOF

# der Einstiegspunkt
cat > tasks/main.yml <<'EOF'
---
- name: Pick the template for this host
  ansible.builtin.set_fact:
    demo_stamp_source: "{{ lookup('ansible.builtin.first_found', demo_stamp_candidates) }}"
  vars:
    demo_stamp_candidates:
      files:
        - "stamp.{{ ansible_facts.distribution }}.conf.j2"
        - "stamp.{{ ansible_facts.os_family }}.conf.j2"
        - stamp.conf.j2
      paths:
        - "{{ role_path }}/templates"
  tags: [always]

- name: Write the stamp
  ansible.builtin.template:
    src: "{{ demo_stamp_source }}"
    dest: "{{ demo_stamp_path }}"
    owner: root
    group: root
    mode: "{{ demo_stamp_mode }}"
  notify: Announce stamp change
  tags: [stamp]

- name: Report on the stamp
  ansible.builtin.import_tasks: report.yml
  tags: [report]

- name: Extras for the chosen level
  ansible.builtin.include_tasks: "level_{{ demo_stamp_level }}.yml"
  tags: [extras]
EOF

# die beiden Task-Dateien, die der Einstiegspunkt einbindet
cat > tasks/report.yml <<'EOF'
---
- name: Look at the stamp
  ansible.builtin.stat:
    path: "{{ demo_stamp_path }}"
  register: demo_stamp_stat

- name: Say which template was used
  ansible.builtin.debug:
    msg: "{{ demo_stamp_source | basename }} -> {{ demo_stamp_path }}, exists: {{ demo_stamp_stat.stat.exists }}"
EOF
for n in 1 2; do
cat > "tasks/level_$n.yml" <<EOF
---
- name: Extras of level $n
  ansible.builtin.debug:
    msg: "level $n extras"
EOF
done

# der Handler, den der Stamp-Task benachrichtigt
cat > handlers/main.yml <<'EOF'
---
- name: Announce stamp change
  ansible.builtin.debug:
    msg: the stamp changed
EOF
```

Zwei Details des Einstiegspunkts sind später wichtig. Der erste Task wählt mit `first_found` ein
Template: Das Lookup geht eine Liste von Dateinamen durch, das Spezifischste zuerst, und liefert
den ersten, der in `paths` existiert. Die Kette lautet hier *Distribution*, dann *Familie*, dann
eine allgemeine Datei; existiert kein Kandidat, scheitert das Lookup mit `No file was found when
using first_found`, also gehört ein allgemeiner Eintrag ans Ende. Und dieser Task trägt das Tag
`always` - warum, erklärt das vierte Konzept.

Eine Rolle tut nichts, bis ein Play sie verwendet:

```yaml
- name: Apply the demo role
  hosts: targets
  become: true
  roles:
    - role: demo_stamp
```

Speichere es als `/tmp/lesson07/site.yml` und führe es zweimal aus:

```bash
cd /tmp/lesson07
ansible-playbook site.yml
ansible-playbook site.yml
```

Der erste Lauf ändert die Datei auf jedem Host und startet den Handler; der zweite meldet
`changed=0` und keinen Handler. Die Task-Namen tragen den Rollennamen (`demo_stamp : Write the
stamp`), daran erkennst du in der Ausgabe, zu welcher Rolle ein Task gehört.

**Wo Ansible eine Rolle sucht.** Die Meldung "not found" listet die durchsuchten Orte: ein
Verzeichnis `roles/` neben dem Playbook, die Verzeichnisse aus `roles_path` (im Lab
`/lab/work/roles:/lab/ansible/roles`) und das Verzeichnis des Playbooks selbst. Das **aktuelle
Arbeitsverzeichnis** wird ebenfalls durchsucht, obwohl die Meldung es nicht aufführt; gibt es
denselben Namen in `roles_path` und im Arbeitsverzeichnis, gewinnt `roles_path` (gemessen). Die
Regel mit dem Arbeitsverzeichnis schlägt im Lab zu: Mit `/lab` als Arbeitsverzeichnis kann
`role: cis` zum Katalogverzeichnis `cis/` aufgelöst werden, wenn in `roles_path` nichts namens
`cis` existiert. Arbeite aus dem Projektverzeichnis, halte Rollen unter einem einzigen `roles/`
und lies die Liste in der Fehlermeldung, wenn eine Rolle nicht gefunden wird.

**Drei Arten, eine Rolle aufzurufen.** `roles:` ist statisch und hat einen festen Platz im Play:
`pre_tasks`, dann `roles:`, dann `tasks:` - auch wenn im YAML `tasks:` zuerst steht.
`ansible.builtin.import_role` ist ebenfalls statisch, läuft aber dort, wo es zwischen den Tasks
steht, und `ansible.builtin.include_role` ist dynamisch: Es wird aufgelöst, wenn der Task
erreicht wird. `--list-tasks` zeigt die Tasks von `roles:` und von `import_role`, bei
`include_role` nur das Include selbst. Eine Rolle, die in `roles:` zweimal steht, läuft einmal -
außer die Parameter unterscheiden sich oder `meta/main.yml` setzt `allow_duplicates: true`.

### `defaults/` und `vars/`: eine Schnittstelle und interne Daten

Das Problem: Eine Rolle wird von Leuten benutzt, die sie nicht geschrieben haben. Sie brauchen
eine kurze Liste von Werten, die sie ändern dürfen, und die Plattformfakten und internen
Konstanten sollen so bleiben, wie der Autor sie gesetzt hat. Die beiden Verzeichnisse bilden genau
das ab, über die **Rangfolge**. Von schwächer zu stärker, für das, was diese Lektion braucht:

| Ebene | Schlägt |
|---|---|
| `defaults/main.yml` der Rolle | nichts; jede andere Ebene überschreibt sie |
| Inventar (`group_vars`, `host_vars`) | die Defaults der Rolle |
| `vars:` des Plays | die Defaults der Rolle und das Inventar |
| `vars/main.yml` der Rolle | das Play und das Inventar |
| `-e name=value` | alles |

Die vollständige Liste hat mehr Ebenen (L04 enthält die Kurzfassung). Prüfe es mit der
Demo-Rolle. Das Play setzt einen Default und eine Rollenvariable:

```yaml
- name: Which layer wins, a default or a role variable?
  hosts: targets
  become: true
  vars:
    demo_stamp_note: set by the play
    demo_stamp_header: set by the play
  roles:
    - role: demo_stamp
  post_tasks:
    - name: Read the stamp back
      ansible.builtin.command: cat /tmp/lesson-stamp.conf
      register: lesson_stamp
      changed_when: false
      when: not ansible_check_mode
    - name: Show it
      ansible.builtin.debug:
        var: lesson_stamp.stdout_lines
      when: not ansible_check_mode
```

Speichere es als `/tmp/lesson07/override.yml` und führe `ansible-playbook override.yml` in diesem
Verzeichnis aus. Die Datei enthält danach `note=set by the play` - das Play hat den Default
geschlagen - und weiterhin `header=managed by the demo_stamp role`: Das Play hat gegen
`vars/main.yml` verloren. Ergänze `-e demo_stamp_header=cli`, und der Header ändert sich, denn nur
die Kommandozeile schlägt das `vars/` einer Rolle. Die Stamp-Datei behält außerdem auf Debian und
Ubuntu ihre Debian-Zeile, der erzeugte Text unterscheidet sich also je nach Host.

Daraus folgt die Faustregel: **Wenn ein Benutzer einen anderen Wert wollen könnte, ist es ein
Default.** Ein Wert in `vars/` lässt sich weder aus dem Inventar noch aus dem Play überschreiben -
richtig für einen Dienstnamen, der eine Tatsache der Plattform ist, falsch für einen Pfad, ein
Limit oder eine Paketliste.

**Jeder Name bekommt ein Präfix.** Variablen aus `defaults/` und `vars/` sind nicht privat. Sie
leben im Namensraum des ganzen Plays: `defaults/` und `vars/` einer Rolle sind für jeden Task nach
der Rolle sichtbar, selbst wenn die Tasks der Rolle per `when` übersprungen wurden (gemessen). Zwei
Rollen, die beide `owner` definieren, überschreiben sich gegenseitig, und eine Rollenvariable kann
unbemerkt eine ersetzen, die der Play-Autor schon hatte. Darum versieht eine Rolle alles, was ihr
gehört - Defaults, Vars, `register`, `set_fact` - mit ihrem eigenen Namen (`demo_stamp_...`).
`ansible-lint` erzwingt das mit der Regel `var-naming[no-role-prefix]`.

### `import_tasks` und `include_tasks`: statisch und dynamisch

Das Problem: Die `tasks/main.yml` einer Rolle soll lesbar bleiben, deshalb ziehen die Tasks in
eigene Dateien um, eine pro Thema. Zwei Module binden eine Datei ein, und sie unterscheiden sich
darin, **wann**:

- `import_tasks` ist **statisch**. Die Datei wird beim Parsen des Playbooks gelesen, ihre Tasks
  werden Teil des Plays, und Tags und `when` des Imports werden auf jeden Task darin kopiert.
- `include_tasks` ist **dynamisch**. Die Datei wird gelesen, wenn der Task erreicht wird, ihr Name
  darf also eine Variable enthalten und das Include darf eine `loop` haben. Tags und `when` gelten
  für das Include, nicht für die Tasks darin.

Den Unterschied siehst du, ohne etwas auszuführen:

```bash
cd /tmp/lesson07
ansible-playbook site.yml --list-tasks
ansible-playbook site.yml --list-tags
ansible-playbook site.yml --tags extras -e demo_stamp_level=2
```

`--list-tasks` zeigt die beiden Tasks aus `report.yml` einzeln, beide mit dem Tag `report`, aber
nur eine Zeile für das Include - die Tasks aus `level_1.yml` oder `level_2.yml` gibt es erst, wenn
das Play läuft. Der dritte Befehl wählt die zweite Level-Datei per Variable. Er zeigt auch, dass
das Tag des Includes am Include endet: Die Tasks darin tragen kein Tag `extras`, mit `--tags
extras` läuft also das Include, seine Tasks aber nicht. Entweder du taggst die Tasks in der Datei,
oder du schreibst das Include in der Langform mit `file:` und `apply:` (`apply: {tags:
[extras]}`), die die Tags an die eingebundenen Tasks weitergibt - gemessen: Mit `apply` laufen beide
Tasks der Datei unter `--tags extras`.

Weitere gemessene Folgen:

- Ein `when` an einem Import wird pro Task darin ausgewertet: Jeder Task erscheint als `skipping`.
- `loop` an `import_tasks` wird beim Laden abgelehnt: `You cannot use loops on 'import_tasks'
  statements. You should use 'include_tasks' instead.`
- Eine fehlende Datei hinter `import_tasks` lässt `--syntax-check` scheitern; hinter
  `include_tasks` besteht sie die Prüfung und scheitert erst, wenn der Task erreicht wird. Feste
  Namen sind sicherer.

Nimm `import_tasks` für eine feste Aufteilung einer Rolle in Dateien und `include_tasks`, wenn
Dateiname oder Wiederholung von Daten abhängen.

### Tags: auswählen, was läuft

Das Problem: Ein voller Lauf einer Härtungsrolle dauert Minuten und berührt alles, während die
Frage oft lautet "nur SSH" oder "alles außer der Firewall". **Tags** beschriften Tasks, Blöcke,
Importe, Rolleneinträge und Plays, und die Kommandozeile wählt nach Beschriftung: `--tags a,b`
führt nur Tasks aus, die eines davon tragen, `--skip-tags` führt alles andere aus, `--list-tags`
zeigt, was es gibt. Ein Tag an einem Block, einem Import oder einem Rolleneintrag wird von jedem
Task darin geerbt:

```yaml
- name: Tag the whole role
  hosts: targets
  become: true
  roles:
    - role: demo_stamp
      tags: [baseline]
```

Speichere es als `/tmp/lesson07/site_tag.yml`; `--tags baseline` führt nun die ganze Rolle aus,
und `--tags stamp` führt weiterhin nur ihren einen Task aus (plus den `always`-Task und das
Sammeln der Facts). So sollte der Entwurf aussehen: ein grobes Tag für die ganze Einheit und ein
feines Tag pro Thema, benannt nach dem, was ein Operator allein ausführen will.

Die scharfe Kante: **Mit `--tags` werden Tasks ohne passendes Tag übersprungen** - auch Tasks, von
denen andere abhängen. Zwei besondere Tags fangen das ab. `always` führt den Task aus, was auch
immer `--tags` sagt (nur `--skip-tags always` hält ihn auf); `never` macht das Gegenteil - der Task
läuft nur, wenn eines seiner anderen Tags ausdrücklich genannt wird. Was die Demo-Rolle bei
welcher Auswahl tut:

| Befehl | Was läuft |
|---|---|
| keine Option | alle Tasks |
| `--tags report` | der `always`-Task, dann die beiden Tasks von `report` |
| `--tags extras` | der `always`-Task, dann das Include selbst; nicht die Tasks darin |
| `--skip-tags stamp` | alles außer dem Schreiben der Datei |
| `--tags report --skip-tags always` | scheitert: `'demo_stamp_source' is undefined` |

Die letzte Zeile ist die Stolperfalle. Ohne `always` wird ein Task, der etwas für spätere Tasks
berechnet oder lädt, bei jeder `--tags`-Auswahl übersprungen, die ihn nicht nennt, und der erste
Task, der das Ergebnis nutzt, scheitert. Alles, was spätere Tasks brauchen, kommt unter `always`;
alles, was ein gefährliches Extra ist, unter `never` plus ein Tag, das du bewusst nennst.

`--list-tasks` beachtet die Auswahl: `--list-tasks --tags report` zeigt den `always`-Task und die
beiden Tasks von `report`, ohne etwas auszuführen - eine billige Möglichkeit zu sehen, was eine
Tag-Kombination tun wird, bevor sie einen Host berührt.

### Eine Rolle linten

Das Problem: YAML, das Ansible akzeptiert, kann trotzdem auf Weisen falsch sein, die erst spät
auffallen - ein Modus ohne Anführungszeichen, den YAML als Oktalzahl liest, ein Befehl, der bei
jedem Lauf `changed` meldet, eine Variable, die mit der einer anderen Rolle kollidiert.
`ansible-lint` liest Playbooks und Rollen und meldet solche Muster. Seine Regeln sind in
**Profilen** gruppiert, jedes schließt das vorherige ein, sodass du die Latte Schritt für Schritt
anheben kannst (`ansible-lint -P` listet sie mit allen Regeln auf):

| Profil | Was es hinzufügt (eine Auswahl) |
|---|---|
| `min` | der Inhalt lässt sich überhaupt laden: Syntaxfehler, nicht parsbare Dateien |
| `basic` | Formatierung und Idiome: `var-naming`, `name`, `yaml`, `role-name`, `schema`, `key-order`, keine veralteten Module |
| `moderate` | lesbare Namen: `name[casing]`, `name[template]`, `name[imperative]` |
| `safety` | Risiko vermeiden: `risky-file-permissions`, `latest`, `risky-shell-pipe` |
| `shared` | bereit zum Teilen: `no-changed-when`, `no-handler`, `meta-*`, `galaxy`, `max-tasks`, `unsafe-loop` |
| `production` | am strengsten: `fqcn`, `avoid-dot-notation`, `use-loop`, `single-entry-point`, `meta-no-dependencies` |

Eine absichtlich schlechte Rolle zeigt, was ein Lauf sagt. Die Rolle hat einen Default ohne
Präfix, ein Modul ohne Collection-Namen, einen Modus ohne Anführungszeichen, einen unbenannten
Task und ein `command`, das nie sagt, wann es etwas ändert:

```bash
mkdir -p /tmp/lesson07/roles/lintdemo/{tasks,defaults}
cd /tmp/lesson07
cat > roles/lintdemo/defaults/main.yml <<'EOF'
---
owner: root
EOF
cat > roles/lintdemo/tasks/main.yml <<'EOF'
---
- name: Write a file
  copy:
    dest: /tmp/lintdemo
    content: hi
    mode: 0644

- ansible.builtin.command: cat /tmp/lintdemo
  register: result

- name: Show who owns it
  ansible.builtin.debug:
    msg: "{{ owner }} {{ result.stdout }}"
EOF
ansible-lint --offline --profile basic --format pep8 roles/lintdemo
ansible-lint --offline --profile production --format pep8 roles/lintdemo
```

`basic` meldet vier Verletzungen, `production` sechs (gekürzt, ohne den Hinweis zur
Verzeichnis-Expansion, den `ansible-lint` bei einem Verzeichnis als Argument immer ausgibt):

```
roles/lintdemo/defaults/main.yml:2:1: var-naming[no-role-prefix]: Variables names from within roles should use lintdemo_ as a prefix. (vars: owner)
roles/lintdemo/tasks/main.yml:3:3: fqcn[action-core]: Use FQCN for builtin module actions (copy).
roles/lintdemo/tasks/main.yml:6: yaml[octal-values]: Forbidden implicit octal value "0644"
roles/lintdemo/tasks/main.yml:8: name[missing][/]: All tasks should be named.
roles/lintdemo/tasks/main.yml:8: no-changed-when: Commands should not change things if nothing needs doing.
roles/lintdemo/tasks/main.yml:8:13: var-naming[no-role-prefix]: Variables names from within roles should use lintdemo_ as a prefix. (register: result)
Failed: 6 failure(s), 0 warning(s) in 3 files processed of 3 encountered. Profile 'production' was required, but 'min' profile passed.
```

Lies eine Zeile als `Datei:Zeile:Spalte: regel[detail]: Meldung`. Der Regelname ist das, wonach
du in der Dokumentation suchst oder was du bewusst abschaltest; die letzte Zeile sagt, welches
Profil verlangt war und welches der Inhalt tatsächlich erreicht. Mit `basic` werden `fqcn` und
`no-changed-when` nicht gemeldet - sie gehören zu höheren Profilen, weshalb dieselbe Rolle eine
Stufe bestehen und die nächste verfehlen kann. Der Exit-Code ist `2`, solange etwas Fatales übrig
ist, eine Pipeline kann also daran ein Gate festmachen. Ohne `--profile` gelten alle Regeln.

Drei Details aus denselben Messungen:

- `--offline` hält `ansible-lint` davon ab, Galaxy zu erreichen. Das Repository hat eine
  `.ansible-lint`, die `offline: true` setzt; eine Rolle außerhalb des Repositorys, wie die
  Demo-Rolle, linten wir mit dem Schalter auf der Kommandozeile.
- `meta/main.yml` ist für eine lokale Rolle optional, und eine Datei mit nur `dependencies: []`
  besteht `production`, aber ein vorhandenes, unvollständiges `galaxy_info` wird geprüft:
  `galaxy_info: {}` scheitert mit `schema[meta]`. Gib ihm Name, Autor, Beschreibung, Lizenz,
  Mindestversion und Plattformen, oder lass den Schlüssel weg.
- Ein Rollenverzeichnis muss auf `^[a-z][a-z0-9_]*$` passen: `role-name` beanstandet ein
  Verzeichnis namens `Bad-Name` schon bei `basic`. Kleinbuchstaben, Ziffern und Unterstriche, mit
  einem Buchstaben am Anfang, sind sicher.

Lint prüft die Form, nicht das Verhalten. Bei einem **Refactoring** - Tasks in eine Rolle
verschieben, ohne zu ändern, was sie tun - ist der Beleg verhaltensbezogen: Wende die alten
Playbooks auf frische Hosts an, halte fest, was die Checks sagen, wende die Rolle auf frische Hosts
an und vergleiche. Ein zweiter Lauf mit `changed=0` und ein sauberes `--check --diff` zeigen, dass
die Rolle idempotent ist. Frameworks wie Molecule automatisieren dieselbe Schleife: auf eine frische
Instanz anwenden, prüfen, noch einmal anwenden.

## CIS-Hintergrund

Alle zehn Abschnitte des [Kontrollkatalogs](../../cis/controls.yml) im Kopf führen diese Übung auf,
weil sie frühere Arbeit sammelt: Banner, Kernelmodule, sysctl-Werte, Dienste, cron und
Dateirechte, SSH, sudo und Kontendateien. Der Benchmark selbst sagt nichts darüber, wie
Automatisierung aufgebaut wird; die Struktur ist deine Sache, und der Benchmark prägt drei
Entscheidungen.

Erstens die **Nachvollziehbarkeit**: Ein Auditor fragt, welcher Task eine Empfehlung umsetzt, und
ein Operator will genau diesen Teil neu ausführen. Tags, die die Themen des Benchmarks spiegeln,
beantworten beides ohne Tabelle. Zweitens das **Profil**: Level 1 und Level 2 unterscheiden sich
darin, wie viel eine Rolle tut, also ist das Level ein Wert in `defaults/`, den Tasks und Importe
mit `when` prüfen (L01 hat ihn von der Kommandozeile benutzt; L11 zeigt, wie eine Rolle ihn
beachtet und Ausnahmen festhält). Drittens der **Besitz**: Eine Rolle ist ein prüfbares,
versioniertes Artefakt. Eine Härtungsänderung, die als Diff eines Verzeichnisses ankommt, lässt sich
lesen, auf frischen Hosts testen und zurückrollen; dieselbe Änderung, über viele Playbooks
verstreut, nicht.

Ein Preis, den man nennen sollte: Eine Baseline-Rolle wird auf jeden Host angewendet, ihre Defaults
sind also Entscheidungen für jeden Host. Prüfe `defaults/` wie eine Sicherheitsrichtlinie, nicht
wie Konfiguration.

## Plattformunterschiede

Die Mechanik einer Rolle - Aufbau, Rangfolge, Importe, Tags, Lint - läuft auf dem Control-Node und
ist für alle acht Targets gleich. Die Plattformen unterscheiden sich in den Daten, nach denen eine
Rolle auswählt. Die Demo-Rolle wählt ein Template mit der Kette *Distribution, dann Familie, dann
allgemein*:

| os_family | Hosts | Fakt `distribution` | Template, das die Demo-Rolle wählt |
|---|---|---|---|
| Debian | debian, ubuntu | Debian, Ubuntu | `stamp.Debian.conf.j2` für beide: debian passt über die Distribution, ubuntu fällt auf die Familie durch |
| RedHat | rocky, alma, fedora | Rocky, AlmaLinux, Fedora | fedora: `stamp.Fedora.conf.j2`; rocky und alma: die allgemeine Datei |
| Suse | opensuse | openSUSE Leap | die allgemeine Datei |
| Alpine | alpine | Alpine | die allgemeine Datei |
| Archlinux | arch | Archlinux | die allgemeine Datei |

Die Tabelle ist das Ergebnis des Lookups, angewendet auf die Werte der zweiten Spalte und berechnet
mit demselben `first_found`-Ausdruck; die `distribution`-Werte sind die, die L04 auf den Lab-Hosts
gemessen hat. Beachte das Leerzeichen in `openSUSE Leap`: Ein daraus gebauter Dateiname existiert
schlicht nicht, und das Lookup geht zum nächsten Kandidaten. Halte die allgemeine Datei am Ende -
ohne sie lässt eine Plattform, an die du nicht gedacht hast, den Task scheitern.

### In den Lab-Containern

- Die Demo-Rolle liegt in `/tmp/lesson07` auf dem **Control-Node**, außerhalb von `/lab/work`, und
  kann daher nicht mit den Rollen der Übungen kollidieren (3.01 startet von einem Grundgerüst, das
  `lab start 3.01` in `/lab/work/roles/cis` anlegt). Die `ansible.cfg` des Labs setzt `roles_path`
  auf `/lab/work/roles:/lab/ansible/roles`; das Verzeichnis `roles/` neben dem Playbook wird
  ebenfalls durchsucht.
- Das Play läuft auf allen Hosts von `targets`; alpine braucht vorher Python aus Übung 0.02, weil
  das Play Facts sammelt.
- Die Stamp-Datei landet im `/tmp` jedes Targets. Entferne sie mit
  `ansible targets -b -m ansible.builtin.file -a "path=/tmp/lesson-stamp.conf state=absent"` oder
  mit `./lab.sh reset <host>` (`.\lab.ps1 reset <host>` unter Windows).
- Führe `ansible-lint` auf dem Control-Node aus, wo die gepinnte Version installiert ist; dieselbe
  Version läuft im CI-Gate des Repositorys.

## Stolperfallen

| Symptom | Ursache | Behebung |
|---|---|---|
| `The role 'x' was not found in: ...` | Name oder Ort falsch; die Meldung listet die durchsuchten Verzeichnisse | Namen korrigieren, die Rolle in `roles_path` oder in `roles/` neben das Playbook legen |
| Eine Rolle wird gefunden, obwohl sie nicht in `roles_path` liegt | das aktuelle Arbeitsverzeichnis wird mit durchsucht und steht nicht in der Meldung | aus dem Projektverzeichnis arbeiten; Rollen in einem `roles/` halten; kein Verzeichnis wie eine Rolle benennen |
| Eine Play-Variable oder ein Inventarwert wirkt bei einer Rolle nicht | der Wert steht im `vars/` der Rolle, das beides schlägt | Werte, die Benutzer ändern dürfen, nach `defaults/` verschieben; einen `vars/`-Wert nur mit `-e` überschreiben |
| `Finalization of task args ... 'demo_stamp_source' is undefined` unter `--tags` | der Task, der die Variable setzt, trägt nicht das Tag `always` | Vorbereitungs-Tasks mit `always` taggen |
| `--tags extras` führt das Include aus, aber nicht die Tasks in seiner Datei | bei `include_tasks` bleibt das Tag am Include | die inneren Tasks taggen, `apply: {tags: [...]}` nutzen oder `import_tasks` verwenden |
| `You cannot use loops on 'import_tasks' statements.` | Importe werden beim Parsen aufgelöst, bevor es eine Schleife gibt | `include_tasks` mit `loop`, oder in der Datei schleifen |
| `Could not find or access '.../level_3.yml'` erst zur Laufzeit | der Dateiname eines dynamischen Includes kommt aus einer Variable und wird vorab nicht geprüft | die Variable validieren oder aus einer festen Liste wählen |
| Zwei Rollen stören sich über eine gleichnamige Variable | Rollenvariablen teilen sich den Namensraum des Plays | jedes Default, Var, `register` und `set_fact` mit dem Rollennamen präfixen |
| Das zweite `- role: x` in `roles:` tut nichts | eine Rolle mit identischen Parametern läuft einmal | andere Parameter geben oder `allow_duplicates: true` in `meta/main.yml` setzen |
| `No file was found when using first_found` | keiner der Kandidaten existiert | die Liste mit einer allgemeinen Datei beenden oder `skip: true` übergeben (das Lookup liefert dann ein leeres Ergebnis, das du selbst behandelst) |
| `Failed: n failure(s) ... Profile 'production' was required` und Exit-Code 2 | Regeln des verlangten Profils sind verletzt | beheben oder mit `--profile` ein niedrigeres Profil verlangen, solange die Rolle reift |
| `schema[meta]` bei `meta/main.yml` | `galaxy_info` ist vorhanden, aber unvollständig | vervollständigen oder den Schlüssel entfernen |

## Übungen

| Übung | Wofür diese Lektion vorbereitet |
|---|---|
| [3.01](../../exercises/stage3-intermediate/3.01-build-the-cis-role/README.de.md) | der Aufbau einer Rolle und was von selbst geladen wird, Defaults gegen Vars und die Präfix-Regel, statische Importe und ihre Tags, `always`, Daten nach Plattform wählen, Linting und der Vorher-nachher-Vergleich eines Refactorings |

Starte eine Übung mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Welche Dateien einer Rolle lädt Ansible, ohne dass man es sagt, und welche sucht es nur über den
   Namen?

   <details><summary>Antwort</summary>

   `tasks/main.yml`, `defaults/main.yml`, `vars/main.yml`, `handlers/main.yml` und
   `meta/main.yml` werden geladen, wenn die Rolle verwendet wird. `templates/` und `files/` werden
   nur durchsucht, wenn ein Task wie `template` oder `copy` eine Datei nennt. Weitere Task-Dateien
   werden nur gelesen, wenn ein Import oder Include sie nennt.

   </details>

2. Eine Rolle definiert `ssh_port: 22` in `defaults/main.yml` und versehentlich `ssh_port: 2222`
   in `vars/main.yml`. Das Inventar setzt `ssh_port: 2200`, das Play setzt nichts, und du startest
   mit `-e ssh_port=2300`. Welchen Wert sehen die Tasks, und welchen ohne `-e`?

   <details><summary>Antwort</summary>

   Mit `-e` ist es 2300: Die Kommandozeile schlägt jede andere Ebene. Ohne sie ist es 2222, weil
   das `vars/` der Rolle das Inventar (2200) und die Defaults (22) schlägt. Das Duplikat ist der
   Fehler: Ein Wert, den Benutzer ändern dürfen, gehört nur nach `defaults/`.

   </details>

3. Warum nennt eine Rolle namens `hardening` ihre registrierte Variable `hardening_cron_stat`
   statt `cron_stat`?

   <details><summary>Antwort</summary>

   Variablen einer Rolle, auch registrierte Ergebnisse und von ihr gesetzte Facts, teilen sich den
   Namensraum des ganzen Plays. Ein Name ohne Präfix kann eine andere Rolle oder das Play
   überschreiben oder von ihnen überschrieben werden, und der Schaden zeigt sich weit von der
   Ursache entfernt. Das Präfix hält die Namen einer Rolle für sie reserviert, und `ansible-lint`
   beanstandet das Fehlen als `var-naming[no-role-prefix]`.

   </details>

4. `--list-tasks` zeigt vier Tasks für eine mit `import_tasks` eingebundene Datei, aber nur eine
   Zeile für eine mit `include_tasks` eingebundene. Warum, und was bedeutet das für `--tags`?

   <details><summary>Antwort</summary>

   Ein Import wird beim Parsen des Playbooks aufgelöst, seine Tasks existieren also vor dem Lauf
   und erben Tags und Bedingungen des Imports. Ein Include wird gelesen, wenn der Task erreicht
   wird; `--list-tasks` kann nicht hineinsehen, und ein Tag am Include erreicht die Tasks der
   Datei nicht, es sei denn, du taggst sie oder nutzt `apply`.

   </details>

5. Nach einem Refactoring scheitert `ansible-playbook site.yml --tags ssh` beim ersten Task, der
   eine Variable nutzt, die ein Task am Anfang der Rolle mit `set_fact` setzt. Ein voller Lauf
   funktioniert. Was ist passiert, und was ist die Lösung?

   <details><summary>Antwort</summary>

   Unter `--tags ssh` hat der Task, der die Variable setzt, kein passendes Tag und wird
   übersprungen, die Variable ist für die folgenden Tasks also nicht definiert. Tagge jeden Task,
   von dem spätere Tasks abhängen, mit `always`, damit er läuft, was auch immer `--tags` auswählt.

   </details>

6. `ansible-lint --profile production` endet mit `Profile 'production' was required, but 'min'
   profile passed.` und Exit-Code 2. Was sagt der Satz, und wie machst du weiter?

   <details><summary>Antwort</summary>

   Es bleiben Verletzungen von Regeln in Profilen oberhalb von `min`, der Inhalt erreicht also nur
   `min`, die Stufe, auf der er lediglich lädt. Lies jede Zeile `Datei:Zeile: regel`, behebe sie
   und starte erneut; solange eine Rolle reift, kannst du ein niedrigeres Profil verlangen und es
   schrittweise anheben. Der Exit-Code ungleich null macht den Lauf als Gate brauchbar.

   </details>

7. Du hast die Tasks von einem Dutzend Playbooks in eine Rolle verschoben. Wie zeigst du, dass die
   Rolle tut, was die Playbooks taten?

   <details><summary>Antwort</summary>

   Mit Verhaltensbelegen, nicht mit Lint: Wende die Playbooks auf frische Hosts an und halte das
   Ergebnis der Checks fest, setze zurück, wende die Rolle an und führe dieselben Checks aus. Führe
   die Rolle danach ein zweites Mal aus (`changed=0`) und mit `--check --diff` (keine Unterschiede).
   Stimmen die Checks überein und ist der Lauf idempotent, hat das Refactoring das Verhalten
   erhalten.

   </details>

## Weiterführendes

- [Rollen](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html) - Aufbau, Suchpfade, `roles:` gegen `import_role` und `include_role`, Abhängigkeiten
- [Dateien und Rollen wiederverwenden](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse.html) - statische Importe gegen dynamische Includes
- [Tags](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_tags.html) - `always`, `never`, Vererbung, `--tags` und `--skip-tags`
- [Variablen verwenden](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html) - die vollständige Rangfolge
- [`ansible.builtin.first_found`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/first_found_lookup.html) - das Lookup der Demo-Rolle
- [ansible-lint](https://docs.ansible.com/projects/lint/) - Profile, Regeln und Konfiguration
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: `always` (tag), `defaults/` and `vars/`,
  `first_found`, `import_tasks` / `include_tasks`, `include_vars`, lint profile, role, tag
