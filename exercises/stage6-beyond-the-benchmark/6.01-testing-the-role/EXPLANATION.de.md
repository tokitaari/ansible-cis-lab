# 6.01 - Eine Rolle testen: Molecule-Szenario mit testinfra: Erklärung

### Was der Check prüft
`lab check 6.01` führt `check.sh` in vier Schritten aus. `meta.yml` sagt `idempotency: false`:
Der zweite Lauf ist der Schritt `idempotence` deiner eigenen Sequenz.

1. **Das Szenario:** `molecule.yml` nennt `testinfra` als Verifier, `tests/` enthält mindestens
   eine `test_*.py`, und eine `test_sequence`, falls du eine setzt, hat `converge`, `idempotence`
   und `verify` in dieser Reihenfolge.
2. **`molecule test`** in `/lab/work/6.01` endet mit 0, und sein junit-Bericht (der Check setzt
   `PYTEST_ADDOPTS=--junitxml=...`) hat bestandene Tests für jedes der acht Targets.
3. **Die Anforderungen**, geprüft von einem eigenen Playbook des Checks: `stat` und `slurp` der
   sechs Dateien auf jedem Target, verglichen mit R1-R3 - genauer Eigentümer, Gruppe und Modus,
   der Bannertext Byte für Byte.
4. **Deine Tests auf kaputten Targets:** Auf sechs Targets wird je eine Anforderung verletzt,
   dann muss `molecule verify` auf jedem davon einen gescheiterten Test melden und auf ubuntu und
   alma keinen. `molecule converge` stellt sie danach wieder her.

| Target | Was der Check verletzt |
|---|---|
| debian | `/etc/passwd` Modus 0664 |
| arch | `/etc/group` gehört `ansible` |
| rocky | `/etc/shadow` Modus 0640 (RedHat verlangt 0000) |
| opensuse | `/etc/shadow` Gruppe root (Suse verlangt shadow) |
| fedora | `/etc/issue` Modus 0666 |
| alpine | `/etc/issue.net` sagt "Welcome to Alpine Linux" |

Er prüft nicht, woher deine Sollwerte stammen (nur ihre Wirkung), und auch nicht die Teile der
Anforderungen, die keine Mutation verletzt: `/etc/gshadow`, die Shadow-Werte von Debian, Alpine
und Archlinux, die Gruppe von R1 und R3, den Inhalt von `/etc/issue`. Schritt 3 prüft für alle
trotzdem das Ergebnis der Rolle. Gemessen mit der Musterlösung auf allen acht Targets: `molecule
test` 65-69 s (syntax 8 s, converge 28, idempotence 30, verify 15), der ganze Check 143 s.

### So funktioniert es

#### Molecule führt Ansible mit einer eigenen Konfiguration aus
Molecule schreibt eine `ansible.cfg` in sein kurzlebiges Verzeichnis
(`~/.ansible/tmp/molecule.<x>.<scenario>/`) und lässt `ANSIBLE_CONFIG` darauf zeigen. Alles, was
`/lab/ansible/ansible.cfg` setzt, ist weg: das Inventar, `roles_path`, die SSH-Optionen,
Pipelining. Die Verbindungsvariablen bleiben, weil `ansible_user` und der Schlüssel in
`group_vars/targets.yml` des Inventars stehen. `molecule.yml` holt den Rest zurück:

- `ansible.executor.args.ansible_playbook: [--inventory=...]` - kommt in jeden Aufruf von
  `ansible-playbook`, neben Molecules eigenes (fast leeres) Inventar;
- `ansible.cfg.ssh_connection` - wird in die erzeugte `ansible.cfg` eingemischt;
- `ansible.env` - Umgebungsvariablen für jeden Lauf; `${MOLECULE_PROJECT_DIRECTORY}` wird
  ersetzt, damit hängt der Rollenpfad nicht davon ab, wo das Arbeitsverzeichnis liegt (der
  CI-Runner nimmt `/tmp/lab-run-work`). Die Musterlösung ergänzt
  `${MOLECULE_PROJECT_DIRECTORY}/roles` als zweiten Eintrag für `lab solve 6.01`, das in
  `solution/` läuft, wo `roles/` im Projekt liegt.

#### Der Default-Driver und Hosts, die es schon gibt
Molecule 26 bringt einen Driver mit, `default`. Mit `managed: false` legt er nichts an und
löscht nichts; ohne `platforms` ist das Szenario "ansible-native": Die Hosts sind die des
Inventars (`molecule list` zeigt die acht). Der Preis ist Zustand: `molecule test` ändert die
echten Targets, und ein Target, das eine frühere Übung in einem anderen Zustand hinterlassen hat,
ergibt ein anderes erstes converge. `./lab.sh reset all` bringt den frischen Zustand zurück.

#### testinfra: eine Testfunktion, viele Hosts
Molecule ruft `pytest` mit `--connection=ansible` und `--ansible-inventory=<sein eigenes
Inventar>` auf. Dieses Inventar hat keine Hosts, darum `verifier.options.ansible-inventory`;
`hosts: targets` wird zu `--hosts=targets`. pytest führt dann jede Testfunktion einmal je Host aus
(IDs wie `test_account_file[ansible://debian-/etc/passwd]`), und `parametrize` multipliziert das
mit den Dateien. testinfra führt je Befehl (`stat`, `cat`) sein eigenes `ssh` aus, mit Benutzer,
Schlüssel und `ssh_args`, die es im Inventar und in `ANSIBLE_CONFIG` findet - die SSH-Optionen in
`molecule.yml` dienen also auch den Tests.

