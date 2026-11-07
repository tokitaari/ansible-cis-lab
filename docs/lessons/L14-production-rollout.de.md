# L14 - Rollout in Produktion: Fehlerbehandlung, Vorabprüfung, Wellen und Community-Rollen

*[English](L14-production-rollout.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 5.02, 5.03 | - | ~35 Min. | L02, L07, L10, L13 |

Eine korrekte Rolle kann trotzdem einen Ausfall verursachen, wenn sie alle Hosts gleichzeitig
trifft, und eine Härtungsrolle berührt Authentifizierung, Netzwerk und Dienste. Der Rollout ist
deshalb eine eigene Ingenieursaufgabe: vorher festlegen, wie weit sich ein Fehler ausbreiten darf,
die Hosts prüfen, bevor etwas geändert wird, den Kreis schrittweise vergrößern und nach jedem
Schritt das Ergebnis ansehen. Die zweite Hälfte der Lektion handelt von Code, den du nicht selbst
geschrieben hast. Community-CIS-Rollen gibt es, und sie decken weit mehr ab, als ein Team allein
schreibt; aber sie laufen als root auf jedem Server, also pinnst du sie, liest sie und testest sie
wie deine eigenen.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] vorhersagen, was ein Fehler auf einem Host mit den anderen Hosts, den späteren Wellen und den späteren Plays macht, mit und ohne `serial`, `max_fail_percentage` und `any_errors_fatal`
- [ ] die Wellengrößen einer `serial`-Liste ausrechnen, Prozentwerte eingeschlossen, und die Zusammenfassung (Recap) eines abgebrochenen Laufs richtig lesen
- [ ] nennen, was die Parallelität begrenzt (`forks`, `serial`, `throttle`), und sagen, welche Grenze gewinnt
- [ ] eine Vorabprüfung schreiben, deren lesende Prüfungen auch unter `--check` laufen, hinter einem Gate, das ohne ausdrückliche Bestätigung verweigert
- [ ] sagen, warum Facts nicht immer die richtige Quelle für das sind, was ein Host über sich weiß, und warum freier Platz innerhalb eines Hosts bei Thin Provisioning täuschen kann
- [ ] die Hostliste eines Plays von der Hostliste einer Welle unterscheiden und sagen, was `run_once` und `post_tasks` unter `serial` tun
- [ ] eine Rolle oder Collection aus Galaxy oder Git in `requirements.yml` pinnen und sagen, was ein zweiter Installationslauf ändert und was nicht
- [ ] eine fremde Rolle lesen, ohne sie auszuführen, und die Kriterien für Übernehmen, Forken oder Selberbauen nennen

## Theorie

Alle Demos laufen in einem Verzeichnis auf dem Control-Node und ändern auf den Targets nichts außer
einer kleinen Datei in `/tmp`. Alpine braucht das Python aus Übung 0.02 für die Module, die auf dem
Host laufen (`lab solve 0.02`).

```bash
mkdir -p /tmp/lesson14 && cd /tmp/lesson14
```

### Fehlersemantik: Wer hält an, wenn etwas scheitert

Dieselbe Rolle, die auf sieben Hosts funktioniert, kann auf dem achten scheitern, einer OS-Version,
die niemand getestet hat. Wie weit der Schaden reicht, entscheiden drei Schlüsselwörter, und der
Standard ist nicht das, was die meisten erwarten. Speichere das folgende Play als `fleet.yml`. Es
bricht absichtlich auf den Hosts, die in einer Variable stehen, und ändert sonst nichts:

```yaml
- name: A change that breaks on chosen hosts
  hosts: targets
  gather_facts: false
  serial: "{{ lesson14_serial | default(0) }}"
  max_fail_percentage: "{{ lesson14_maxfail | default(100) }}"
  tasks:
    - name: Pretend to change the host
      ansible.builtin.fail:
        msg: "broken on purpose"
      when: inventory_hostname in lesson14_broken | default([])

    - name: Carry on with the next task
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} got through"

- name: A later play, for example the report
  hosts: targets
  gather_facts: false
  tasks:
    - name: Say who gets here
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} reached the later play"
```

```bash
ansible-playbook fleet.yml -e '{"lesson14_broken": ["ubuntu"]}'
ansible-playbook fleet.yml -e '{"lesson14_broken": ["debian"], "lesson14_serial": 3}'
ansible-playbook fleet.yml -e '{"lesson14_broken": ["debian"], "lesson14_serial": 3, "lesson14_maxfail": 0}'
```

