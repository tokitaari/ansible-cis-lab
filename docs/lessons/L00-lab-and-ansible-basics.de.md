# L00 - Lab-Aufbau und Ansible-Grundlagen

*[English](L00-lab-and-ansible-basics.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 0.01, 0.02, 0.03, 0.04 | 1.6 | ~25 Min. | - |

Bevor du irgendetwas härtest, musst du wissen, was du verwaltest, ob du es erreichst und wie
Ansible aus einem Task eine Änderung auf einem entfernten Host macht; diese Lektion erklärt die
Bausteine des Labs und die vier Ansible-Ideen, auf denen jede spätere Übung aufbaut: Inventar,
Modulausführung, Facts und Idempotenz.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] beschreiben, wie der Control-Node die acht Targets erreicht und welches Konto und welche Rechte er nutzt
- [ ] das Lab-Inventar lesen, Hosts mit Patterns auswählen und ein Pattern prüfen, ohne dich zu verbinden
- [ ] erklären, was auf dem Target passiert, wenn ein Modul läuft, und warum manche Hosts keine Module ausführen können
- [ ] entscheiden, wann `raw` das richtige Werkzeug ist und warum es deine Hilfe braucht, um Änderungen zu melden
- [ ] Facts wie `os_family` für Entscheidungen nutzen und wissen, wann Facts anderer Hosts verfügbar sind
- [ ] vorhersagen, ob ein Task idempotent ist, und es mit einem zweiten Lauf oder `--check --diff` prüfen

## Theorie

### Das Lab: ein Control-Node, acht Targets

Ansible ist agentenlos und arbeitet im Push-Modell: Auf einem verwalteten Host läuft dauerhaft
nichts. Der Control-Node öffnet SSH-Verbindungen, schickt kleine Programme (Module), sammelt
deren JSON-Ergebnisse ein und schließt die Verbindung wieder. Im Lab sieht das so aus:

```
Docker-Host (natives Linux oder die Linux-VM von Docker Desktop / WSL2)
└── Netzwerk "lab" (Bridge)
    ├── control   Ansible, das lab-CLI, dein /lab/work  (hier arbeitest du)
    └── Targets   debian ubuntu rocky alma fedora opensuse arch alpine
                  sshd + Init-System (systemd, OpenRC auf alpine), Konto "ansible"
```

So greifen die Teile ineinander:

- **Authentifizierung.** Der Control-Node erzeugt ein SSH-Schlüsselpaar im gemeinsamen Volume
  `lab-keys`. Jedes Target installiert beim Start den öffentlichen Schlüssel für das Konto
  `ansible` (`lab-keysync`). Es gibt kein Passwort, nur den Schlüssel.
- **Rechte.** `ansible` darf per sudo ohne Passwort jeden Befehl als root ausführen. Genau das
  nutzt `become: true` (ad-hoc: `-b`). Ohne `become` laufen deine Tasks als `ansible`.
- **Konfiguration.** Die Variable `ANSIBLE_CONFIG` zeigt auf `/lab/ansible/ansible.cfg`. Dort
  stehen das Inventar, `remote_user`, der Schlüssel, `interpreter_python = auto_silent` (Python
  auf dem Target ohne Warnung finden) und `pipelining = True` (Module durch die offene
  SSH-Sitzung schicken statt temporäre Dateien zu kopieren). Weil `ANSIBLE_CONFIG` gesetzt ist,
  wird eine `ansible.cfg` im aktuellen Verzeichnis **nicht** gelesen.
- **Deine Arbeit.** Alles, was du schreibst, liegt in `/lab/work/<id>/` (`lab start <id>` legt
  es an). Das `lab`-CLI zeigt Übungen, Hinweise und Erklärungen und führt die Prüfungen aus.
- **Zurücksetzen.** Auf dem Host baut `./lab.sh reset <host|all>` (Windows-PowerShell:
  `.\lab.ps1`) ein Target in seinem ursprünglichen, absichtlich nicht konformen Zustand neu
  auf. Ein kaputtes Target gehört zum Lernen dazu und ist kein Unglück.

