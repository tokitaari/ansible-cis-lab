# L18 - Rollen testen: Molecule, testinfra und Tests, die scheitern können

*[English](L18-testing-roles.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 6.01 | - | ~20 Min. | L02, L07 |

Eine Härtungsrolle greift auf jeder Plattform anders ein, und eine Änderung, die auf einer Familie
stimmt, kann auf einer anderen falsch sein. Bisher hat dir `lab check` gesagt, ob deine Arbeit
stimmt; in einem echten Team schreibt dir diesen Check niemand. Diese Lektion zeigt, wie eine
Rolle sich selbst testet: Molecule führt sie aus, führt sie noch einmal aus und übergibt die Hosts
an testinfra, dessen Tests in Python den Zustand lesen und mit den Anforderungen vergleichen. Sie
erklärt auch, warum ein Test nur dann etwas wert ist, wenn er scheitern kann.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] sagen, was Lint, Syntaxprüfung, converge, der Idempotenz-Schritt und der Verifier jeweils finden - und was jeweils nicht
- [ ] ein Molecule-Szenario einrichten, das gegen Hosts läuft, die es schon gibt
- [ ] benennen, was Molecules eigene `ansible.cfg` wegnimmt, und es in `molecule.yml` zurückholen
- [ ] testinfra-Tests mit der Fixture `host`, `parametrize` und Erwartungen je Familie schreiben
- [ ] Sollwerte aus den Anforderungen nehmen, nicht aus dem getesteten Code, und zeigen, dass ein Test scheitern kann
- [ ] Molecules Ergebnis an Exit-Code und `CRITICAL`-Zeile ablesen, nicht an seiner Zusammenfassung

## Theorie

### Eine Leiter von Tests

Jede Art von Test beantwortet eine Frage, und jede übersieht, was die nächste findet:

| Schritt | Befehl | Findet | Übersieht |
|---|---|---|---|
| Lint | `ansible-lint` | riskante Muster: `command` ohne `changed_when`, Modi ohne Anführungszeichen, fehlender FQCN (L07) | einen falschen Wert in gültigem Code |
| Syntax | `ansible-playbook --syntax-check` | YAML- und Schlüsselwortfehler, eine Rolle, die nicht gefunden wird | alles, was auf einem Host passiert |
| converge | die Rolle ausführen | Modulfehler auf echten Hosts, je Plattform | einen falschen Zustand, den die Module akzeptieren |
| idempotence | sie noch einmal ausführen, `changed=0` erwarten | Tasks, die bei jedem Lauf ändern | einen falschen Zustand, der gleich bleibt |
| verify | den Zustand lesen, vergleichen | falsche Werte, eine vergessene Plattform | nur, was kein Test fragt |

Der Check-Modus (L02) gehört zu keinem dieser Schritte: Er sagt voraus, was ein Lauf ändern
würde, er sieht sich das Ergebnis nicht an. Eine Rolle kann den Check-Modus bestehen, ohne Fehler
durchlaufen und idempotent sein - und trotzdem auf einer Familie den falschen Modus setzen. Nur
der letzte Schritt sieht sich das Ergebnis an, darum geht es in dieser Lektion vor allem um ihn.

### Molecule: Szenarien und Sequenzen

Molecule ordnet die Schritte. Ein *Szenario* ist ein Verzeichnis mit einer `molecule.yml`, einem
Playbook `converge.yml`, das anwendet, was du testest, und - für testinfra - einem Verzeichnis
`tests/`. Das Szenario `default` liegt in `molecule/default/` unter dem Verzeichnis, in dem du
Molecule ausführst (dem *Projekt*). `molecule test` führt die *Testsequenz* des Szenarios aus;
jeder Schritt läuft auch einzeln:

```bash
molecule --version
```