Der erste Lauf zeigt den Standard: Der gescheiterte Host fällt heraus, die anderen sieben beenden
das Play und gehen ins spätere Play, und der Exit-Code ist 2. Ein Fehler ist ein Ereignis pro Host.
Der zweite Lauf teilt die acht Hosts in Wellen zu je drei; die zwei gesunden Hosts der ersten Welle
werden fertig, und die nächsten Wellen und das spätere Play laufen, als wäre nichts passiert. Erst
der dritte Lauf mit der Schwelle 0 hält an: Die anderen zwei Hosts der Welle führen den nächsten
Task nicht aus, und weder die späteren Wellen noch das spätere Play starten. Die Tabelle fasst
zusammen, was mit einem kaputten Host gemessen wurde:

| Aufbau | Andere Hosts der Welle | Spätere Wellen und Plays | Recap listet |
|---|---|---|---|
| kein Schlüsselwort, kein `serial` | beenden das Play | laufen, ohne den gescheiterten Host | alle Hosts |
| `serial: 3` | beenden das Play | laufen | alle Hosts |
| `serial: 3`, `max_fail_percentage: 0` | halten vor dem nächsten Task an | starten nie | nur die Hosts der abgebrochenen Welle |
| `serial: 1`, der eine Host scheitert | keiner übrig | starten nie | nur diesen Host |
| `any_errors_fatal: true`, kein `serial` | halten vor dem nächsten Task an | starten nie | alle Hosts (sie sind alle gestartet) |

Drei Einzelheiten entscheiden, ob du das richtig liest:

- **Die Schwelle ist ein Anteil der Welle, und sie ist strikt.** Der Lauf hält erst an, wenn der
  Anteil gescheiterter Hosts in der aktuellen Welle *größer* als der Wert ist. Bei Wellen zu vier
  Hosts und zwei Fehlern macht `max_fail_percentage: 50` weiter und 49 hält an; bei einem Fehler
  macht 25 weiter und 24 hält an. Ein unerreichbarer Host zählt als Fehler (getestet mit einem Host,
  der auf einen geschlossenen Port zeigt); ohne Schwelle fällt er einfach heraus.
- **Eine Welle, in der jeder Host scheitert, beendet den Lauf** auch ohne Schwelle (getestet mit
  Wellen zu einem und zu zwei Hosts). Mit `serial: 1` beendet der erste gescheiterte Host deshalb
  alles, auch spätere Plays wie einen Bericht.
- **Das Recap listet Hosts nicht, die nie gestartet sind.** Nach einem Abbruch kann es drei Hosts
  mit `failed=0` zeigen und grün aussehen. Das Signal sind der Exit-Code (2) und die fehlenden Hosts.

`any_errors_fatal` ist die binäre Variante: Ein Fehler beendet das Play für alle, auch ohne `serial`
(getestet). Es ist ein Schlüsselwort des Plays und eines Blocks; in einem Block beendete ein Fehler
das ganze Play für alle Hosts, nicht nur den Block (getestet). `max_fail_percentage: 0` verhielt
sich ohne `serial` genauso, der Unterschied ist also vor allem der Regler: Der Prozentwert lässt
dich einen Fehler in einer Welle zu fünfzig Hosts tolerieren, das binäre Schlüsselwort nicht.

**Wellengrößen.** `serial` nimmt eine Zahl, einen Prozentwert oder eine Liste aus beidem. Ein
Prozentwert ist ein Anteil der Hosts des Plays (nach `--limit`), abgerundet und mindestens eins;
das letzte Element wiederholt sich, bis alle Hosts fertig sind. Auf den acht Lab-Hosts ergibt
`[1, "50%", "100%"]` 1, 4 und 3 Hosts, `["30%"]` vier Wellen zu zwei, `["10%"]` acht Wellen zu
einem, `[3]` 3, 3 und 2, und `[1, 100]` 1 und 7. Mit `-l` hat das Play weniger Hosts, und die
Prozentwerte schrumpfen mit.

**Was die Parallelität begrenzt.** Drei Einstellungen deckeln, wie viele Hosts gleichzeitig
arbeiten: `forks` (das Lab setzt 10), die Wellengröße von `serial` und `throttle` an einem einzelnen
Task. Die strengste gewinnt. Acht Hosts und ein Task, der eine Sekunde dauert, brauchen eine Runde
mit `forks` 10, vier mit `forks` 2, zwei mit `serial: 4`, vier mit `serial: 2`, vier mit
`throttle: 2` und vier mit `serial: 4` und `throttle: 2` zusammen (als Laufzeit gemessen, 2,2 s
gegen 5,3 s). Im Lab ist `forks` größer als die acht Hosts und begrenzt nie; auf einer Flotte
tut es das.

### Vorabprüfung und Gate: prüfen, bevor du änderst

Ein Rollout soll scheitern, bevor er etwas geändert hat, also schaut das erste Play nur hin. Es
prüft, was die Änderung braucht: Die Hosts antworten, die Werkzeuge, die die Änderung anfasst,
bestehen ihre eigenen Validatoren (denk an `sh -n` für ein Shell-Skript), es ist Platz da, und ein
Operator hat Ja gesagt. Das Play nutzt `any_errors_fatal`, weil ein kaputter Host in einer
Vorabprüfung ein Grund ist, dass ein Mensch hinsieht, und nichts, was der Rest der Flotte
übergehen sollte.