Die Targets erreichst du genau wie Server: per SSH, als unprivilegiertes Konto, das per sudo
eskaliert. `docker exec` würde all das umgehen und die falschen Gewohnheiten einüben.

### Inventar und Patterns

Das Inventar beantwortet die Frage *was verwalte ich?* Das Lab-Inventar
(`/lab/ansible/inventory/hosts.yml`) verschachtelt Gruppen: `targets` enthält eine Gruppe pro
OS-Familie, und jede Familiengruppe enthält Hosts.

```yaml
all:
  children:
    targets:
      children:
        redhat_family:
          hosts:
            rocky:
            alma:
            fedora:
```

Der Ausschnitt zeigt die Form: Ein Host ist über jede Gruppe oberhalb erreichbar (`fedora`
liegt in `redhat_family`, `targets` und `all`). Variablen hängen über `group_vars/<gruppe>.yml`
an Gruppen; das Lab hat `all.yml` (lab-weite Werte wie `lab_in_container`) und `targets.yml`
(SSH-Benutzer und Schlüssel). Ein Host bekommt die Zusammenführung aller seiner Gruppen,
spezifischere Gruppen gewinnen.

**Patterns** wählen Hosts für ein Ad-hoc-Kommando oder ein Play aus. Sie kombinieren Gruppen
und Hosts:

| Pattern | Bedeutung |
|---|---|
| `redhat_family` | alle Hosts der Gruppe |
| `debian:rocky` | Vereinigung (auch mit `,` geschrieben) |
| `targets:!alpine_family` | alle Targets außer der Gruppe |
| `redhat_family:&targets` | Schnittmenge |

Prüfe ein Pattern, bevor du es benutzt - `--list-hosts` löst es auf, ohne sich irgendwohin zu
verbinden, und `ansible-inventory` zeigt die Struktur und die zusammengeführten Variablen eines
Hosts:

```bash
ansible 'targets:!debian_family' --list-hosts
ansible-inventory --graph redhat_family
ansible-inventory --host rocky --yaml
```

Wenn "eine Variable den falschen Wert hat", ist `ansible-inventory --host` der erste
Debug-Schritt: Es zeigt, was Ansible nach dem Zusammenführen aller Gruppen für diesen Host
wirklich sieht.

### Wie ein Modul läuft

`ansible.builtin.ping` ist kein ICMP-Ping. Es ist ein Modul wie jedes andere: Ansible verbindet
sich per SSH, startet den Python-Interpreter auf dem Target, übergibt ihm den Modulcode und
erwartet JSON zurück. Ein Modullauf braucht auf dem Target also zwei Dinge: **SSH-Zugang und
Python**. Ein Host, der SSH-Logins annimmt, kann trotzdem jedes Modul scheitern lassen, wenn er
keinen nutzbaren Python-Interpreter hat.

Ad-hoc-Kommandos führen ein Modul einmal aus der Shell aus - gut, um sich umzusehen:

```bash
ansible debian_family -m ansible.builtin.command -a 'uptime'
ansible rocky -b -m ansible.builtin.command -a 'id -u'
ansible ubuntu -m ansible.builtin.ping -vvv
```

Die zweite Zeile zeigt `become`: Mit `-b` läuft der Befehl als root und gibt `0` aus. Mit
`-vvv` siehst du die SSH-Kommandozeile und wie das Modul übertragen wird - einmal lohnt sich das.

Einige Module funktionieren ohne Python auf dem Target. `ansible.builtin.raw` schickt eine
Kommandozeile per SSH und liefert zurück, was sie ausgibt; `ansible.builtin.script` kopiert ein
lokales Skript und führt es aus. Damit sind sie die Werkzeuge zum **Bootstrappen** eines Hosts,
der noch keine Module ausführen kann:

```bash
ansible arch -m ansible.builtin.raw -a 'uname -r'
```

Der Preis: `raw` weiß nichts über den Zustand des Systems. Es kann nicht beurteilen, ob es etwas
geändert hat, unterstützt keinen Check-Modus und meldet bei jedem Lauf `changed`. Wenn ein Task
seine Wirkung nicht selbst beurteilen kann, sagst du es Ansible mit `changed_when` - einem
Ausdruck über das registrierte Ergebnis:

```yaml
- name: Read the SSH client version
  hosts: debian_family
  gather_facts: false
  tasks:
    - name: Ask ssh for its version
      ansible.builtin.command: ssh -V
      register: ssh_version
      changed_when: false
    - name: Show it
      ansible.builtin.debug:
        var: ssh_version.stderr
```

`changed_when: false` passt zu einem Task, der nur liest. Ein Task, der *manchmal* etwas
ändert, braucht einen Ausdruck, der genau dann wahr ist - zum Beispiel anhand seiner Ausgabe
oder seines Rückgabecodes. Einen solchen Task für einen Bootstrap zu entwerfen, ist Übung 0.02.

### Facts

Facts sind das, was Ansible über einen Host weiß: Distribution, OS-Familie, Paketmanager,
Dienstmanager, Netzwerkschnittstellen, Python-Version und vieles mehr. Das Modul
`ansible.builtin.setup` sammelt sie; ein Play führt es zu Beginn automatisch aus
(`gather_facts: true` ist der Default). Weil `setup` ein Python-Modul ist, scheitert das
Sammeln der Facts auf einem Host ohne Python - das Play bricht dann vor deinem ersten Task ab,
deshalb muss ein Bootstrap-Play es abschalten.

Einzelne Facts siehst du dir ad-hoc mit einem Filter an:

```bash
ansible opensuse -m ansible.builtin.setup -a 'filter=ansible_os_family'
```

In Playbooks liest du Facts aus dem Dictionary `ansible_facts`, in dem das Präfix `ansible_`
entfällt: `ansible_facts['os_family']`. Ansible legt die Namen mit Präfix standardmäßig auch als
eigene Variablen an (`ansible_os_family`), aber das ist eine Einstellung
(`inject_facts_as_vars`), die man abschalten kann; `ansible_facts[...]` funktioniert immer.
Facts treffen Plattformentscheidungen:

```yaml
- name: React to the OS family
  hosts: targets
  tasks:
    - name: Only on RedHat-family hosts
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} uses {{ ansible_facts['pkg_mgr'] }}"
      when: ansible_facts['os_family'] == 'RedHat'
```

Facts gehören zu dem Host, der sie gemeldet hat. `hostvars['<host>']` gibt Zugriff auf die
Variablen und Facts jedes Hosts, `groups['<gruppe>']` listet die Hosts einer Gruppe, und
`inventory_hostname` ist der Name des aktuellen Hosts:

```yaml
- name: Look at another host's facts
  hosts: debian_family
  tasks:
    - name: Show what ubuntu reported
      ansible.builtin.debug:
        msg: "{{ hostvars['ubuntu']['ansible_facts']['distribution_version'] | default('no facts') }}"
```

So wie es dasteht, geben beide Hosts die Ubuntu-Version aus: Jeder Host des Plays hat zuerst
seine Facts gesammelt. Mit `-l debian` erscheint `no facts`: Die Facts von `ubuntu` gibt es
erst, wenn ein Play im selben Lauf sie gesammelt hat (oder ein Fact-Cache konfiguriert ist).
Denk daran, sobald ein Host oder `localhost` Daten von anderen braucht.

### Idempotenz: den Zustand beschreiben, nicht die Schritte

Ein Härtungs-Playbook läuft wieder und wieder - nach Änderungen, nach Updates, auf neuen Hosts.
Es muss deshalb einen **Sollzustand** beschreiben, und jeder Task darf nur ändern, was davon
abweicht. Module wie `file`, `copy`, `template`, `package` und `service` vergleichen den
aktuellen mit dem gewünschten Zustand und melden:

- `ok` - schon wie gewünscht, nichts getan
- `changed` - etwas wurde geändert, um den Zustand zu erreichen
- `failed` / `skipped` / `unreachable` - selbsterklärend

```yaml
- name: Desired state, not a command
  hosts: debian_family
  become: true
  tasks:
    - name: Directory for local notes exists
      ansible.builtin.file:
        path: /etc/lab-notes
        state: directory
        owner: root
        group: root
        mode: "0750"
```

