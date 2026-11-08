# L04 - Plattformunterschiede als Daten: Dictionaries, Schleifen, Jinja2 und Templates

*[English](L04-platform-differences-as-data.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 2.01, 2.02, 2.06 | 1.6, 5.1, 7.1 | ~25 Min. | L00, L02, L03 |

Acht Hosts, fünf OS-Familien, eine Vorgabe: Wenn jeder Unterschied sein eigenes `when` bekommt,
wächst das Playbook mit jeder Distribution. Diese Lektion zeigt die Alternative - *was sich
unterscheidet* in Daten halten und *was zu tun ist* in einem Task - und die vier Werkzeuge dafür:
Dictionaries, Schleifen, Jinja2-Ausdrücke und Templates.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] eine Kette von `when`-Bedingungen durch einen Dictionary-Zugriff mit einem Fakt als Schlüssel ersetzen und entscheiden, was bei einem unbekannten Schlüssel passiert
- [ ] den Aufbau eines registrierten Schleifenergebnisses lesen und auf eine Teilmenge seiner Einträge wirken
- [ ] mit Filtern und Tests Daten formen und sagen, was bei einer undefinierten Variable passiert
- [ ] ein Template mit Schleifen und Bedingungen schreiben, das bei jedem Lauf identische Ausgabe erzeugt
- [ ] vorhersagen, welchen Wert eine Variable hat, wenn mehrere Ebenen des Inventars und des Plays sie definieren

## Theorie

### Ein Task, viele Plattformen: Daten statt Bedingungen

Der erste Reflex bei "das ist auf RedHat anders" ist ein Task mit `when: ansible_facts.os_family ==
'RedHat'`. Bei drei Familien sind das drei fast gleiche Tasks, bei fünf fünf - und jede Änderung
muss fünfmal erfolgen. Unterscheidet sich nur ein *Wert* (ein Name, ein Modus, ein Pfad), lege die
Werte in ein Dictionary und schlage einen mit dem Fakt als Schlüssel nach:

```yaml
- name: One lookup instead of five conditions
  hosts: targets
  vars:
    sshd_service:
      Debian: ssh
      RedHat: sshd
      Suse: sshd
      Alpine: sshd
      Archlinux: sshd
  tasks:
    - name: Name of the SSH daemon on this host
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }}: {{ sshd_service[ansible_facts.os_family] }}"
    - name: The same lookup with a family nobody listed
      ansible.builtin.debug:
        msg: "{{ sshd_service['Gentoo'] | default('sshd') }}"
```

Nimm eckige Klammern, wenn der Schlüssel eine Variable ist; `sshd_service.Debian` funktioniert für
einen festen Namen. Schlüssel werden exakt und mit Groß-/Kleinschreibung verglichen: `Archlinux`,
nicht `Arch` und nicht die Inventargruppe `arch_family`. Ein fehlender Schlüssel lässt den Task
fehlschlagen (`object of type 'dict' has no attribute 'Gentoo'`). Das ist gewollt: Eine neue
Familie fällt beim ersten Lauf auf, statt wie eine andere behandelt zu werden. Ein `default`
macht aus dem Fehler eine Vermutung, das passt zu einem harmlosen Wert wie einem Dienstnamen, der
meist `sshd` heißt, und ist bei einer Sicherheitseinstellung falsch. Wähle es bewusst.

Daten ersetzen `when` nicht. Unterscheidet sich das *Verhalten* - ein Task, den es nur bei einer
Familie gibt, oder ein anderes Modul -, sagt eine Bedingung es klarer: Werte gehören in
Dictionaries, Schritte in Bedingungen. Wo das Dictionary liegt (hier in den `vars` des Plays,
sonst in Dateien je Familie in einer Rolle), ist Thema von L11.

### Schleifen über Daten

`loop` führt einen Task einmal je Element aus und legt das Element in `item`. Eine Liste ist der
einfache Fall; ein Dictionary wird mit `dict2items` zur Liste (Elemente mit `key` und `value`).
Bei langen Elementen wird die Ausgabe unlesbar, daher bestimmt `loop_control.label`, was angezeigt
wird.