Das „Ja" ist eine Variable ohne Standardwert und ein `assert` hinter `run_once`. Scheitert ein
`run_once`-Task, endet der Lauf: Kein späterer Task und kein späteres Play ist gestartet, auch ohne
`any_errors_fatal` (getestet). `assert` läuft auch unter `--check`, ein Probelauf kann das Gate also
nicht überspringen. Die Prüfungen selbst brauchen unter `--check` Sorgfalt. Lesende Module wie
`stat` laufen; `command` wird übersprungen, außer `check_mode: false` ist gesetzt (die Arten von
Check-Mode-Ergebnissen stehen in [L10](L10-compliance-reporting.de.md)). Eine Vorabprüfung, deren
Prüfungen übersprungen wurden, ist grün und hat nichts geprüft. Speichere das als `gate.yml`; es
zeigt auch, wo Facts und Kernel sich widersprechen:

```yaml
- name: Gate before a change
  hosts: targets
  gather_subset: [hardware]
  any_errors_fatal: true
  tasks:
    - name: Operator confirmed
      ansible.builtin.assert:
        that: lesson14_go | default(false) | bool
        fail_msg: "refusing to go on: pass -e lesson14_go=true"
        quiet: true
      run_once: true

    - name: A probe without the keyword
      ansible.builtin.command: id -un
      register: lesson14_plain
      changed_when: false

    - name: Ask the kernel about the file system of /
      ansible.builtin.command: stat -f -c '%a %S' /
      register: lesson14_kernel
      changed_when: false
      check_mode: false

    - name: Compare the facts with the kernel
      vars:
        lesson14_fields: "{{ lesson14_kernel.stdout.split() }}"
      ansible.builtin.debug:
        msg:
          - "plain probe skipped: {{ lesson14_plain.skipped | default(false) }}"
          - "mount entries for / in the facts: {{ ansible_facts.mounts | selectattr('mount', 'equalto', '/') | list | length }}"
          - "MB available to non-root users on /: {{ (lesson14_fields[0] | int * lesson14_fields[1] | int / 1048576) | int }}"
```

```bash
ansible-playbook gate.yml --check
ansible-playbook gate.yml --check -e lesson14_go=true
```