Führe es zweimal aus. Der erste Lauf zeigt `changed=1` pro Host, der zweite `changed=0`: Das
Verzeichnis existiert bereits mit dem richtigen Besitzer und Modus. Dieser zweite Lauf ist der
Test, den jedes Playbook in diesem Lab bestehen muss, und `lab check` führt ihn für dich aus.

Zwei Werkzeuge lassen dich schauen, bevor du springst:

```bash
ansible-playbook notes.yml --check --diff
```

`--check` fragt jedes Modul, was es ändern *würde*, ohne es zu ändern; `--diff` zeigt den
Unterschied (Dateiinhalte, Rechte). Module, die ihre Wirkung nicht vorhersagen können, werden im
Check-Modus übersprungen - `raw` immer, `command` und `shell`, solange sie kein `creates` oder
`removes` haben.

`command` und `shell` sind die üblichen Idempotenz-Brecher: Ansible kann nicht wissen, was eine
Kommandozeile tut, also meldet es jedes Mal `changed`. Nimm lieber ein Modul, das den Zustand
verwaltet; ist ein Befehl unvermeidbar, ergänze `creates`/`removes` oder `changed_when`.

## CIS-Hintergrund

Die CIS Benchmarks sind Konfigurations-Baselines pro Betriebssystem; Lektion L01 behandelt ihren
Aufbau, ihre Level und Profile. Zwei Ideen daraus zählen schon hier:

- **Jedes Paket ist Angriffsfläche.** CIS empfiehlt, Software zu entfernen, die ein System nicht
  braucht. Ansible braucht Python auf dem verwalteten Host, also ist die Installation eine
  bewusste Abwägung zugunsten der Verwaltbarkeit - dokumentiere sie oder bleib bei
  `raw`/`script`, wo Python nicht akzeptabel ist. Dasselbe gilt für das Konto auf dem Host:
  passwortloses sudo für `ansible` ist ein privilegierter Weg auf jeden Host und muss auch so
  geschützt werden (Umgang mit dem Schlüssel, wer den Control-Node benutzen darf).
  Rechteausweitung ist Kontrolle 5.2 in [dem Kontrollkatalog](../../cis/controls.yml).
- **Keine kostenlose Aufklärung verteilen.** Kontrolle 1.6 (Level 1) verlangt Login-Banner, die
  vor unbefugter Nutzung warnen und nichts über Betriebssystem oder Version verraten. Übung 0.04
  ist die erste Härtungsänderung des Labs und setzt genau dort an.

Ab jetzt wird jeder Härtungs-Task zweimal geprüft: Erreicht er den geforderten Zustand, und
bleibt der zweite Lauf ruhig? Ein Playbook, das einen Host bei jedem Lauf "repariert",
verdeckt echte Abweichungen.

## Plattformunterschiede

| os_family | Hosts | Python im Lab-Image | `pkg_mgr` | `service_mgr` |
|---|---|---|---|---|
| Debian | debian, ubuntu | ja | apt | systemd |
| RedHat | rocky, alma, fedora | ja | dnf (Fedora: dnf5) | systemd |
| Suse | opensuse | ja | zypper | systemd |
| Alpine | alpine | **nein** (Bootstrap in 0.02) | apk | openrc |
| Archlinux | arch | ja | pacman | systemd |

Die Familie ist die Dimension, entlang der sich Paketnamen, Dienstnamen, Dateipfade und Defaults
unterscheiden - deshalb gruppiert das Inventar danach. Beachte, dass eine Familie nicht ein
System ist: Ubuntu gehört zur Debian-Familie, Fedora hat einen anderen `pkg_mgr`-Wert als Rocky
und Alma. `ansible.builtin.package` und `ansible.builtin.service` wählen anhand dieser Facts das
passende Backend-Modul.

### In den Lab-Containern

- Die Targets führen ihr echtes Init-System als PID 1 aus (systemd, OpenRC auf Alpine), in
  privilegierten Containern; Dienste, sshd und sudo verhalten sich wie auf einer VM.