Der Schritt, der Leute überrascht, ist `register` an einem Schleifen-Task. Die Variable enthält
dann eine Struktur, deren Liste `results` **einen Eintrag je Element** hat, und jeder Eintrag
trägt das Ergebnis des Moduls *und* das ursprüngliche Element unter `item`. Gibst du sie in eine
zweite Schleife, steht die ursprüngliche Eingabe als `item.item` bereit:

```yaml
- name: Act only on the paths that exist
  hosts: targets
  become: true
  vars:
    wanted_modes:
      /tmp/lab-data/one.txt: "0640"
      /tmp/lab-data/two.txt: "0600"
  tasks:
    - name: Scratch directory
      ansible.builtin.file:
        path: /tmp/lab-data
        state: directory
        mode: "0755"
    - name: Only one of the two files exists
      ansible.builtin.copy:
        dest: /tmp/lab-data/one.txt
        content: "demo\n"
        mode: "0640"
    - name: Look at every path
      ansible.builtin.stat:
        path: "{{ item.key }}"
      loop: "{{ wanted_modes | dict2items }}"
      loop_control:
        label: "{{ item.key }}"
      register: probe
    - name: Apply the mode where the file exists
      ansible.builtin.file:
        path: "{{ item.item.key }}"
        mode: "{{ item.item.value }}"
      loop: "{{ probe.results | selectattr('stat.exists') | list }}"
      loop_control:
        label: "{{ item.item.key }}"
```

`selectattr('stat.exists')` behält die Einträge, deren `stat.exists` wahr ist, sodass die zweite
Schleife nur `one.txt` sieht. Die Alternative ist, über alle Ergebnisse zu laufen und dem Task
eine Bedingung zu geben: Übersprungene Elemente erscheinen dann in der Ausgabe und in `results`,
als übersprungen markiert, während der Filter sie der Schleife ganz vorenthält. Beides ist
korrekt; nimm die Variante, deren Ausgabe du um 3 Uhr nachts lesen kannst. So kommt ein Task mit
Dateien zurecht, die es nur auf manchen Hosts gibt - die Lücke, die L03 offen gelassen hat.

Vorsicht: `item` gehört zur *innersten* Schleife; eine Task-Datei, die aus einer Schleife
eingebunden wird und selbst schleift, braucht `loop_var`, damit sich beide nicht in die Quere
kommen.

### Jinja2 in Ansible: Ausdrücke, Filter, undefinierte Werte

Alles zwischen `{{ }}` ist ein Jinja2-Ausdruck, der auf dem **Control Node** mit den Variablen des
aktuellen Hosts ausgewertet wird - das Target sieht nie Jinja2, nur das Ergebnis. `{% %}` enthält
Kontrollanweisungen (`for`, `if`) und `{# #}` Kommentare; beide sind in Template-Dateien zu
Hause. Ein YAML-Wert, der mit `{{` *beginnt*, muss in Anführungszeichen stehen, sonst liest YAML
ein Dictionary.

Filter verändern einen Wert und werden mit `|` geschrieben; Tests stellen eine Frage und werden
mit `is` geschrieben:

```yaml
- name: Filters and tests in one place
  hosts: targets
  vars:
    users: [bob, alice, bob]
    limits: {tries: 4, grace: 60}
  tasks:
    - name: Shape the data
      ansible.builtin.debug:
        msg:
          - "{{ users | unique | sort | join(' ') }}"
          - "{{ limits | dict2items | map(attribute='key') | sort | list }}"
          - "{{ limits.tries * 2 }}"
          - "{{ optional_banner | default('none') }}"
          - "{{ 'tries' in limits }} {{ limits.grace is defined }}"
```

Jeder Filter nimmt das Ergebnis des vorigen. `unique`, `sort`, `join`, `map`,
`select`/`selectattr` und `list` decken das meiste ab, was Härtungs-Playbooks brauchen; `lower`
vereinheitlicht ein Schlüsselwort vor einem Vergleich (in L03 gab es einen Fall, in dem das
zählte). Der Ausdruck `limits.tries * 2` ergibt die *Zahl* 8, nicht den Text "8": Ansible behält
den Typ eines Ergebnisses, das aus einem einzigen Ausdruck besteht. Text, der nur wie eine Zahl
aussieht (der Modus `"0640"`), bleibt Text, weil du ihn in Anführungszeichen gesetzt hast.