#### Sollwerte, die der Rolle widersprechen können
Die Rolle kam mit zwei Fehlern. Ein Task `command: chmod` meldet bei jedem Lauf `changed`: Nur
der Idempotenz-Schritt sieht ihn (seine `CRITICAL`-Meldung nennt `* => cis_mini : Make sure the
banners are world-readable`), weil der Zustand, den der Task hinterlässt, stimmt. Und die eigene
Tabelle der Rolle gibt der Familie RedHat den Modus 0640: Das sieht nur ein Test mit *eigenen*
Sollwerten - gemessen sechs Fehler, `/etc/shadow` und `/etc/gshadow` auf rocky, alma und fedora,
jeweils `assert ('root', 'root', 416) == ('root', 'root', 0)`. Ein Test, der `vars/main.yml` der
Rolle liest, bestand mit dem Fehler auf allen acht Hosts; der Check hielt ihn in Schritt 3 auf.
Ein Test ist nur so viel wert wie die Chance, dass er scheitert: Die Mutationen aus Schritt 4
machen diese Chance sichtbar.

### Hinweise je Familie

| os_family | Hosts | Worauf die Tests treffen |
|---|---|---|
| Debian | debian, ubuntu | Gruppe `shadow` gibt es; `stat` auf ubuntu ist uutils coreutils 0.10.0 - das Dateimodul von testinfra funktioniert damit |
| RedHat | rocky, alma, fedora | keine Gruppe `shadow`; `/etc/issue` und `/etc/issue.net` von fedora sind vor dem ersten Lauf symbolische Links (`stat` zeigt 0777, siehe 2.06); `copy` ersetzt sie |
| Suse | opensuse | kein `/etc/gshadow` - der gshadow-Test wird übersprungen |
| Alpine | alpine | kein `/etc/gshadow`; BusyBox-`stat` - das Dateimodul funktioniert; die Dienste sind OpenRC |
| Archlinux | arch | keine Gruppe `shadow`, darum root und 0600 |

In einem frischen Lab (nach 0.02) änderte das erste converge der Starter-Rolle auf jedem Host 4
Tasks.

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Abhilfe |
|---|---|---|
| `The role 'cis_mini' was not found in: .../molecule/default/roles:~/.ansible/roles:...` | Molecules `ansible.cfg` hat kein `roles_path` | `ANSIBLE_ROLES_PATH` in `ansible.env` |
| `RuntimeError: No inventory was parsed (missing file ?), only implicit localhost is available` | testinfra bekommt Molecules eigenes Inventar, das keine Hosts hat | `ansible-inventory` in `verifier.options` |
| `molecule verify` allein: `Host key verification failed` bei jedem Test; nach einem `molecule converge` bestehen dieselben Tests | ohne die `ssh_args` des Labs prüft testinfra Host-Schlüssel; Ansible (`host_key_checking = False`) hat sie in `~/.ssh/known_hosts` geschrieben | `ssh_args` in `ansible.cfg.ssh_connection` |
| `molecule test` endet mit 1 und `CRITICAL Idempotence test failed`, aber die Zusammenfassung sagt `idempotence: Executed: Successful` und `failed=0` | die Zusammenfassung hält diesen Fehler nicht fest (gemessen mit Molecule 26.11.1; `successful=` zählt den Idempotenz-Schritt nie) | dem Exit-Code und der `CRITICAL`-Zeile trauen |
| `assert 416 == 0` | pytest gibt Modi dezimal aus | `oct(f.mode)` vergleichen |
| Ein Test besteht mit dem falschen Modus in der Rolle | sein Sollwert stammt aus der Rolle | Sollwerte aus den Anforderungen |
| `molecule idempotence` sagt `Instances not converged` | ein gescheitertes `molecule test` hat cleanup und destroy ausgeführt, die Molecules Zustand zurücksetzen | zuerst `molecule converge` |

### Praxis-Hinweise
- Die meisten Molecule-Setups legen je Lauf frische Instanzen an (Container oder VMs,
  Driver-Plugins oder `create.yml`), so trifft das erste converge immer denselben Zustand. Gegen
  langlebige Hosts, wie hier, laufen die Tests auf dem, was die Hosts gerade haben - setze sie vor
  einem Lauf zurück, der das erste converge beweisen soll.
- In einem Rollen-Repository liegt das Szenario in der Rolle (`roles/<name>/molecule/default/`),
  und CI führt `molecule test` bei jeder Änderung aus; der Projektaufbau hier passt nur zu
  `lab start`.
- Ein Szenario je Profil oder Level hält die Erwartungen auseinander (ein L2-Szenario erwartet
  mehr).
- testinfra prüft den Zustand; ein Audit-Werkzeug ersetzt es nicht. OpenSCAP oder CIS-CAT
  beurteilen einen Host gegen den Benchmark, die Tests die Rolle gegen ihre eigenen Anforderungen.

### Weiterführend
- Lektion [L18 - Rollen testen](../../../docs/lessons/L18-testing-roles.de.md): die Testleiter, Molecules Konfiguration, testinfra, Sollwerte - die Konzepte vor dieser Übung.
- Übung [2.01 - /etc/shadow: richtige Rechte je OS-Familie](../../stage2-building-blocks/2.01-shadow-permissions-per-family/README.de.md): woher die Werte von R2 stammen.
- Übung [2.06 - Alle Login-Banner aus einem Template](../../stage2-building-blocks/2.06-banners-template-loop/README.de.md): die symbolischen Links auf fedora.
- [Molecule: ansible-native configuration](https://docs.ansible.com/projects/molecule/ansible-native/) - `ansible.executor`, `ansible.cfg`, `ansible.env`.

## Musterlösung

Zeige sie mit `lab solution 6.01`, wende sie mit `lab solve 6.01` an (es führt `molecule test` im
Lösungsverzeichnis aus und lässt die Targets im angewendeten Zustand).