- Alle Targets teilen sich den Kernel des Docker-Hosts: Der Fact `kernel` ist auf jedem Target
  gleich. Unter nativem Linux ist es der Kernel des Hosts selbst; mit Docker Desktop (macOS,
  Windows) oder WSL2 der Kernel der Linux-VM, in der Docker läuft. Kernelweite Einstellungen
  werden im Lab deshalb konfiguriert, aber nicht angewendet - siehe
  [Container-Grenzen](../CONTAINER_LIMITS.de.md).
- Manche Facts sind in Containern unvollständig. Zum Beispiel hat `ansible_facts['mounts']`
  keinen Eintrag für das Overlay-Root-Dateisystem; Übung 5.02 kommt darauf zurück.
- Alpine kommt absichtlich ohne Python: Minimale Images, Appliances und Netzwerkgeräte haben es
  oft nicht, und Bootstrappen ist eine Fähigkeit, die du in der Praxis brauchst.

## Stolperfallen

| Symptom | Ursache | Abhilfe |
|---|---|---|
| `ping` scheitert, obwohl SSH zum Host funktioniert | `ping` ist ein Python-Modul, der Host hat kein nutzbares Python | Python per `raw` nachrüsten oder den Host nur mit `raw`/`script` verwalten |
| Ein Play scheitert bei "Gathering Facts" vor deinem ersten Task | das Sammeln der Facts führt `setup` aus, das Python braucht | `gather_facts: false` für das Bootstrap-Play |
| Ein Task ist bei jedem Lauf `changed` | `raw`, `command` oder `shell` können ihre Wirkung nicht beurteilen | ein Zustandsmodul nehmen oder `creates`/`removes`/`changed_when` |
| Eine Datei bekommt seltsame Rechte wie `1204` | `mode: 644` ist die YAML-Ganzzahl 644, die Ansible dezimal liest | Modi immer quoten: `mode: "0644"` |
| Einstellungen in deiner eigenen `ansible.cfg` wirken nicht | `ANSIBLE_CONFIG` ist im Lab gesetzt und gewinnt gegen `./ansible.cfg` | Kommandozeilenoptionen oder Play-Keywords nutzen, oder `ANSIBLE_CONFIG=./ansible.cfg` für ein Kommando |
| `hostvars['x']['ansible_facts']` ist undefiniert | kein Play in diesem Lauf hat Facts für `x` gesammelt | zuerst Facts für diese Hosts sammeln (oder einen Fact-Cache nutzen) |
| "Permission denied" beim Schreiben nach `/etc` | der Task läuft als `ansible` | `become: true` am Play oder Task |

## Übungen

| Übung | Was diese Lektion dafür vorbereitet |
|---|---|
| [0.01](../../exercises/stage0-foundations/0.01-lab-tour/README.de.md) | Lab-Aufbau, Inventar, Patterns, Ad-hoc-Kommandos, warum ein Modullauf scheitert |
| [0.02](../../exercises/stage0-foundations/0.02-bootstrap-alpine/README.de.md) | `raw`, Facts brauchen Python, `become`, `changed_when` |
| [0.03](../../exercises/stage0-foundations/0.03-facts-report/README.de.md) | Facts, `ansible_facts`, `hostvars`, `groups`, wann Facts anderer Hosts existieren |
| [0.04](../../exercises/stage0-foundations/0.04-first-playbook-banner/README.de.md) | Sollzustand, Idempotenz, gequotete Modi, `--check --diff`, CIS 1.6 |

Eine Übung startest du mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Ein Host nimmt deinen SSH-Login an, aber `ansible <host> -m ansible.builtin.ping` scheitert.
   Was ist der wahrscheinlichste Grund, und welches Modul funktioniert trotzdem?

   <details><summary>Antwort</summary>

   `ping` ist ein Python-Modul, kein ICMP: Es braucht einen nutzbaren Python-Interpreter auf dem
   Target. SSH funktioniert, der Transport ist also in Ordnung - Python fehlt oder wird nicht
   gefunden. `ansible.builtin.raw` (und `script`) funktionieren trotzdem, weil sie nur einen
   Befehl per SSH schicken.

   </details>