Eine **undefinierte Variable ist ein Fehler**, kein leerer String: Der Task schlägt mit `'x' is
undefined` fehl, auch in einem Template. Für optionale Werte gibt es drei Werkzeuge:
`| default('none')` liefert einen Wert; `| default(omit)` als Modulargument lässt die Option ganz
weg, sodass der Standard des Moduls gilt; `| mandatory('message')` bricht mit einer Meldung deiner
Wahl ab. Ein `default` verschluckt auch einen *Tippfehler* im Variablennamen, setze es also nur
ein, wo der Wert wirklich optional ist.

Ein `when` ist ein Jinja2-Ausdruck ohne Klammern und muss in ansible-core 2.21 einen Boolean
liefern: `when: "'yes'"` scheitert mit "Conditionals must have a boolean result". Schreibe den
Vergleich aus (`when: answer == 'yes'`).

### Templates: Dateien aus Variablen

Das Modul `template` rendert eine Jinja2-Datei auf dem Control Node und kopiert das Ergebnis auf
das Target, mit demselben Besitzer, Modus, `validate` und `--check --diff`-Verhalten wie `copy`
(L02). Die Template-Dateien liegen in `templates/` neben dem Playbook. Speichere dieses als
`templates/app.conf.j2`:

```jinja2
{{ ansible_managed | comment }}
{% for name, value in app_settings | dictsort %}
{% if value is boolean %}
{{ name }} {{ 'yes' if value else 'no' }}
{% else %}
{{ name }} {{ value }}
{% endif %}
{% endfor %}
AllowUsers {{ app_users | join(' ') }}
{% if app_extra is defined %}
Extra {{ app_extra }}
{% endif %}
```

und rendere es:

```yaml
- name: Render a generic configuration file
  hosts: targets
  vars:
    app_settings: {Retries: 4, Compress: false, Mode: strict}
    app_users: [alice, bob]
  tasks:
    - name: Scratch directory
      ansible.builtin.file:
        path: /tmp/lab-app
        state: directory
        mode: "0755"
    - name: Render several files from one list
      ansible.builtin.template:
        src: "{{ item.src }}"
        dest: "{{ item.dest }}"
        mode: "{{ item.mode }}"
      loop_control:
        label: "{{ item.dest }}"
      loop:
        - {src: app.conf.j2, dest: /tmp/lab-app/a.conf, mode: "0644"}
        - {src: app.conf.j2, dest: /tmp/lab-app/b.conf, mode: "0600"}
```

Ansible entfernt den Zeilenumbruch nach einem Block-Tag (`trim_blocks`), daher hinterlassen Tags
in einer eigenen Zeile **keine Leerzeilen** im Ergebnis - vorausgesetzt, das Tag beginnt in Spalte
0: `lstrip_blocks` ist aus, und ein eingerücktes Tag lässt seine Leerzeichen stehen. Setze
Block-Tags an den Zeilenanfang, wie oben, oder schreibe `#jinja2: lstrip_blocks: True` als erste
Zeile des Templates. Alles andere, auch Leerzeichen am Zeilenende, wird so übernommen, wie es
dasteht. `ansible_managed | comment` macht aus dem Text "Ansible managed" einen Kommentarblock am
Anfang, damit der nächste Administrator weiß, dass er nicht von Hand ändern soll. Nutze es in
Konfigurationsdateien und nicht in Text, den Menschen lesen sollen, etwa Login-Meldungen: Dort ist
es Rauschen, und in einem Dateiformat ohne Kommentare macht es die Datei kaputt.

Ein Template muss **deterministisch** sein, sonst meldet der zweite Lauf `changed`: keine
Zeitstempel, keine Zufallswerte, und Dictionaries und Mengen in fester Reihenfolge durchlaufen
(`dictsort`, `sort`), weil sich die Reihenfolge der Schlüssel beim Zusammenführen oder Verschieben
von Variablen zwischen Ebenen ändern kann. `--check --diff` rendert den neuen Inhalt und zeigt den
Unterschied Zeile für Zeile - führe es vor dem echten Lauf aus (L02) und danach noch einmal: Ein
sauberes `--diff` ist der Beweis für Idempotenz.