Der Control Node des Labs hat Molecule 26.11.1 mit einem Driver, `default`. Ein *Driver* legt
Testinstanzen an und löscht sie wieder - in den meisten Setups Container oder virtuelle Maschinen.
Der Control Node hat keine Container-Laufzeit, und das Lab hat schon acht Hosts, darum nimmt das
Szenario den Default-Driver mit `managed: false` (Molecule legt nichts an und löscht nichts) und
nennt keine `platforms`: Die Hosts sind die eines Inventars, das du übergibst. Molecule nennt das
ein "ansible-native" Szenario.

`molecule converge` wendet das Playbook an; `molecule idempotence` führt es noch einmal aus und
scheitert, wenn ein Task eine Änderung meldet; `molecule verify` führt die Tests gegen den Zustand
aus, den die Hosts jetzt haben; `molecule test` führt die ganze Sequenz aus; `molecule list` zeigt
die Hosts. Eine ausdrückliche `test_sequence` hält sie kurz - die Standardsequenz führt auch
dependency, create, prepare, side_effect, cleanup und destroy aus, die hier nur Warnungen
"Missing ..." ausgeben.

### Molecule schreibt seine eigene `ansible.cfg`

Molecule führt Ansible nicht mit deiner Konfiguration aus. Es schreibt eine `ansible.cfg` in ein
kurzlebiges Verzeichnis unter `~/.ansible/tmp/` und setzt `ANSIBLE_CONFIG` darauf. Alles, was
`/lab/ansible/ansible.cfg` setzt, ist für diesen Lauf weg: das Inventar, `roles_path`, die
SSH-Optionen und Pipelining. Was im Inventar selbst steht, bleibt - `ansible_user` und der
Schlüssel des Labs stehen in `group_vars/targets.yml`. Drei Schlüssel von `molecule.yml` holen den
Rest zurück:

- `ansible.executor.args.ansible_playbook` - zusätzliche Argumente für jeden Aufruf von
  `ansible-playbook`, zum Beispiel `--inventory=/lab/ansible/inventory/hosts.yml`;
- `ansible.cfg` - Abschnitte, die in die erzeugte Datei eingemischt werden, zum Beispiel
  `ssh_connection`;
- `ansible.env` - Umgebungsvariablen für jeden Lauf. Molecule ersetzt `${VAR}` in `molecule.yml`
  durch die Umgebung, auch durch sein eigenes `MOLECULE_PROJECT_DIRECTORY`, damit hängt ein Pfad
  wie `${MOLECULE_PROJECT_DIRECTORY}/../roles` nicht davon ab, wo das Projekt liegt.

Ein kleines Szenario gegen alle acht Targets - keine Rolle, ein Task und zwei Tests:

```bash
mkdir -p /tmp/l18/molecule/default/tests && cd /tmp/l18
cat > molecule/default/molecule.yml <<'EOF'
---
driver:
  name: default
  options:
    managed: false
ansible:
  cfg:
    ssh_connection:
      pipelining: true
      ssh_args: -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR
  executor:
    args:
      ansible_playbook:
        - --inventory=/lab/ansible/inventory/hosts.yml
verifier:
  name: testinfra
  options:
    ansible-inventory: /lab/ansible/inventory/hosts.yml
scenario:
  test_sequence: [syntax, converge, idempotence, verify]
EOF
cat > molecule/default/converge.yml <<'EOF'
---
- name: Converge
  hosts: targets
  tasks:
    - name: A file that names the host that wrote it
      ansible.builtin.copy:
        content: "written by {{ inventory_hostname }}\n"
        dest: /var/tmp/l18-demo
        mode: "0640"
    - name: Which ansible.cfg this run uses
      ansible.builtin.debug:
        msg: "{{ lookup('ansible.builtin.env', 'ANSIBLE_CONFIG') }}"
      run_once: true
EOF
```

Der Debug-Task gibt einen Pfad unter `~/.ansible/tmp/` aus, nicht `/lab/ansible/ansible.cfg`. Die
Tests folgen im nächsten Abschnitt; dann führt `molecule test` alles aus.