2. Du willst einen Befehl auf allen Targets außer der Debian-Familie ausführen. Wie schreibst du
   das Pattern, und wie prüfst du es, ohne einen Host anzufassen?

   <details><summary>Antwort</summary>

   `'targets:!debian_family'` (in Anführungszeichen, weil `!` für die Shell eine Bedeutung hat).
   `ansible 'targets:!debian_family' --list-hosts` löst das Pattern gegen das Inventar auf und
   gibt die Hosts aus, ohne sich zu verbinden.

   </details>

3. Du legst eine `ansible.cfg` mit `forks = 1` nach `/lab/work/demo/` und startest dein Playbook
   von dort. Nichts ändert sich. Warum?

   <details><summary>Antwort</summary>

   Ansible liest genau eine Konfigurationsdatei, und die Umgebungsvariable `ANSIBLE_CONFIG` steht
   in der Suchreihenfolge ganz vorn. Das Lab setzt sie auf `/lab/ansible/ansible.cfg`, also wird
   die Datei im aktuellen Verzeichnis ignoriert. Nimm `--forks 1` oder setze `ANSIBLE_CONFIG`
   für dieses Kommando.

   </details>

4. Ein Task nutzt `ansible.builtin.command` für ein Werkzeug, das nichts ändert, und jeder Lauf
   zeigt `changed`. Warum, und welche Möglichkeiten gibt es?

   <details><summary>Antwort</summary>

   Ansible kann nicht wissen, was eine beliebige Kommandozeile tut, also meldet `command` immer
   `changed`. Für einen rein lesenden Befehl ergänzt du `changed_when: false`. Legt der Befehl
   eine Datei an, lässt `creates:` Ansible ihn überspringen, sobald die Datei existiert. Am
   besten ist ein Modul, das den Zustand direkt verwaltet.

   </details>

5. Ein Play auf `localhost` liest `hostvars['rocky']['ansible_facts']['distribution']` und bekommt
   einen Fehler wegen einer undefinierten Variable. Was fehlt?

   <details><summary>Antwort</summary>

   Facts werden pro Host gesammelt, und ein Play auf `localhost` sammelt nur die Facts von
   `localhost`. Die Facts von `rocky` gibt es nur, wenn ein Play im selben Lauf (oder ein
   konfigurierter Fact-Cache) sie gesammelt hat. Ohne das hat `hostvars['rocky']` zwar
   Inventarvariablen, aber keine `ansible_facts`.

   </details>

6. Alle acht Targets melden denselben Fact `kernel`, obwohl sie fünf verschiedene Distributionen
   ausführen. Warum, und was folgt daraus für kernelbezogene Härtung im Lab?

   <details><summary>Antwort</summary>

   Container haben keinen eigenen Kernel; sie nutzen alle den Kernel des Docker-Hosts.
   Einstellungen ohne Namespace (Kernelmodule, viele Sysctls, das Audit-Subsystem) würden den
   Host verändern, deshalb schreibt das Lab nur ihre Konfigurationsdateien und wendet sie nicht an.

   </details>

7. Warum muss ein Härtungs-Playbook beim zweiten Lauf `changed=0` melden?

   <details><summary>Antwort</summary>

   Es beschreibt einen Zustand; ist der erreicht, gibt es nichts mehr zu tun. Ein Playbook, das
   bei jedem Lauf Änderungen meldet, taugt nicht zum Erkennen von Abweichungen, macht `--check`
   als Compliance-Test nutzlos und schreibt oft wirklich jedes Mal etwas neu (Dienste neu
   starten, Zeitstempel zurücksetzen).

   </details>

## Weiterführendes

- [How to build your inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html) und [Patterns: targeting hosts and groups](https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html)
- [Introduction to ad hoc commands](https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html)
- [Discovering variables: facts and magic variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_vars_facts.html)
- [Validating tasks: check mode and diff mode](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html)
- [Modul `ansible.builtin.raw`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/raw_module.html) und [Interpreter discovery](https://docs.ansible.com/ansible/latest/reference_appendices/interpreter_discovery.html)
- [Ansible configuration settings](https://docs.ansible.com/ansible/latest/reference_appendices/config.html) - Suchreihenfolge von `ansible.cfg`
- `man 5 sshd_config` (`Banner`), `man 5 issue`