### Woher Variablen kommen

Derselbe Name kann an vielen Stellen definiert sein, und ein Wert gewinnt. Vereinfacht, von der
schwächsten zur stärksten Ebene:

| Ebene | Wo |
|---|---|
| Rollen-Defaults | `defaults/main.yml` einer Rolle (L07) |
| Inventargruppe | `group_vars/all.yml`, dann `group_vars/<group>.yml` - die speziellere Gruppe gewinnt |
| Inventar-Host | `host_vars/<host>.yml` |
| Play und Task | `vars:` des Plays, dann des Tasks |
| Kommandozeile | `-e name=value` - schlägt alles |

Die vollständige Liste hat viele weitere Ebenen; diese hier genügt für die Übungen. Definiere
einen Wert auf der schwächsten Ebene, die für alle richtig ist, und überschreibe ihn auf der
engsten Ebene, die einen anderen braucht. `ansible-inventory --host <name>` zeigt die
**Inventarebenen** für einen Host; Play-Variablen und `-e` sind darin nicht enthalten. Die
`group_vars/all.yml` des Labs definiert `lab_in_container` und `lab_org_name`. Sieh dir an, was
jede Ebene bewirkt:

```yaml
- name: One variable, several layers
  hosts: alpine
  gather_facts: false
  tasks:
    - name: Inventory value
      ansible.builtin.debug:
        var: lab_org_name
    - name: Task variable wins over the inventory
      ansible.builtin.debug:
        var: lab_org_name
      vars:
        lab_org_name: from the task
```

Führe es unverändert aus, dann mit `-e lab_org_name=from-the-command-line` und beobachte, wie sich
beide Zeilen ändern. Weil das Inventar eine Gruppe je OS-Familie hat (`debian_family`,
`redhat_family`, ...), enthält eine Datei `group_vars/<family>_family.yml` Daten für genau eine
Familie - der Mechanismus hinter datengetriebenen Rollen.

## CIS-Hintergrund

Die Empfehlungen hinter diesen Übungen sind verschiedener Art. Die Rechte der Dateien mit
Passwort-Hashes (7.1) haben eine richtige Antwort *je Distribution*; der Abschnitt SSH-Server
(5.1) ist eine Empfehlung mit vielen Parametern; die Warnbanner beim Login (1.6) sind ein Text,
der in mehreren Dateien stehen muss. Alle sind Level 1 im [Kontrollkatalog](../../cis/controls.yml)
und alle sind "eine Entscheidung, viele Orte": Die *Absicht* ist gemeinsam, der konkrete Pfad, die
Gruppe oder der Wert nicht.

Der Preis der Abstraktion ist Umweg: Ein Dictionary und ein Template sind schwerer zu lesen als
ein einzelnes `lineinfile`. Wechsle, wenn derselbe Unterschied in einem zweiten Task auftaucht
oder eine dritte Familie dazukommt. Ausnahmen sind ebenfalls Daten: Ein Host, der abweichen muss,
bekommt einen anderen Wert auf einer engeren Variablenebene statt eines geflickten Tasks (L11).

## Plattformunterschiede

| os_family | Hosts | Inventargruppe | SSH-Daemon-Unit | Fakt `distribution` |
|---|---|---|---|---|
| Debian | debian, ubuntu | `debian_family` | `ssh` | Debian, Ubuntu |
| RedHat | rocky, alma, fedora | `redhat_family` | `sshd` | Rocky, AlmaLinux, Fedora |
| Suse | opensuse | `suse_family` | `sshd` | openSUSE Leap |
| Alpine | alpine | `alpine_family` | `sshd` | Alpine |
| Archlinux | arch | `arch_family` | `sshd` | Archlinux |

`os_family` ist der grobe Schlüssel, den Dictionaries nutzen; `distribution` unterscheidet die
Mitglieder einer Familie, wenn eines abweicht (fedora hat einen neueren Paketmanager als rocky).
Nimm keinen Hostnamen als Dictionary-Schlüssel: Er ist Inventardaten, keine Plattform-Eigenschaft.

### In den Lab-Containern

- Fakten werden wie auf einer VM gesammelt, aber ein Play, das Fakten sammelt, braucht Python auf
  dem Target; alpine hat es erst nach Übung 0.02.