### testinfra: Tests in Python gegen echte Hosts

testinfra ist ein Plugin für pytest. pytest sammelt die Funktionen namens `test_*` in Dateien
namens `test_*.py`, führt jede aus und meldet jedes gescheiterte `assert` mit den Werten auf beiden
Seiten. Das Plugin bringt die *Fixture* `host` mit: Eine Testfunktion mit dem Argument `host` läuft
einmal je Host, und `host` gibt Zugriff auf die Module von testinfra - `host.file()`,
`host.service()`, `host.package()`, `host.user()`, `host.run()`, `host.check_output()`,
`host.sudo()` und mehr. `pytest.mark.parametrize` führt eine Funktion ebenfalls einmal je Wert
aus, so deckt eine Funktion eine Liste von Dateien auf jedem Host ab.

```bash
cat > /tmp/l18/molecule/default/tests/test_demo.py <<'EOF'
import pytest

# Name des SSH-Dienstes je Inventargruppe; alle anderen: sshd
SSH_SERVICE = {"debian_family": "ssh"}


@pytest.mark.parametrize("path", ["/var/tmp/l18-demo"])
def test_demo_file(host, path):
    f = host.file(path)
    assert f.is_file
    assert oct(f.mode) == "0o640"
    assert f.content_string == f"written by {host.backend.get_hostname()}\n"


def test_ssh_service(host):
    groups = host.ansible.get_variables()["group_names"]
    name = next((SSH_SERVICE[g] for g in groups if g in SSH_SERVICE), "sshd")
    svc = host.service(name)
    assert svc.is_running
    assert svc.is_enabled
EOF
cd /tmp/l18 && molecule test
```

Der verify-Schritt meldet 16 bestandene Tests: zwei je Host, mit IDs wie
`test_demo_file[ansible://debian-/var/tmp/l18-demo]`. Zwei Einzelheiten lassen den Lauf
funktionieren. Molecule ruft pytest mit `--connection=ansible` und seinem *eigenen* Inventar auf,
das keine Hosts hat - ohne `ansible-inventory` in `verifier.options` bricht testinfra mit "No
inventory was parsed" ab. (`hosts:` daneben würde eine Gruppe wählen; ohne gilt jeder Host des
Inventars.) Und testinfra erreicht die Hosts nicht über Ansible: Es liest Benutzer, Schlüssel und
`ssh_args` aus dem Inventar und aus `ANSIBLE_CONFIG` und führt für jeden Befehl sein eigenes `ssh`
aus. Die SSH-Optionen in `molecule.yml` dienen also auch den Tests, und ebenso der `control_path`,
den Molecules `ansible.cfg` setzt: testinfra nutzt eine Verbindung je Host nur dann wieder, wenn
die Konfiguration einen Control-Pfad nennt.

Dieselbe Testdatei läuft auch ohne Molecule, mit der Konfiguration des Labs:

```bash
cd /tmp/l18 && pytest -p no:cacheprovider -q --hosts=ansible://alpine --ansible-inventory=/lab/ansible/inventory/hosts.yml molecule/default/tests/test_demo.py
```

Auf alpine dauert das ein paar Sekunden. `/lab/ansible/ansible.cfg` nennt keinen `control_path`,
darum öffnet testinfra für jeden Befehl eine neue SSH-Verbindung: Eine Probe von etwa einem
Dutzend Prüfungen je Host brauchte auf jedem systemd-Target 38-48 s und auf alpine 3 s. Für viele
Tests ist `molecule verify` der schnellere Weg.

### Sollwerte, und Tests, die scheitern können

