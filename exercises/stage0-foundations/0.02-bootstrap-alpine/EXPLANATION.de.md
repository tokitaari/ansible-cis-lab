# 0.02 - Python auf Alpine per raw nachrüsten: Erklärung

### Was der Check prüft
`lab check 0.02` führt `check.yml` auf `alpine_family` aus: `ansible.builtin.ping` funktioniert
(es braucht Python) und `python3 --version` gibt eine `Python 3`-Version aus. Danach führt es
dein Playbook noch einmal mit `--check` aus und erwartet `changed=0` (`meta.yml` sagt
`idempotency: true`).

**Dieser zweite Teil sieht deinen Guard nicht.** `raw` unterstützt den Check-Modus nicht, unter
`--check` wird es also übersprungen (`skipping:`, Recap `skipped=1`, im Lab gemessen) und nur der
`ping` läuft. Ein Playbook ohne Shell-Guard oder mit `changed_when: true` besteht `lab check` und
meldet trotzdem bei jedem echten Lauf `changed=1` (gemessen an einem Ersatz mit lokaler
Verbindung: Lauf 2 `changed=1`, `--check`-Lauf `changed=0`). Der Test, der zählt, ist dein
eigener zweiter Lauf:

```bash
ansible-playbook playbook.yml     # erster Lauf: changed=1 auf alpine
ansible-playbook playbook.yml     # zweiter Lauf: changed=0
```
Der Check verlangt außerdem nicht, dass `raw` benutzt wurde: Von Hand installiertes Python
besteht ebenfalls.

### So funktioniert es

#### Das Muster
```yaml
- name: Install python3 if missing
  ansible.builtin.raw: test -e /usr/bin/python3 || { apk add --no-cache python3 && echo INSTALLED; }
  register: bootstrap
  changed_when: "'INSTALLED' in bootstrap.stdout"
```
Zwei Ebenen, beide nötig. Der Shell-Guard (`test -e ... ||`) macht den *Befehl* idempotent. Die
Markierung macht die *Meldung* ehrlich: `echo INSTALLED` läuft erst, nachdem `apk add` gelungen
ist (`&&`); eine fehlgeschlagene Installation lässt also den Task scheitern (Rückgabecode ungleich
null), statt die Markierung auszugeben. `changed_when` macht aus der Markierung `changed`.

#### Warum `gather_facts: false`
Der implizite erste Task `setup` ist ein Python-Modul. Auf einem frischen Alpine bricht das Play
vor deinem ersten Task ab:

```
TASK [Gathering Facts]
fatal: [alpine]: FAILED! => ... The following modules failed to execute: ansible.legacy.setup.
```
Das Starter-Play hat kein `gather_facts: false` - unverändert gestartet scheitert es hier. Ist
Python installiert, sammeln spätere Plays ganz normal Facts.

#### `become` und `raw`
`raw` läuft wie jedes Modul über die Verbindung, einschließlich der Rechteerhöhung: Mit
`become: true` verpackt Ansible den Befehl in `sudo -H -S -n -u root /bin/sh -c '...'` und führt
ihn über `ssh -tt` aus (gemessen mit den SSH-Optionen des Labs gegen einen lokalen sshd). Das Ziel
braucht also `sudo` und eine POSIX-Shell, kein Python: Auf Alpine gibt es `/usr/bin/sudo`, und
`/bin/sh` ist BusyBox. `apk add` ändert das System und braucht Root; der Account `ansible` hat
keine Rechte.

#### Was `raw` zurückgibt
Die Ausgabe kommt mit `\r\n`-Zeilenenden an (das Terminal durch `-tt`), vergleiche also mit `in`,
nicht mit `==`. Mit dem `LogLevel=ERROR` des Labs blieb stderr leer.

#### Warum `--no-cache`
Ein frisches Alpine hat keinen Paketindex: `/var/cache/apk` ist leer, und ein einfaches
`apk add --simulate jq` scheitert mit `unable to select packages: jq (no such package)`.
`apk add --no-cache` holt den Index für genau diesen Aufruf (die Simulation listet 14 Pakete für
`python3`). Die Mirrors aus `/etc/apk/repositories` müssen aus dem Container erreichbar sein
(`dl-cdn.alpinelinux.org`).

#### Was Python auf Alpine kostet
`apk stats` vorher und nachher: 44 -> 58 Pakete und 22,4 MB -> 63,1 MB installiert, also etwa
**40 MB** für Python 3.14 und seine Bibliotheken; das Paket `python3` allein hat 22 MiB. Python
braucht Ansible auf dem verwalteten Host - eine bewusste Abwägung, siehe die Hinweise unten.

#### Bonus: ganz ohne Python
Mit `raw` und `script` allein kannst du Befehle und Skripte ausführen, verlierst aber alles, was
die Modulmaschinerie braucht: Facts, Check-Modus, `template`, `copy`, die `changed`-Meldung.
`script` läuft auf einem Host ohne Python (gemessen auf dem frischen Alpine). Alternativen sind
Pull-basierte Werkzeuge oder ein Image, das Python schon mitbringt.

### Hinweise je Familie
Die Übung läuft nur auf `alpine_family` (ein Host), deshalb gibt es keine Tabelle je Familie.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| Das Play scheitert bei "Gathering Facts" mit `ansible.legacy.setup` | noch kein Python, und Facts werden standardmäßig gesammelt | `gather_facts: false` |
| `ping`: "The module interpreter '/usr/bin/python3' was not found" | der Bootstrap ist noch nicht gelaufen | zuerst den `raw`-Task ausführen |
| `lab check` meldet "idempotent", aber jeder Lauf zeigt `changed=1` | `raw` wird im Check-Modus übersprungen | das Playbook selbst zweimal ausführen |
| Der Task ist immer `changed` | kein Guard, oder `changed_when` ohne die Markierung | Guard plus Markierung in der Ausgabe |
| `unable to select packages` | kein Paketindex auf dem frischen Host | `apk add --no-cache` |
| `bootstrap.stdout == 'INSTALLED'` trifft nie | `\r\n` in der `raw`-Ausgabe | `'INSTALLED' in bootstrap.stdout` |

### Praxis-Hinweise
CIS verlangt immer wieder, unnötige Pakete zu entfernen. Python ist *für Ansible* nötig, also
eine Abwägung: dokumentieren. Wo das nicht akzeptabel ist, bleibst du bei `raw` und `script`
oder nutzt ein Pull-basiertes Werkzeug. Auf Alpine sind die Kosten die 14 Pakete und etwa 40 MB
von oben.

### Weiterführend
- Lektion [L00 - Lab-Aufbau und Ansible-Grundlagen](../../../docs/lessons/L00-lab-and-ansible-basics.de.md): wie ein Modul läuft, `raw`, `changed_when`, Check-Modus.
- Übung [0.01 - Rundgang: Inventar und Erreichbarkeit](../0.01-lab-tour/README.de.md): woher der fehlschlagende `ping` kommt.
- Übung [0.03 - Facts: ein Bericht über acht Distributionen](../0.03-facts-report/README.de.md): braucht Python auf Alpine.
- [Modul `ansible.builtin.raw`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/raw_module.html) und [Modul `ansible.builtin.script`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/script_module.html)
- [Alpine Package Keeper](https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper) (`apk`, `--no-cache`)

## Musterlösung

Anzeigen mit `lab solution 0.02`, anwenden mit `lab solve 0.02`.