- `/tmp` gehört dem Container, daher sind die Scratch-Verzeichnisse dieser Lektion je Host privat
  und verschwinden bei `./lab.sh reset <host>` (`.\lab.ps1 reset <host>` unter Windows).
- Das Inventar definiert eine Gruppe je Familie und die labweiten Variablen in
  `group_vars/all.yml`; die Übungen lesen `lab_org_name` von dort.

## Stolperfallen

| Symptom | Ursache | Behebung |
|---|---|---|
| `object of type 'dict' has no attribute 'Arch'` | Dictionary-Schlüssel anders geschrieben als der Fakt-Wert | die Fakt-Werte `Debian`, `RedHat`, `Suse`, `Alpine`, `Archlinux` verwenden |
| Eine neue Distribution bekommt still einen falschen Wert | ein pauschales `default` verdeckt den fehlenden Schlüssel | kein Default für Sicherheitswerte - fehlschlagen lassen und die Zeile ergänzen |
| `object of type 'dict' has no attribute 'path'` in der Folgeschleife | die Schleife läuft über `probe.results`, `item` ist also ein Ergebnis, kein Pfad | der ursprüngliche Wert ist `item.item`; die Daten sind `item.stat` |
| Ausgabe einer verschachtelten oder eingebundenen Schleife ist falsch | das innere `item` verdeckt das äußere | Variable benennen: `loop_control: {loop_var: path}` |
| `Conditionals must have a boolean result` | `when` liefert String, Zahl oder Liste | ausdrücklich vergleichen: `== 'yes'`, `\| length > 0` |
| Deprecation-Warnung bei `when: "{{ x }}"` | `when` ist bereits ein Ausdruck | `when: x` ohne Klammern schreiben |
| Verirrte Leerzeichen in der gerenderten Datei, verschobene Zeilen | Block-Tags sind eingerückt, und `lstrip_blocks` ist aus | Block-Tags in Spalte 0 setzen oder `#jinja2: lstrip_blocks: True` ergänzen; mit `--diff` prüfen |
| `changed` bei jedem Lauf eines `template`-Tasks | Zeitstempel, Zufallswert oder unsortierte Iteration im Template | entfernen oder sortieren (`dictsort`, `sort`) |
| `'x' is undefined` nur auf manchen Hosts | die Variable ist auf einer Gruppenebene definiert, in der diese Hosts nicht sind | in `all` definieren oder `default` setzen, wo sie wirklich optional ist |
| Der Wert aus `group_vars` wird nicht verwendet | eine engere Ebene (`host_vars`, Play-`vars`, `-e`) überschreibt ihn | den Namen in den stärkeren Ebenen suchen; `ansible-inventory --host` für den Inventaranteil |

## Übungen

| Übung | Was diese Lektion dafür vorbereitet |
|---|---|
| [2.01](../../exercises/stage2-building-blocks/2.01-shadow-permissions-per-family/README.de.md) | Dictionary mit `os_family` als Schlüssel, fehlende Schlüssel, registrierte Schleifenergebnisse, auf Vorhandenes wirken |
| [2.02](../../exercises/stage2-building-blocks/2.02-sshd-template/README.de.md) | `template` mit Variablen, `for`, `join`, `ansible_managed`, deterministische Ausgabe, `--diff` |
| [2.06](../../exercises/stage2-building-blocks/2.06-banners-template-loop/README.de.md) | ein Template in einer Schleife, Inventarvariablen und ihre Rangfolge, wann `ansible_managed` nicht hingehört |

Eine Übung startest du mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Ein Kollege ersetzt fünf Tasks mit `when: ansible_facts.os_family == ...` durch einen Task mit
   Dictionary. Wann ist das keine Verbesserung?

   <details><summary>Antwort</summary>

   Wenn sich die *Schritte* unterscheiden und nicht nur ein Wert: ein Task, den es nur bei einer
   Familie gibt, oder ein anderes Modul je Familie. Eine Bedingung sagt das klarer als ein
   Dictionary mit Modulnamen. Werte (Namen, Modi, Pfade) gehören in Daten, Schritte in Bedingungen.

   </details>