Ein Test vergleicht den Zustand mit einem Sollwert, und der Sollwert muss woanders herkommen als
aus dem getesteten Code: aus den Anforderungen, dem Benchmark, einer Tabelle, die jemand eigens
dafür geschrieben hat. Ein Test, der die Variablen der Rolle importiert oder abschreibt, prüft,
dass die Rolle tut, was die Rolle sagt - er besteht bei jedem falschen Wert in diesen Variablen.
Das ist der häufigste Weg, wie eine Testsuite grün und nutzlos ist.

Die zweite Frage ist, ob ein Test überhaupt scheitern kann. Verletze den Zustand von Hand und führe
die Tests noch einmal aus:

```bash
ansible debian -m ansible.builtin.file -a "path=/var/tmp/l18-demo mode=0644"
cd /tmp/l18 && molecule verify
```

Jetzt scheitert `test_demo_file[ansible://debian-...]` mit `AssertionError: assert '0o644' ==
'0o640'`, und die übrigen fünfzehn bestehen. Ein Test, der grün bleibt, wenn du verletzt, was er
angeblich prüft, prüft nichts. Den Zustand absichtlich zu verletzen ist *Mutationstesten* von
Hand; Molecules Sequenz hat einen Schritt `side_effect` für ein Playbook, das es in einem Szenario
tut. `molecule converge` stellt die Datei wieder her; `ansible targets -m ansible.builtin.file -a
"path=/var/tmp/l18-demo state=absent"` entfernt sie, wenn du fertig bist.

Lies das Ergebnis eines Laufs an seinem Exit-Code und seiner `CRITICAL`-Zeile ab. Ein `molecule
test`, dessen Idempotenz-Schritt scheitert, endet mit Exit-Code 1 und `CRITICAL Idempotence test
failed`, gefolgt von den Tasks, die geändert haben - und Molecule 26.11.1 gibt danach eine
Zusammenfassung aus, die `idempotence: Executed: Successful` und `failed=0` sagt.

## CIS-Hintergrund

Die Benchmarks beschreiben den Zustand eines Hosts, nicht den Weg dorthin, und über Tests sagen sie
nichts. Für eine Rolle, die sie umsetzt, beantworten Tests drei Fragen, die ein Audit nicht
beantworten kann: Erreicht die Rolle den Zustand auf *jeder* Plattform, die sie unterstützt,
bleibt sie still, wenn nichts falsch ist, und bleibt beides wahr nach einer Änderung? Die zweite
wiegt schwerer, als es aussieht. Der Audit-Modus aus L10 liest ein `changed` als Abweichung; ein
Task, der bei jedem Lauf ändert, schreibt einen falschen Befund in jeden Bericht und versteckt die
echten. Ändert eine neue Benchmark-Version einen Wert, zeigt eine Rolle mit Tests, auf welchen
Familien die Änderung angekommen ist, bevor es die Hosts tun.

Ein Szenario je Profil hält Level 1 und Level 2 auseinander - ein L2-Szenario erwartet mehr. Und
Tests sind kein Audit-Werkzeug: OpenSCAP oder CIS-CAT beurteilen einen Host gegen den Benchmark,
die Tests beurteilen die Rolle gegen ihre eigenen Anforderungen.

## Plattformunterschiede

Gemessen mit testinfra 10.2.2 auf den acht Targets (nach 0.02):

| os_family | `host.system_info.distribution` | `host.service` | `host.package` | `stat` |
|---|---|---|---|---|
| Debian | debian, ubuntu | systemd (`ssh`) | dpkg | GNU coreutils (debian), uutils coreutils 0.10.0 (ubuntu) |
| RedHat | rocky, almalinux, fedora | systemd (`sshd`) | rpm | GNU coreutils |
| Suse | opensuse-leap | systemd (`sshd`) | rpm | GNU coreutils |
| Alpine | alpine | OpenRC (`sshd`) | apk | BusyBox |
| Archlinux | arch | systemd (`sshd`) | pacman (`openssh`) | GNU coreutils |

