# 0.01 - Rundgang: Inventar und Erreichbarkeit: Erklärung

### Was der Check prüft
`lab check 0.01` führt `check.yml` aus. `meta.yml` sagt `idempotency: false`: Die Übung ändert
nichts, einen zweiten Lauf gibt es also nicht. Der Check stellt sicher:
- `groups['targets']` hat 8 Hosts, `alpine_family` ist genau `['alpine']` und `redhat_family`
  hat 3 Hosts;
- jedes Target außer der Alpine-Familie antwortet auf `ansible.builtin.ping`.

Nicht getestet werden: die anderen Familiengruppen (`debian_family`, `suse_family`,
`arch_family`), der Inhalt von `notes.md` und dass Alpine fehlschlägt. Der Check lässt Alpine
mit Absicht aus, er besteht also auf einem frischen Lab genauso wie nach 0.02.

### So funktioniert es

#### Das Inventar als Baum
`ansible-inventory --graph` gibt aus (im Lab gemessen):
```
@all:
  |--@ungrouped:
  |--@targets:
  |  |--@debian_family:
  |  |  |--debian
  |  |  |--ubuntu
  |  |--@redhat_family:
  |  |  |--rocky
  |  |  |--alma
  |  |  |--fedora
  |  |--@suse_family:
  |  |  |--opensuse
  |  |--@arch_family:
  |  |  |--arch
  |  |--@alpine_family:
  |  |  |--alpine
```
`@ungrouped` ist eingebaut und hier leer. Die Gruppierung nach OS-Familie ist Absicht:
Paketnamen, Dienstnamen, Dateipfade und Defaults unterscheiden sich genau entlang dieser Linien.

#### Was `--host` zeigt
`ansible-inventory --host debian` gibt vier Variablen aus: `ansible_user`,
`ansible_ssh_private_key_file` (beide aus `group_vars/targets.yml`), `lab_in_container` und
`lab_org_name` (aus `group_vars/all.yml`). Es zeigt *Inventar*-Daten nach dem Zusammenführen
aller Gruppen, nicht die Einstellungen aus `ansible.cfg` - `remote_user` steht nicht darin. Wenn
"eine Variable den falschen Wert hat", ist das der erste Blick.

#### Muster
`ansible 'targets:!alpine_family' --list-hosts` löst zu 7 Hosts auf, ohne irgendwohin zu
verbinden. Setze das Muster in Anführungszeichen: `!` hat für die Shell eine Bedeutung.
`redhat_family:&targets` ist die Schnittmenge, `debian:rocky` die Vereinigung.

#### Warum `ping` auf Alpine scheitert
`ping` ist ein Python-Modul, kein ICMP. Mit `pipelining = True` (die `ansible.cfg` des Labs)
kopiert Ansible keine Datei auf das Ziel: Es startet den Python-Interpreter über die
SSH-Sitzung und füttert ihn mit dem Modulcode (`-vvv` zeigt keine `PUT`-, `sftp`- oder
`scp`-Zeile). Mit `interpreter_python = auto_silent` sucht es auf dem Ziel nach einem
Interpreter. Die sieben anderen Hosts haben einen; das frische Alpine-Image nicht, und der
Fallback `/usr/bin/python3` scheitert:

```
msg: The module interpreter '/usr/bin/python3' was not found.
module_stderr: /bin/sh: /usr/bin/python3: not found
rc: 127
```
SSH selbst funktioniert - nur Python fehlt. Das ist der Unterschied zwischen `FAILED`
(verbunden, Modul fehlgeschlagen) und `UNREACHABLE` (keine Verbindung, zum Beispiel keine Route
oder falscher Schlüssel).

#### Was ohne Python noch geht
`ansible.builtin.raw` schickt eine Befehlszeile per SSH und liefert, was sie ausgibt: Die
Musterlösung liest `/etc/os-release` und findet `no python3`. `ansible.builtin.script` kopiert
ein lokales Skript und führt es aus - auf dem frischen Alpine lief es ebenfalls (gemessen). Beide
sind die Werkzeuge, um einen Host zu bootstrappen, und das ist 0.02.

#### Bonus: die Hosts vergleichen
`setup -a 'filter=ansible_distribution*'` liefert überall dieselben Schlüssel mit
unterschiedlichen Werten: `ansible_distribution_version` ist `13.7` auf debian, `26.04` auf
ubuntu, `10.2` auf rocky und alma, `44` auf fedora, `16.0` auf opensuse, `3.24.3` auf alpine -
und `20261101.0.620205` auf arch, einem Rolling Release mit einer Build-ID statt einer Version
(die Hauptversion ist `20261101`). Ubuntu meldet `ansible_distribution_file_variety: Debian`.
Auf Alpine geht das erst nach 0.02.

### Hinweise je Familie
Interpreter, den `ping` gefunden hat (gemessen am 2026-11-07, die Versionen ändern sich mit dem
Image-Build):

| `os_family` | Hosts | Python für Ansible |
|---|---|---|
| Debian | debian, ubuntu | `/usr/bin/python3.13`, `/usr/bin/python3.14` |
| RedHat | rocky, alma, fedora | `/usr/bin/python3.12` (rocky, alma), `/usr/bin/python3.14` (fedora) |
| Suse | opensuse | `/usr/bin/python3.13` |
| Archlinux | arch | `/usr/bin/python3.14` |
| Alpine | alpine | auf einem frischen Lab keiner (`/usr/bin/python3` nicht gefunden); nach 0.02 `/usr/bin/python3.14` |

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| `ping` auf alpine: "The module interpreter '/usr/bin/python3' was not found" | kein Python im frischen Alpine-Image | per `raw` nachrüsten (0.02) |
| Gar kein Host schlägt fehl | 0.02 wurde vorher gemacht, Alpine hat jetzt Python | `./lab.sh reset alpine` auf dem Host stellt den Fehler wieder her |
| `lab check 0.01` besteht, obwohl du die Fehlermeldung nicht gelesen hast | der Check testet deine Erkenntnisse nicht | halte sie für dich in `notes.md` fest |

### Praxis-Hinweise
In Produktion trägt das Inventar auch `ansible_host`, Jump-Hosts (`ansible_ssh_common_args`) und
kommt oft aus einer dynamischen Quelle (Azure, AWS, Satellite). Die Fragen bleiben dieselben:
Was verwalte ich, und komme ich heran? Ein Erreichbarkeitslauf mit `ping` vor jeder Änderung
kostet wenig, und die Trennung zwischen `UNREACHABLE` und `FAILED` sagt dir, ob du beim Netzwerk
oder beim Host suchen musst.

### Weiterführend
- Lektion [L00 - Lab-Aufbau und Ansible-Grundlagen](../../../docs/lessons/L00-lab-and-ansible-basics.de.md): die Konzepte vor dieser Übung (Inventar, Muster, wie ein Modul läuft).
- Übung [0.02 - Python auf Alpine per raw nachrüsten](../0.02-bootstrap-alpine/README.de.md): die Lösung für den fehlschlagenden Host.
- [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html) und [Patterns: targeting hosts and groups](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_patterns.html)
- [Interpreter discovery](https://docs.ansible.com/projects/ansible/latest/reference_appendices/interpreter_discovery.html) und das [Modul `ansible.builtin.raw`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/raw_module.html)

## Musterlösung

Anzeigen mit `lab solution 0.01`, anwenden mit `lab solve 0.01`.