2. Ein Dictionary-Zugriff scheitert auf einem Host mit `has no attribute`. Nenne zwei Lösungen
   und sage, wann welche falsch ist.

   <details><summary>Antwort</summary>

   Den fehlenden Schlüssel ergänzen oder dem Zugriff ein `default` geben. Das Default ist bei
   einem Sicherheitswert falsch, weil eine neue Familie still eine Vermutung bekäme. Die Zeile zu
   ergänzen ist falsch, wenn die Familie gar nicht unterstützt werden soll: Dann ist der Fehler
   das gewollte Ergebnis.

   </details>

3. Nach `stat` mit `loop` und `register: probe` läuft eine zweite Schleife über `probe.results`.
   Was ist `item.item`, was `item.stat`, und wie lässt du die zweite Schleife nur auf vorhandene
   Dateien laufen?

   <details><summary>Antwort</summary>

   `item.item` ist das ursprüngliche Schleifenelement des `stat`-Tasks, `item.stat` sein
   Ergebnis. Filtere die Liste mit `probe.results | selectattr('stat.exists') | list` oder gib
   dem Task `when: item.stat.exists`; der Filter hält übersprungene Elemente aus der Ausgabe, die
   Bedingung listet sie als übersprungen auf.

   </details>

4. `{{ x }}` ergibt in einem Task `8` und in einem anderen `"8"`. Was bestimmt den Typ?

   <details><summary>Antwort</summary>

   Ein Ergebnis, das aus einem einzigen Ausdruck besteht, behält seinen Typ (eine Zahl bleibt
   eine Zahl); Text, der mit einem Ausdruck gemischt ist, etwa `"{{ x }} items"`, ist immer ein
   String. Ein in YAML in Anführungszeichen gesetzter Wert (`"0640"`) ist von Anfang an ein
   String, deshalb werden Modi gequotet.

   </details>

5. Ein Play mit Template meldet bei jedem Lauf `changed=1`, obwohl sich keine Variable geändert
   hat. Wonach suchst du?

   <details><summary>Antwort</summary>

   Nach etwas im *gerenderten Text*, das sich von Lauf zu Lauf unterscheidet: ein Datum oder eine
   Uhrzeit, ein Zufallswert oder eine Iteration in wechselnder Reihenfolge (zusammengeführte
   Dictionaries, Mengen). Entferne es oder sortiere mit `dictsort` oder `sort`. `--check --diff`
   zeigt die abweichenden Zeilen.

   </details>

6. `group_vars/all.yml` setzt `site: A`, `host_vars/web1.yml` setzt `site: B`, das Play hat
   `vars: site: C`, und du startest mit `-e site=D`. Was sieht `web1`, und wie prüfst du den
   Inventaranteil?

   <details><summary>Antwort</summary>

   `D`: Die Kommandozeile schlägt alles, dann folgen die Play-Variablen (`C`), die Host-Ebene (`B`)
   und zuletzt die Gruppenebene (`A`). `ansible-inventory --host web1` zeigt nur die
   Inventarebenen (`B`); Play-Variablen und `-e` sind darin nicht enthalten.

   </details>

7. Warum bekommt ein Login-Banner kein `{{ ansible_managed | comment }}`, ein sshd-Drop-in aber
   schon?

   <details><summary>Antwort</summary>

   Der Kommentar ist für den nächsten Administrator gedacht, der eine Konfigurationsdatei liest. Im
   Banner sieht ihn jeder Benutzer, der sich anmeldet: Rauschen und ein Hinweis darauf, wie der
   Host verwaltet wird. Eine Konfigurationsdatei will ihn, solange das Format Kommentare hat.

   </details>

## Weiterführendes

- [Templating (Jinja2)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html) und [Filter](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html) im Ansible-Guide
- [Schleifen](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_loops.html) - `loop_control`, `dict2items`, Schleifen registrieren
- [Variablen verwenden](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html) - die vollständige Rangfolge
- [Modul `ansible.builtin.template`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)
- [Jinja-Template-Designer-Dokumentation](https://jinja.palletsprojects.com/en/stable/templates/) - `for`, `if`, Whitespace-Kontrolle
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: `group_vars` / `host_vars`, Jinja2,
  loop, platform data, template, variable precedence