testinfra wählt das Backend eines Moduls nach dem Host, und sein Dateimodul funktionierte mit allen
drei `stat`-Umsetzungen. Namen unterscheiden sich trotzdem: Der SSH-Dienst heißt in der Familie
Debian `ssh`, das Paket auf arch `openssh` - ein Test braucht Erwartungen je Familie genau dort, wo
die Rolle Daten je Familie braucht.

### In den Lab-Containern

Die Targets sind langlebige Container, keine Instanzen, die Molecule für jeden Lauf anlegt: Ein
Szenario läuft auf dem, was eine frühere Übung hinterlassen hat, und `molecule test` ändert die
echten Targets. `./lab.sh reset all` gibt jedem Szenario den frischen Zustand der Images. Die
üblichen Driver von Molecule bräuchten eine Container-Laufzeit im Control Node, und die hat das Lab
nicht.

## Stolperfallen

| Symptom | Ursache | Abhilfe |
|---|---|---|
| `The role '<name>' was not found in: .../molecule/default/roles:~/.ansible/roles:...` | Molecules `ansible.cfg` hat kein `roles_path` | `ANSIBLE_ROLES_PATH` in `ansible.env` |
| `RuntimeError: No inventory was parsed (missing file ?), only implicit localhost is available` | testinfra bekommt Molecules Inventar, das keine Hosts hat | `ansible-inventory` in `verifier.options` |
| `molecule verify` allein scheitert mit `Host key verification failed`; nach `molecule converge` besteht es | ohne `ssh_args` prüft testinfra Host-Schlüssel, und erst der Lauf von Ansible hat sie in `~/.ssh/known_hosts` geschrieben | die `ssh_args` des Labs in `ansible.cfg.ssh_connection` |
| Die Zusammenfassung sagt `idempotence: Executed: Successful` nach `CRITICAL Idempotence test failed` | Molecules Zusammenfassung hält diesen Fehler nicht fest | Exit-Code und `CRITICAL`-Zeile entscheiden |
| `assert 416 == 420` | pytest gibt Modi dezimal aus | `oct(f.mode)` mit `"0o644"` vergleichen |
| `WARNING ... The scenario config file (...) has been modified since the scenario was created` | du hast `molecule.yml` nach einem Lauf geändert | harmlos; `molecule reset` löscht den gespeicherten Zustand |
| Ein eigenständiges `pytest --hosts=ansible://...` braucht Sekunden je Test | kein `control_path` in der `ansible.cfg` des Labs: eine SSH-Verbindung je Befehl | `molecule verify`, oder einen Host testen |
| Jeder Test besteht, und die Rolle ist falsch | die Sollwerte stammen aus der Rolle | schreibe sie nach den Anforderungen; verletze den Zustand einmal und sieh den Test scheitern |

## Übungen

| Übung | Was diese Lektion vorbereitet |
|---|---|
| [6.01](../../exercises/stage6-beyond-the-benchmark/6.01-testing-the-role/README.de.md) | ein Szenario mit dem Default-Driver gegen das Lab-Inventar, was Molecules Konfiguration wegnimmt, testinfra mit `host` und `parametrize`, Sollwerte aus den Anforderungen, ein Test, der scheitern kann |

Starte eine Übung mit `lab start <id>`; `lab show <id>` gibt ihre README aus.

## Selbstkontrolle

1. Eine Rolle setzt jede Datei auf allen acht Hosts richtig und besteht `molecule verify`, aber
   `molecule test` scheitert. Welche Art Fehler ist übrig, und welcher Schritt hat ihn gefunden?

   <details><summary>Antwort</summary>

   Ein Task, der bei jedem Lauf eine Änderung meldet - zum Beispiel `command` ohne
   `changed_when` oder ein Template mit Zeitstempel. Der Zustand, den er hinterlässt, stimmt, also
   kann der Verifier ihn nicht sehen; der Idempotenz-Schritt führt die Rolle ein zweites Mal aus
   und scheitert, weil `changed` nicht 0 ist. In der Praxis zählt das: Im Audit-Modus meldet so ein
   Task auf jedem Host bei jedem Lauf eine Abweichung.

   </details>