Der erste Lauf wird verweigert, mit oder ohne `--check`. Der zweite gibt `plain probe skipped: True`
und eine Größe aus. Auf den Lab-Targets ist die Zahl der Mount-Einträge für `/` **0**: Der Fact
listet einen Mount nur, wenn sein Gerät mit `/` beginnt (oder mit `\`, oder wie `host:/pfad`
aussieht, so erscheint NFS), und die Wurzel eines Containers ist das Gerät `overlay`. Eine Prüfung,
die `ansible_facts.mounts` liest und auf 0 zurückfällt, meldet auf jedem Host eine leere Platte. Der
Kernel hat diesen blinden Fleck nicht. Achte darauf, nach welcher Zahl du fragst: `%a` ist, was
Nicht-root-Benutzer noch belegen dürfen, `%f` zählt auch die Reserve für root mit.

Auch die richtige Zahl kann täuschen. Ein Host sieht den freien Platz seiner *virtuellen* Platte,
nicht den des Speichers dahinter. Im Lab melden alle acht Targets die Kapazität der virtuellen
Platte von WSL2 oder Docker Desktop (etwa ein Terabyte), während das Windows-Laufwerk, das sie
hält, vielleicht nur noch wenige Gigabyte frei hat. Dasselbe gilt für qcow2-Images, Thin-LVM-Pools,
Thin-Disks von VMware und SAN-Volumes. Eine Vorabprüfung im Host kann das nicht sehen; die Kapazität
des Speichers dahinter gehört ins Monitoring der Plattform. Wisse, was eine Prüfung beweist, und
schreibe in das Runbook, was sie nicht beweisen kann.

### Wellen, Wellenlisten und die Prüfung nach jeder Welle

`serial` führt das *ganze Play* einmal pro Welle aus: Tasks, `post_tasks` und die gemeldeten
Handler, dann die nächste Welle (getestet). Das macht aus „Rolle, dann Verifikation, dann nächste
Welle" ein einziges Play. Zwei Spezialvariablen beschreiben die Lage, und man verwechselt sie
leicht. `ansible_play_batch` enthält die Hosts der aktuellen Welle; `ansible_play_hosts` enthält
jeden Host des Plays, der nicht gescheitert ist, **auch die Wellen, die noch nicht gelaufen sind**.
Ein Task mit `run_once` läuft einmal *pro Welle*, auf dem ersten Host dieser Welle, nicht einmal
pro Play. Speichere das als `batches.yml`:

```yaml
- name: Batches and the lists that describe them
  hosts: targets
  gather_facts: false
  serial: [1, 3, "100%"]
  tasks:
    - name: Record a result for this host
      ansible.builtin.set_fact:
        lesson14_result: "done on {{ inventory_hostname }}"

    - name: Compare the two lists
      ansible.builtin.debug:
        msg: "this batch has {{ ansible_play_batch | length }} hosts, the play {{ ansible_play_hosts | length }}"
      run_once: true

    - name: Read the result of every host of the play
      ansible.builtin.debug:
        msg: "{{ ansible_play_hosts | map('extract', hostvars, 'lesson14_result') | list | length }} results"
      run_once: true
      ignore_errors: true

- name: A later play reads what the earlier play recorded
  hosts: debian
  gather_facts: false
  tasks:
    - name: Read the result of another host
      ansible.builtin.debug:
        msg: "{{ hostvars['alpine'].lesson14_result }}"
```

```bash
ansible-playbook batches.yml
```

Der Vergleich gibt `this batch has 1 hosts, the play 8` aus, dann `3 hosts` und `4 hosts` gegen
dieselben 8: drei Wellen, die letzte mit den vier Hosts, die übrig waren. Der dritte Task scheitert
in den ersten beiden Wellen mit `object of type 'HostVarsVars' has no attribute 'lesson14_result'`,
weil er Hosts fragt, die noch nicht gelaufen sind, und gelingt in der letzten. Ein Bericht, der
einmal pro Welle geschrieben wird, braucht eine bewusste Antwort auf zwei Fragen: Welche Hosts
gehören hinein, und was soll jede Welle mit dem tun, was frühere Wellen geschrieben haben? Eine
Tatsache hilft: Mit `set_fact` gesetzte Variablen bleiben für den Rest des Laufs in `hostvars`,
auch in späteren Plays (das letzte Play liest das Ergebnis eines Hosts, auf dem es nie lief), ein
Canary-Play und die Wellen-Plays können also Daten teilen. Ein Task, der eine solche Variable liest,
darf nicht so geschrieben sein, als hätte jeder Host der Liste sie schon.

**Canary und Muster.** Ein Canary ist das erste Play mit einer kleinen, nach Vielfalt gewählten
Gruppe (ein Host pro Plattformfamilie ist ein guter Anfang). Der Rest ist ein zweites Play mit
einem Muster, das den Canary abzieht: `targets:!redhat_family` liest sich „alle Targets außer dieser
Gruppe" ([L00](L00-lab-and-ansible-basics.de.md) behandelt Muster), und `--list-hosts` zeigt, was ein
Muster auswählt, bevor etwas läuft. Ein Canary, der besteht, beweist wenig, wenn seine Prüfung
„der Task ist nicht gescheitert" lautet. Prüfe eine Eigenschaft, an der dir liegt: Der Dienst
antwortet, die Konfiguration ist gültig, und eine *neue* SSH-Verbindung funktioniert
([L13](L13-host-firewall-nftables.de.md) zeigt, warum eine wiederverwendete Verbindung nichts
beweist und wie `meta: reset_connection` eine neue erzwingt).

### Community-Rollen: Galaxy, Git und was du liest, bevor du ausführst

Das Projekt ansible-lockdown und andere pflegen CIS-Rollen je Distribution mit mehreren hundert
Kontrollen und einer Testmatrix. Eine davon zu nutzen heißt, Code von Dritten zu installieren, also
kommen drei Fragen zuerst: Woher kommt er, welche Version ist es, und was tut er.

**Woher er kommt.** Rollen auf Galaxy hängen an einem GitHub-Repository: `ansible-galaxy role
install geerlingguy.ntp` lädt das Archiv eines Tags von GitHub und gibt die dabei benutzte URL aus.
Eine Rolle lässt sich auch direkt aus einer Git-URL mit `scm: git` installieren. Collections sind
getrennt: `ansible-galaxy collection install` holt ein Artefakt vom Galaxy-Server. Der Control-Node
braucht Zugriff auf beides, und der Control-Container des Labs hat ihn (`git` 2.47 ist dort
installiert, auf den Targets nicht). Produktionsumgebungen spiegeln oft beides auf einen internen
Server und installieren von dort.

**Welche Version.** `requirements.yml` listet Rollen und Collections, und `version:` pinnt sie. Ein
Tag ist ein Versprechen des Maintainers und kann verschoben werden; ein Commit-Hash nicht. Ein
Branch-Name ist gar kein Pin. Die Datei unten installiert eine Rolle aus Galaxy an einem Tag,
dieselbe Rolle von GitHub an einem Commit und eine Collection in einem Bereich:

```bash
cat > requirements-galaxy.yml <<'EOF'
---
roles:
  - name: ntp_galaxy
    src: geerlingguy.ntp
    version: "4.0.1"
  - name: ntp_git
    src: https://github.com/geerlingguy/ansible-role-ntp
    scm: git
    version: "97e3451fc831c5d291addcce04599253cdca7a87"
collections:
  - name: ansible.posix
    version: ">=1.0.0,<2.0.0"
EOF
ansible-galaxy role info geerlingguy.ntp | head -n 8
ansible-galaxy role install -r requirements-galaxy.yml -p roles
ansible-galaxy collection install -r requirements-galaxy.yml -p collections
ansible-galaxy collection list ansible.posix
```

(`ntp` ist nur eine kleine, bekannte Rolle zum Üben, keine Härtungsempfehlung.) Die Rolleninfo
nennt GitHub-Benutzer, Repository und Commit hinter der Rolle. Die Rolleninstallation meldet
`ntp_galaxy (4.0.1) was installed successfully` und dasselbe für `ntp_git` mit dem Hash; die
Collection-Installation meldet `ansible.posix:1.6.2` und den Pfad, in den sie ging. Ein zweiter Lauf
der Rolleninstallation sagt für beide `is already installed, skipping`. Deine Versionen und Daten
werden abweichen, wenn die Projekte weiterziehen; die Pins oben bleiben installierbar. Zwei Fallen
sind in diesem Lauf sichtbar. Der Collection-Bereich `<2` installierte 1.6.2 nach `collections/`,
während der Control-Node des Labs `ansible.posix` 2.2.2 schon als Teil des Ansible-Pakets mitbringt,
und `ansible-galaxy collection list ansible.posix` zeigt weiterhin nur die 2.2.2: Die neue Kopie ist
unsichtbar, bis ihr Verzeichnis im Collections-Pfad liegt (die Installation warnt, dass es nicht so ist),
und dann entscheidet die Reihenfolge dieses Pfads, welche läuft. Rollen haben dasselbe Problem: Welche Kopie läuft, hängt davon ab, wo
Ansible den Namen zuerst findet ([L07](L07-roles-tags-project-structure.de.md) listet die Orte).

**Was die Installation mit einem Pin macht.** Das Verhalten sieht man leichter mit einem eigenen
Repository. Dieser Block baut eine winzige Rolle in einem lokalen Git-Repository und installiert sie
von dort. Der Installer besteht auf einer `meta/main.yml`, auch einer fast leeren; ohne sie wird die
Rolle mit `this role does not appear to have a meta/main.yml file` abgelehnt (getestet):

```bash
mkdir -p upstream/lesson14_stamp/tasks upstream/lesson14_stamp/defaults upstream/lesson14_stamp/meta roles
printf -- '---\nlesson14_stamp_text: hello\n' > upstream/lesson14_stamp/defaults/main.yml
printf -- '---\ndependencies: []\n' > upstream/lesson14_stamp/meta/main.yml
cat > upstream/lesson14_stamp/tasks/main.yml <<'EOF'
---
- name: Write the stamp
  ansible.builtin.copy:
    content: "{{ lesson14_stamp_text }}\n"
    dest: /tmp/lesson14_stamp
    mode: "0644"
  tags: [stamp]

- name: Show who runs
  ansible.builtin.command: id -un
  changed_when: false
  check_mode: false
  tags: [probe]
EOF
git -C upstream/lesson14_stamp init -q -b main
git -C upstream/lesson14_stamp add -A
git -C upstream/lesson14_stamp -c user.name=demo -c user.email=demo@example.invalid commit -q -m first
git -C upstream/lesson14_stamp tag v1.0.0
cat > requirements.yml <<'EOF'
---
roles:
  - name: lesson14_stamp
    src: /tmp/lesson14/upstream/lesson14_stamp
    scm: git
    version: v1.0.0
EOF
ansible-galaxy role install -r requirements.yml -p roles
ansible-galaxy role list -p roles
```

Jetzt veröffentlicht der Maintainer ein neues Tag, und du änderst den Pin:

```bash
git -C upstream/lesson14_stamp -c user.name=demo -c user.email=demo@example.invalid commit -q --allow-empty -m second
git -C upstream/lesson14_stamp tag v1.1.0
sed -i 's/version: v1.0.0/version: v1.1.0/' requirements.yml
ansible-galaxy role install -r requirements.yml -p roles
ansible-galaxy role install --force -r requirements.yml -p roles
```

Die erste Installation warnt nur: `lesson14_stamp (v1.0.0) is already installed - use --force to
change version to v1.1.0`. Ein Pin in der Datei ist eine Aussage darüber, was du willst, und die
Installation gleicht ihn nicht mit dem ab, was auf der Platte liegt, außer du erzwingst es. Eine
Rolle ohne `version:` wird als `(unknown version)` gelistet, und mit `version: main` bekommst du,
was der Branch am Tag der Installation enthält, morgen einen anderen Stand. Die installierte Kopie
enthält keine Git-Historie; Version und Datum stehen in `meta/.galaxy_install_info`.

**Was sie tut.** Lies, bevor du ausführst, in dieser Reihenfolge. `ansible-playbook site.yml
--list-tasks --list-tags` gibt aus, was das Play tun würde, ohne es zu tun; `--syntax-check` fängt
eine Rolle ab, die nicht lädt; und `--check --diff` gegen einen frisch zurückgesetzten Host zeigt,
was sich ändern würde (mit den Grenzen aus [L10](L10-compliance-reporting.de.md): `command`-Tasks
werden übersprungen, außer sie sind als lesend markiert). Speichere das als `site.yml`:

```yaml
- name: Use the installed role
  hosts: targets
  gather_facts: false
  roles:
    - role: lesson14_stamp
```

```bash
ansible-playbook site.yml --list-tasks --list-tags
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --check --diff -l debian
```

Die Auflistung zeigt beide Tasks mit ihren Tags (`stamp`, `probe`); der Check-Lauf meldet die Datei
als Änderung samt Inhalt. Lies dann die Rolle selbst: `defaults/` zeigt, welche Stellschrauben es
gibt und wie sie heißen, `tasks/` zeigt den Aufbau, und eine Suche nach `command`, `shell` und `raw`
findet die Tasks, die nichts von Idempotenz oder Check-Mode wissen. Sieh in `meta/` nach
Abhängigkeiten, die weitere Rollen installieren, in die Handler nach Dienst-Neustarts, danach, was
sie außerhalb ihres eigenen Bereichs schreibt, und nach den Tests, die mitgeliefert werden (die
Galaxy-Rolle oben bringt ein `molecule`-Verzeichnis mit). `ansible-lint` auf der Rolle ist eine
billige zweite Meinung.

**Übernehmen, forken oder bauen.** Übernehmen kauft Abdeckung und die Wartung durch andere. Es kostet
die Durchsicht jedes Releases, eine Abhängigkeit vom Tempo der Maintainer (Benchmarks wechseln
Versionen) und eine Spannung zwischen dem Entwurf der Rolle und deinen Ausnahmen. Forken gibt dir
Kontrolle und bei jeder Änderung von oben eine Merge-Aufgabe. Selberbauen gibt volle Kontrolle über
jede Zeile, für einen Umfang, den du selbst testen kannst, und alle Fehler gehören dir. Viele Teams
verpacken eine übernommene Rolle in eine kleine eigene Rolle für Einstellungen, Ausnahmen und
Berichte. Die Kriterien sind Passung, Prüfaufwand, Testabdeckung und wer um drei Uhr nachts was
repariert.

## CIS-Hintergrund

Ein Rollout ist kein Benchmark-Abschnitt, deshalb nennt der Kopf keinen: Die Empfehlungen sagen, was
zu konfigurieren ist, nicht wie man es auf zweitausend Server bringt. Die Benchmarks warnen aber
pro Empfehlung vor den Auswirkungen einer Änderung, und das ist die Eingabe für die Reihenfolge
eines Rollouts: Die Kontrollen, die jemanden aussperren oder eine Anwendung brechen können (Zugang,
Authentifizierung, Netzwerkfilter, Mount-Optionen, Mandatory Access Control), gehören in einen
frühen Canary auf jeder Plattform und in eine kleine erste Welle ([L01](L01-cis-benchmarks.de.md)
nennt die Falle für Level 2). Eine Community-Rolle gibt dir hunderte Empfehlungen auf einmal; die
Benchmark-Version, auf die sie zielt, und die Art, wie sie die störenden markiert, verraten dir, wie
viel vom Nachdenken dir abgenommen wurde. Die genauen Empfehlungsnummern unterscheiden sich je
Benchmark und Version; schlage sie im PDF deiner Distribution nach.

## Plattformunterschiede

| os_family | Hosts | `sshd`-Programm | `df`-Programm | Fehlt im Image |
|---|---|---|---|---|
| Debian | debian, ubuntu | `/usr/sbin` | `/usr/bin` | `git` |
| RedHat | rocky, alma / fedora | `/sbin` / `/usr/sbin` | `/bin` / `/usr/sbin` | `git`; fedora auch `hostname` |
| Suse | opensuse | `/usr/sbin` | `/usr/bin` | `git`, `hostname` |
| Alpine | alpine | `/usr/sbin` | `/bin` | `git`; Python vor 0.02 |
| Archlinux | arch | `/usr/bin` | `/usr/bin` | `git`, `hostname` |

Die Programme liegen je Familie in verschiedenen Verzeichnissen (und `df` auf fedora unter
`/usr/sbin`), eine Vorabprüfung sollte sich also weder auf einen Pfad noch auf den Befehl `hostname`
verlassen; `inventory_hostname` gibt es immer. `stat -f -c` funktioniert auf allen acht Hosts,
Alpine eingeschlossen. Alle acht melden das Dateisystem von `/` als `overlay` mit derselben
Kapazität.

### In den Lab-Containern

Die acht Targets sind Container auf einem Docker-Host. Ein misslungener Rollout kann immer nur einen
Container kaputt machen, und `./lab.sh reset <host>` stellt ihn wieder her. Drei Dinge unterscheiden
sich von einer echten Flotte. Bei acht Hosts sind Prozentwerte grob (10 % ist ein Host, 30 % sind
zwei; im Wellen-Play mit sechs Hosts von
[5.02](../../exercises/stage5-capstone/5.02-rollout-strategy/README.de.md) ist 30 % ein Host) und
`forks` ist nie die Grenze. `ansible_facts.mounts` hat keinen Eintrag für `/`, und der
freie Platz ist die Kapazität der virtuellen Platte von Docker Desktop (siehe
[Container-Grenzen](../CONTAINER_LIMITS.de.md)). Und ein Verbindungstest beweist nur den Netzweg der
Docker-Bridge, nicht den eines Produktionsnetzes.

## Stolperfallen

| Symptom | Ursache | Abhilfe |
|---|---|---|
| Das Recap zeigt `failed=0` für die gelisteten Hosts und der Lauf endete früh | eine abgebrochene Welle lässt spätere Hosts im Recap weg | Exit-Code lesen und das Recap mit der Hostliste vergleichen |
| Der Rollout ging nach einem Fehler weiter | der Standard toleriert Fehler in einer Welle mit mehr als einem Host | `max_fail_percentage` setzen (und denken, dass der Vergleich strikt ist) |
| Ein späteres Play, etwa der Bericht, lief nie | jeder Host einer Welle scheiterte, also blieb kein Host übrig | den Bericht als eigenen Schritt laufen lassen, der nicht davon abhängt, dass der Rollout fertig wird |
| Eine Prozentwelle ist größer als erwartet | der Prozentwert zählt die Hosts des Plays, nicht die übrigen, abgerundet | aus der Play-Größe rechnen, `--limit` eingeschlossen |
| `object of type 'HostVarsVars' has no attribute '...'` in einem Bericht | `ansible_play_hosts` listet Hosts von Wellen, die nicht gelaufen sind | entscheiden, wovon der Bericht handelt, und die Liste dafür wählen |
| Das Gate ist grün und nichts wurde geprüft | lesende `command`-Tasks werden unter `--check` übersprungen | `check_mode: false` an lesenden Proben, und auf `skipped` achten |
| „0 MB frei" auf jedem Host | `ansible_facts.mounts` hat keinen Eintrag für die Wurzel des Containers | den Kernel fragen und Facts als Bequemlichkeit behandeln |
| Viel Platz, Schreiben scheitert | der Host sieht die virtuelle Platte, nicht den Speicher dahinter | den Speicher dahinter überwachen; der Zahl im Gast nicht trauen |
| `does not appear to have a meta/main.yml file` | der Installer braucht die Datei, auch eine fast leere | `meta/main.yml` zur Rolle hinzufügen |
| Ein geänderter Pin wird nicht installiert | eine installierte Rolle wird ohne `--force` übersprungen | `--force`, nachdem du gelesen hast, was sich ändert, und `role list` ansehen |
| Die Rolle ist anders als letzte Woche | `version:` ist ein Branch oder fehlt | ein Tag pinnen, besser einen Commit |
| `collection list` zeigt eine andere Version als die installierte | die neue Kopie liegt nicht im Collections-Pfad, die mitgelieferte schon | dort installieren, wo der Pfad sie findet, oder den Pfad bewusst setzen |

## Übungen

| Übung | Was diese Lektion vorbereitet |
|---|---|
| [5.02](../../exercises/stage5-capstone/5.02-rollout-strategy/README.de.md) | Fehlersemantik und ihr Recap, `serial`-Listen, ein Gate und Proben, die auch unter `--check` laufen, was Facts und freier Platz sagen können und was nicht, Prüfung und Berichte pro Welle |
| [5.03](../../exercises/stage5-capstone/5.03-compare-with-community-role/README.de.md) | woher Community-Rollen kommen, Pinnen, eine Rolle lesen ohne sie auszuführen, Kriterien für Übernehmen, Forken oder Bauen |

Eine Übung startest du mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Bei acht Hosts und `serial: 3` scheitert ein Host der ersten Welle, sonst ist nichts gesetzt.
   Was passiert mit den anderen Hosts und mit den späteren Plays?

   <details><summary>Antwort</summary>

   Die zwei gesunden Hosts beenden das Play, die nächsten Wellen laufen, und spätere Plays laufen
   ohne den gescheiterten Host; nur der Exit-Code (2) und das Recap markieren den Fehler. Eine Welle
   mit mehr als einem Host toleriert Fehler, solange keine Schwelle und kein `any_errors_fatal`
   etwas anderes sagen.

   </details>

2. Wellen zu vier Hosts, ein Host scheitert, `max_fail_percentage: 25`. Läuft es weiter? Und bei 24?

   <details><summary>Antwort</summary>

   Bei 25 läuft es weiter und bei 24 hält es an: Einer von vieren sind 25 %, und der Lauf hält erst
   an, wenn der Anteil gescheiterter Hosts in der Welle größer als der Wert ist.

   </details>

3. Nach einem abgebrochenen Rollout zeigt das Recap drei Hosts mit `failed=0`. Ist die Flotte in
   Ordnung?

   <details><summary>Antwort</summary>

   Nein. Hosts, die nie gestartet sind, stehen nicht im Recap. Vergleiche es mit der Hostliste und
   sieh auf den Exit-Code; die drei gelisteten Hosts sind die der Welle, die abgebrochen wurde.

   </details>

4. Welche Wellengrößen hat `serial: [1, "50%", "100%"]` bei acht Hosts, und bei sechs nach `-l`?

   <details><summary>Antwort</summary>

   Acht Hosts: 1, 4 und 3. Sechs Hosts: 1, 3 und 2. Der Prozentwert ist ein Anteil der Hosts des
   Plays, nicht der übrigen, und die letzte Welle nimmt, was übrig ist.

   </details>

5. Eine Vorabprüfung mit einem `command`-Task ist unter `--check` auf einem Host grün, der in
   Wahrheit kaputt ist. Warum, und was änderst du?

   <details><summary>Antwort</summary>

   `command` wird im Check-Mode übersprungen, also wurde nichts geprüft. Eine lesende Probe bekommt
   `check_mode: false`, und das Gate sollte eine übersprungene Probe als Fehler werten, nicht als
   bestanden.

   </details>

6. Ein Berichts-Task mit `run_once` liest eine Variable jedes Hosts aus `ansible_play_hosts` und
   scheitert in der ersten Welle. Warum, und warum ist `ansible_play_batch` nicht die ganze Antwort?

   <details><summary>Antwort</summary>

   Unter `serial` enthält die Liste alle nicht gescheiterten Hosts, auch Wellen, die nicht gelaufen
   sind und deshalb diese Variable nicht haben. Die Wellenliste würde nicht abbrechen, aber jede
   Welle sähe dann nur ihre eigenen Hosts. Entscheide, für welche Hosts der Bericht ist, und wähle
   die Liste dafür.

   </details>

7. Die Facts sagen, es gibt keinen Mount für `/`, ein Befehl sagt, es sind 900 GB frei, und die
   Platte ist voll. Welche Aussagen stimmen?

   <details><summary>Antwort</summary>

   Die Facts überspringen Geräte, die nicht wie ein Pfad oder `host:/pfad` aussehen, also fehlt eine
   Container-Wurzel. Der Befehl meldet die virtuelle Platte, die größer sein kann als der Speicher,
   auf dem sie liegt. Beides stimmt, und keines misst den Speicher dahinter.

   </details>

8. Du hast `version:` in `requirements.yml` geändert und die Installation laufen lassen; die alte
   Version ist noch da. Warum, und wie findest du heraus, was installiert ist?

   <details><summary>Antwort</summary>

   Eine installierte Rolle wird übersprungen, außer du erzwingst die Installation, und die
   Installation warnt davor. `ansible-galaxy role list` zeigt die installierte Version und
   `meta/.galaxy_install_info` das Datum. Ein Tag kann verschoben werden und ein Branch zieht von
   selbst weiter; ein Commit-Hash pinnt.

   </details>

## Weiterführendes

- [Controlling playbook execution](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_strategies.html) - `serial`, `throttle`, `run_once`, Strategien
- [Error handling in playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_error_handling.html) - `any_errors_fatal`, `max_fail_percentage`, `ignore_errors`
- [Patterns: targeting hosts and groups](https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html) - eine Gruppe abziehen, `--limit`
- [Special variables](https://docs.ansible.com/ansible/latest/reference_appendices/special_variables.html) - `ansible_play_batch`, `ansible_play_hosts`
- [Galaxy user guide](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html) - Rollen und Collections installieren, `requirements.yml`
- [`ansible-galaxy`](https://docs.ansible.com/ansible/latest/cli/ansible-galaxy.html) - `role install`, `role list`, `collection install`, `--force`
- [Validating tasks: check mode and diff mode](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html) - `check_mode: false` an lesenden Tasks
- [stat(1)](https://manpages.debian.org/unstable/coreutils/stat.1.en.html) - `-f` für das Dateisystem, `%a`, `%f`, `%S`
