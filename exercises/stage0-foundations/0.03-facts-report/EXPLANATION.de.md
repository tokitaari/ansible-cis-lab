# 0.03 - Facts: ein Bericht über acht Distributionen: Erklärung

### Was der Check prüft
`lab check 0.03` führt `check.yml` auf dem Control-Node aus und stellt für
`$LAB_WORK_DIR/0.03/facts.csv` sicher:
- die Datei existiert und ihre erste Zeile ist genau
  `host,distribution,version,os_family,pkg_mgr,service_mgr,python`;
- es gibt 8 Datenzeilen mit je 7 Feldern, und die erste Spalte ist genau die Menge von
  `groups['targets']`;
- die `alpine`-Zeile enthält `,openrc,` und keine Zeile enthält `unreachable`.

Danach führt er dein Playbook noch einmal mit `--check` aus und erwartet `changed=0` (`meta.yml`
sagt `idempotency: true`). Anders als bei 0.02 ist das ein echter Test: `setup`, `file` und
`template` unterstützen alle den Check-Modus.

Nicht getestet werden die Werte und wie die Datei entstanden ist. Eine handgetippte Datei mit
ausgedachten Werten (`x` als Distribution, `3` als Python) besteht, und Zeilen in umgekehrter
Reihenfolge ebenso (gemessen mit der echten `check.yml`). Das "kein Shell-`echo >>`" der README
und der Sortier-Bonus beruhen also auf deiner Ehrlichkeit.

### So funktioniert es

#### Warum zwei Plays
Facts werden *pro Host* gesammelt, der Bericht braucht aber *alle* an einer Stelle. Play 1 auf
`targets` füllt `hostvars`, Play 2 auf `localhost` liest es und schreibt die Datei auf dem
Control-Node. Ein einzelnes Play geht auch: Facts für alle Hosts sammeln, dann rendert ein Task
mit `delegate_to: localhost` und `run_once: true` das Template (mit zwei Hosts gemessen: der Task
zeigt `changed: [a -> localhost]`, der zweite Lauf ist `ok`). Zwei Plays lesen sich klarer.

#### Facts lesen
`hostvars[h]['ansible_facts']` enthält die Facts des Hosts `h` ohne das Präfix `ansible_`:
`distribution`, `distribution_version`, `os_family`, `pkg_mgr`, `service_mgr`, `python_version`.
`python_version` ist die Version des Interpreters, den Ansible auf diesem Host benutzt hat.

#### Wie ein fehlender Fact aussieht
Ein Host, der keine Facts geliefert hat, ist entweder `UNREACHABLE` (keine SSH-Verbindung) oder
`FAILED` (zum Beispiel Alpine ohne Python, siehe 0.02). In beiden Fällen war er in Play 1, und
sein `ansible_facts` ist ein leeres Dict (gemessen mit ansible-core 2.21.6). Das Lesen von
`f.distribution` stoppt dann Play 2:

```
object of type 'dict' has no attribute 'distribution'
```
Das Referenz-Template vermeidet das mit `f.get('distribution', 'unreachable')` und
`| default({})`: `.get()` deckt das leere Dict ab, `default({})` einen Host, der in gar keinem
Play war (dann ist `ansible_facts` undefiniert, siehe L00). Das Platzhalterwort `unreachable`
steht für beide Fälle, auch für das fehlgeschlagene Alpine; der Check lehnt es in beiden Fällen
ab.

#### Template-Details
`template` rendert mit `trim_blocks=True` und `lstrip_blocks=False` (Modul-Defaults, gemessen),
`{% ... %}`-Zeilen am Zeilenanfang hinterlassen also keine Leerzeilen. Die sortierte Schleife
über `groups['targets'] | sort` liefert eine stabile Reihenfolge und eine idempotente Datei. Die
Lösung legt das Verzeichnis (`0755`) und die Datei (`0644`) auf dem Control-Node an.

### Hinweise je Familie
Gemessen auf den Lab-Images vom 2026-11-07, nach 0.02:

| `os_family` | Hosts: `distribution` `distribution_version` | `pkg_mgr` | `service_mgr` | `python_version` |
|---|---|---|---|---|
| Debian | debian: Debian 13.7; ubuntu: Ubuntu 26.04 | apt | systemd | 3.13.5 (debian), 3.14.4 (ubuntu) |
| RedHat | rocky: Rocky 10.2; alma: AlmaLinux 10.2; fedora: Fedora 44 | dnf (rocky, alma), dnf5 (fedora) | systemd | 3.12.15 (rocky, alma), 3.14.10 (fedora) |
| Suse | opensuse: openSUSE Leap 16.0 | zypper | systemd | 3.13.14 |
| Archlinux | arch: Archlinux 20261101.0.620205 | pacman | systemd | 3.14.9 |
| Alpine | alpine: Alpine 3.24.3 | apk | openrc | 3.14.10 |

Fedoras `dnf5` zeigt, dass eine Familie zwei Paketmanager haben kann - deshalb ist
`ansible.builtin.package` (es wählt das passende Backend) nützlich. Ubuntu gehört zur
Debian-Familie. Arch ist ein Rolling Release: Seine "Version" ist eine Build-ID.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| `object of type 'dict' has no attribute 'distribution'` | ein Host aus Play 1 ist fehlgeschlagen oder nicht erreichbar, sein `ansible_facts` ist `{}` | `f.get('distribution', ...)` statt `f.distribution` |
| Die `alpine`-Zeile sagt `unreachable` und der Check fragt "did every host deliver facts?" | auf Alpine fehlt Python, der Host ist bei "Gathering Facts" gescheitert | zuerst 0.02 machen |
| `hostvars['x']['ansible_facts']` ist undefiniert | `x` war in keinem Play dieses Laufs | zuerst Facts für `x` sammeln, oder `default({})` |
| "Premature end of stream waiting for become success" / `sudo: not found` | `become: true` ins `localhost`-Play kopiert: der Control-Container hat kein `sudo`, der Benutzer `learner` hat keine Rechte | kein `become` in Play 2 - es schreibt nur unter `/lab/work` |
| Der Check besteht mit einer handgetippten Datei | der Check prüft die Form, nicht die Werte | die Datei mit dem Template erzeugen |

### Praxis-Hinweise
Dieselbe Technik erzeugt Inventarberichte, Patchstand-Übersichten und die Compliance-Berichte
späterer Übungen. Bei einer großen Flotte spart ein Fact-Cache die Sammelzeit; ein Bericht, der
vollständig sein muss, sollte sagen, welche Hosts fehlen, statt sie wegzulassen.

### Weiterführend
- Lektion [L00 - Lab-Aufbau und Ansible-Grundlagen](../../../docs/lessons/L00-lab-and-ansible-basics.de.md): Facts, `hostvars` und wann die Facts anderer Hosts existieren.
- Übung [0.02 - Python auf Alpine per raw nachrüsten](../0.02-bootstrap-alpine/README.de.md): ohne sie hat Alpine keine Facts.
- Übung [4.01 - Reiner Audit-Lauf mit Compliance-Bericht](../../stage4-advanced/4.01-audit-only-report/README.de.md): Ergebnisse je Host, gesammelt in einem Bericht auf dem Control-Node.
- [Discovering variables: facts and magic variables](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_vars_facts.html) und [Controlling where tasks run: delegation](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_delegation.html)
- [Modul `ansible.builtin.template`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/template_module.html)

## Musterlösung

Anzeigen mit `lab solution 0.03`, anwenden mit `lab solve 0.03`.