2. Du führst `molecule converge` aus, und es sagt `The role 'cis' was not found`, obwohl
   `ansible-playbook` dieselbe Rolle aus demselben Verzeichnis findet. Warum?

   <details><summary>Antwort</summary>

   Molecule führt Ansible mit seiner eigenen `ansible.cfg` aus (`ANSIBLE_CONFIG` zeigt in sein
   kurzlebiges Verzeichnis), darum gilt der `roles_path` aus `/lab/ansible/ansible.cfg` nicht.
   Setze `ANSIBLE_ROLES_PATH` in `ansible.env` von `molecule.yml`, mit
   `${MOLECULE_PROJECT_DIRECTORY}`, wenn der Pfad relativ zum Projekt ist.

   </details>

3. Ein Test aus dem Team liest den erwarteten Modus von `/etc/shadow` aus `vars/main.yml` der
   Rolle. Was beweist dieser Test, und was nicht?

   <details><summary>Antwort</summary>

   Er beweist, dass die Rolle den Wert, den sie enthält, auf jedem Host angewendet hat - ein
   Modulfehler oder eine vergessene Familie würde also noch auffallen. Er beweist nicht, dass der
   Wert richtig ist: Ein falscher Eintrag in `vars/main.yml` ist zugleich Sollwert und Istwert, und
   der Test besteht. Sollwerte müssen aus einer unabhängigen Quelle kommen, etwa den Anforderungen
   oder dem Benchmark.

   </details>

4. Wie findest du heraus, ob ein Test scheitern kann, und warum reicht "alle Tests grün" nicht?

   <details><summary>Antwort</summary>

   Verletze den Zustand, den er prüft, auf einem Host - von Hand oder in einem
   `side_effect`-Playbook - und führe `molecule verify` aus: Der Test muss auf diesem Host scheitern
   und nur dort. Ein Test, der grün bleibt, prüft nichts, und "alle grün" sagt nur, dass kein Test
   gescheitert ist, nicht dass ein Test auf das Richtige geschaut hat.

   </details>

5. `pytest --hosts=ansible://targets` mit der Konfiguration des Labs braucht Minuten, `molecule
   verify` mit denselben Tests Sekunden. Was ist der Unterschied?

   <details><summary>Antwort</summary>

   testinfra öffnet je Befehl eine eigene SSH-Verbindung und nutzt eine nur dann wieder, wenn die
   Ansible-Konfiguration, die es liest, einen `control_path` nennt. Molecules erzeugte
   `ansible.cfg` setzt einen, die des Labs nicht, und eine neue Verbindung zu einem systemd-Target
   braucht ein paar Sekunden.

   </details>

## Weiterführendes

- [Molecule documentation](https://docs.ansible.com/projects/molecule/) - Szenarien, Befehle, die Testsequenz
- [Molecule: ansible-native configuration](https://docs.ansible.com/projects/molecule/ansible-native/) - `ansible.executor`, `ansible.cfg`, `ansible.env`, Szenarien ohne `platforms`
- [testinfra: modules](https://testinfra.readthedocs.io/en/latest/modules.html) - `file`, `service`, `package`, `user`, `ansible`
- [testinfra: connection backends](https://testinfra.readthedocs.io/en/latest/backends.html) - `ansible://`, `--ansible-inventory`, wie SSH-Einstellungen gelesen werden
- [pytest: parametrizing tests](https://docs.pytest.org/en/stable/how-to/parametrize.html) - `@pytest.mark.parametrize`
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: default driver (Molecule), fixture (pytest), idempotence step
  (Molecule), Molecule, mutation testing, scenario (Molecule), test oracle, test sequence (Molecule),
  testinfra, verifier (Molecule)
