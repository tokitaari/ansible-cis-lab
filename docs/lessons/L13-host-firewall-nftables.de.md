# L13 - Host-Firewall mit nftables: die Regeln ändern, über die du den Host erreichst

*[English](L13-host-firewall-nftables.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 4.07 | 4 | ~30 Min. | L02, L05, L09 |

Eine Host-Firewall ist die eine Härtungsänderung, die die Verbindung abschneiden kann, über die sie
eingespielt wird. Eine falsche SSH-Regel lässt keine Aufgabe fehlschlagen; sie macht die nächste
Aufgabe und jedes spätere Play unerreichbar. Drei Gewohnheiten machen das beherrschbar: Die
Firewall lebt in einer eigenen Tabelle, damit niemandes fremde Regeln angefasst werden; die Regeln
werden so geladen, dass man sie prüfen, wiederholen und zurücknehmen kann; und die Änderung wird
mit einem Rückweg gemacht, der nicht von der Verbindung abhängt, die sie zerstören könnte. Eine
vierte Frage folgt daraus: Was ist nach einem Neustart noch da? Diese Lektion behandelt alle vier.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] erklären, warum eine Host-Firewall genau eine Tabelle besitzt und nie das ganze Regelwerk leert, und sagen, wer sonst noch Regeln schreibt
- [ ] sagen, wie mehrere Base-Chains an einem Hook zusammenwirken und warum ein accept in deiner Tabelle das drop einer anderen Tabelle nicht aufheben kann
- [ ] den reinen Prüfmodus von nft benutzen und sagen, was er beweist und was er nicht wissen kann
- [ ] vorhersagen, was das zweimalige Laden einer Regeldatei bewirkt, was ein fehlgeschlagenes Laden zurücklässt und was das Löschen einer fehlenden Tabelle meldet
- [ ] einen Totmannschalter beschreiben und die Anforderungen an den Job nennen, der die Änderung zurücknimmt
- [ ] eine neue SSH-Verbindung von einer wiederverwendeten unterscheiden und sagen, wie man den Unterschied erzwingt und belegt
- [ ] das Timeout des Verbindungstests im Verhältnis zur Verzögerung des Rollbacks wählen
- [ ] die drei Dinge nennen, die stimmen müssen, damit ein Regelwerk einen Neustart überlebt: Datei, Dienst und aktives Regelwerk

## Theorie

### Wer Regeln schreibt: Tabellen, Hooks und deine eigene Tabelle

Der Paketfilter des Kernels wird geteilt. Docker, Kubernetes, fail2ban, libvirt und firewalld
schreiben alle Regeln in denselben Netzwerk-Namespace, und keines fragt nach. nftables ordnet
Regeln in **Tabellen**. Eine Tabelle gehört zu einer Adressfamilie (`ip`, `ip6`, `inet` für beide,
und ein paar weitere) und enthält **Chains**. Eine Chain, die an einer Stelle im Weg eines Pakets
eingehängt ist, ist eine **Base-Chain**: Sie nennt einen **Hook** (`input` für Pakete an diesen
Host, `forward` für Pakete, die er weiterleitet, `output` für Pakete, die er sendet, dazu
`prerouting` und `postrouting`), eine **Priorität** und eine **Policy**, das Urteil für Pakete, die
keine Regel entschieden hat. Regeln innerhalb einer Chain laufen der Reihe nach.

Wichtig für das Nebeneinander: **Die Base-Chains verschiedener Tabellen am selben Hook laufen
alle.** Ein `accept` beendet nur die Auswertung seiner eigenen Chain; ein `drop` beendet sie
endgültig. Ein Paket kommt durch, wenn keine Chain es verwirft, und deine Tabelle hat keinen
Einfluss darauf, was eine andere verwirft. Das erste Play zeigt es mit zwei Demo-Tabellen auf Port
65001 des Loopback-Interfaces, einem Port, an dem nichts lauscht. Es installiert außerdem nftables,
weil die Lab-Images es nicht mitbringen (und die Debian-Images keinen Paketindex, wie in L09):

```yaml
- name: Two tables on one hook
  hosts: targets:!suse_family
  become: true
  vars:
    probe: >-
      import socket; s = socket.socket(); s.settimeout(2);
      print('refused' if s.connect_ex(('127.0.0.1', 65001)) == 111 else 'timeout')
  tasks:
    - name: Refresh the apt index (the Debian images ship without one)
      ansible.builtin.apt:
        update_cache: true
      changed_when: false
      check_mode: false
      when: ansible_facts.os_family == 'Debian'
    - name: Install nftables
      ansible.builtin.package:
        name: nftables
        state: present
    - name: Table A accepts port 65001
      ansible.builtin.command:
        cmd: nft -f -
        stdin: |
          table inet lesson13_a {
            chain input {
              type filter hook input priority filter; policy accept;
              tcp dport 65001 accept
            }
          }
      changed_when: false
      check_mode: false
    - name: Connect to port 65001 with table A only
      ansible.builtin.command:
        argv: [python3, -c, "{{ probe }}"]
      register: only_a
      changed_when: false
      check_mode: false
    - name: Table B, someone else's, drops the same port
      ansible.builtin.command:
        cmd: nft -f -
        stdin: |
          table inet lesson13_b {
            chain input {
              type filter hook input priority filter; policy accept;
              tcp dport 65001 drop
            }
          }
      changed_when: false
      check_mode: false
    - name: Connect again with both tables
      ansible.builtin.command:
        argv: [python3, -c, "{{ probe }}"]
      register: both
      changed_when: false
      check_mode: false
    - name: Remove both demo tables
      ansible.builtin.command: "nft delete table inet {{ item }}"
      loop: [lesson13_a, lesson13_b]
      changed_when: false
      check_mode: false
    - name: Flush the whole ruleset, but only in a throw-away network namespace
      ansible.builtin.command:
        argv:
          - unshare
          - --net
          - sh
          - -c
          - nft add table ip lesson13_foreign && nft flush ruleset && nft list tables | wc -l
      register: flushed
      changed_when: false
      check_mode: false
    - name: Compare the results
      ansible.builtin.debug:
        msg:
          - "table A only: {{ only_a.stdout }}, with table B: {{ both.stdout }}"
          - "tables left after the flush in the throw-away namespace: {{ flushed.stdout }}"
```

Die Ausgabe ist `table A only: refused, with table B: timeout`. *Refused* heißt: Das Paket hat den
Host erreicht, der mit einem Reset geantwortet hat, weil nichts lauscht; *timeout* heißt: Es wurde
stillschweigend verworfen. Tabelle A erlaubt den Port in beiden Läufen, und das drop von Tabelle B
gewinnt. Die letzte Aufgabe ist der Grund für die Regel „eigene Tabelle besitzen“: Sie nutzt den
Wegwerf-Netzwerk-Namespace aus L05, legt eine Tabelle an, die für fremde Regeln steht, leert das
ganze Regelwerk und listet, was übrig ist. Es ist nichts übrig, denn `flush ruleset` kennt keinen
Besitzer. Führe es nie im eigenen Namespace eines Targets aus: Dort liegen Dockers DNS-Regeln (siehe
[Container-Grenzen](../CONTAINER_LIMITS.de.md)), und auf dem Arch-Target zeigt `nft list tables`
eine Tabelle `ip nat`, bevor du irgendetwas konfiguriert hast.

Drei Folgen ergeben sich. Eine Firewall verwaltet **ihre eigene Tabelle** und sonst nichts. Eine
Regel darin, die SSH erlaubt, garantiert keine Erreichbarkeit, weil eine andere Tabelle trotzdem
verwerfen kann. Und eine `drop`-Policy in deiner Base-Chain verwirft, was deine Regeln nicht
erlauben, auch wenn eine andere Tabelle es durchgelassen hätte; die Policies von `input`,
`forward` und `output` sind also eine Designentscheidung, kein Standardwert.

### Regeln laden: prüfen, Transaktion, Wiederholung

Drei Fragen entscheiden, wie Regeln in den Kernel kommen: Ist die Datei annehmbar, was lässt ein
fehlgeschlagenes Laden zurück, und was bewirkt erneutes Laden? Das nächste Play beantwortet sie an
einer Demo-Tabelle mit `nft -c`, dem reinen Prüfmodus (in der Session nftables 1.0.9, die Targets
des Labs bringen ihre eigene Version mit), und `-f -`, das die Regeln von der Standardeingabe liest.
Es setzt voraus, dass das vorige Play nftables installiert hat:

```yaml
- name: What nft does with a rule file
  hosts: targets:!suse_family
  become: true
  vars:
    good_table: |
      table inet lesson13_demo {
        chain input {
          type filter hook input priority filter; policy accept;
          tcp dport 65002 counter
        }
      }
  tasks:
    - name: Check a file with a syntax error
      ansible.builtin.command:
        cmd: nft -c -f -
        stdin: "table inet lesson13_demo {\n  chain input { foo }\n}\n"
      register: syntax
      changed_when: false
      failed_when: false
      check_mode: false
    - name: Check a file that names a set which does not exist
      ansible.builtin.command:
        cmd: nft -c -f -
        stdin: |
          table inet lesson13_demo {
            chain input {
              type filter hook input priority filter; policy accept;
              ip saddr @nosuchset accept
            }
          }
      register: reference
      changed_when: false
      failed_when: false
      check_mode: false
    - name: Check a good file
      ansible.builtin.command:
        cmd: nft -c -f -
        stdin: "{{ good_table }}"
      register: good
      changed_when: false
      check_mode: false
    - name: Is the table loaded after the checks?
      ansible.builtin.command: nft list tables
      register: after_check
      changed_when: false
      check_mode: false
    - name: Load a good table and a broken one in one file
      ansible.builtin.command:
        cmd: nft -f -
        stdin: |
          table inet lesson13_good {
            chain input {
              type filter hook input priority filter; policy accept;
            }
          }
          table inet lesson13_bad {
            chain input {
              type filter hook input priority filter; policy accept;
              ip saddr @nosuchset accept
            }
          }
      register: atomic
      changed_when: false
      failed_when: false
      check_mode: false
    - name: Is the good table there?
      ansible.builtin.command: nft list tables
      register: after_atomic
      changed_when: false
      check_mode: false
    - name: Load the same good file twice
      ansible.builtin.command:
        cmd: nft -f -
        stdin: "{{ good_table }}"
      loop: [1, 2]
      changed_when: false
      check_mode: false
    - name: Show the chain
      ansible.builtin.command: nft list chain inet lesson13_demo input
      register: chain
      changed_when: false
      check_mode: false
    - name: Delete a table that is not there
      ansible.builtin.command: nft delete table inet lesson13_missing
      register: missing
      changed_when: false
      failed_when: false
      check_mode: false
    - name: Remove the demo table
      ansible.builtin.command: nft delete table inet lesson13_demo
      changed_when: false
      check_mode: false
    - name: Summary
      ansible.builtin.debug:
        msg:
          - "syntax error: rc {{ syntax.rc }}, {{ syntax.stderr_lines[0] }}"
          - "unknown set: rc {{ reference.rc }}, {{ reference.stderr_lines[0] }}"
          - "good file: rc {{ good.rc }}, table loaded afterwards: {{ 'lesson13_demo' in after_check.stdout }}"
          - "good + broken table: rc {{ atomic.rc }}, good table loaded: {{ 'lesson13_good' in after_atomic.stdout }}"
          - "rules in the chain after two loads: {{ chain.stdout_lines | select('search', 'dport 65002') | list | length }}"
          - "delete of a missing table: rc {{ missing.rc }}, {{ missing.stderr_lines[0] }}"
```

Die Zusammenfassung lautet (die letzte Zeile geht in der nächsten weiter):

```
syntax error: rc 1, /dev/stdin:2:21-21: Error: syntax error, unexpected '}'
unknown set: rc 1, /dev/stdin:4:14-23: Error: No such file or directory
good file: rc 0, table loaded afterwards: False
good + broken table: rc 1, good table loaded: False
rules in the chain after two loads: 2
delete of a missing table: rc 1, Error: Could not process rule: No such file or directory
```

Lies sie als fünf Tatsachen.

- **Die Prüfung fängt mehr als Syntax.** Auch der Verweis auf ein Set, das nicht existiert,
  scheitert, aber der Text ist derselbe `No such file or directory` wie bei einer fehlenden
  Tabelle; der Positionsbereich hinter dem Dateinamen zeigt auf das schuldige Wort. Die Prüfung
  ändert nichts: Die gute Datei wurde geprüft, und danach existiert keine Tabelle.
- **Was die Prüfung nicht wissen kann**, ist, ob die Regeln dich hineinlassen. Eine Datei, die
  alles verwirft, SSH eingeschlossen, besteht sie. Das ist die Lehre von `validate` aus L02, noch
  einmal: Der Prüfer beurteilt die Datei, nicht die Wirkung.
- **Ein Laden ist eine Transaktion.** Die Datei mit einer guten und einer kaputten Tabelle hat
  keine von beiden geladen. Aus einem einzelnen `nft -f` kann keine halb angewendete Firewall
  entstehen.
- **Eine Tabellendeklaration mit Inhalt ergänzt, was existiert.** Zweimaliges Laden derselben
  Datei hinterließ zwei Kopien der Regel in der Chain. Eine nackte Deklaration, `table inet name`
  ohne Rumpf, ist anders: Sie ist kein Fehler, ob die Tabelle existiert oder nicht (getestet), und
  ändert nichts.
- **Ein Löschen braucht etwas zu löschen.** Das Löschen einer Tabelle, die es nicht gibt, ist ein
  Fehler mit rc 1.

Aus diesen Tatsachen kannst du ableiten, was eine Regeldatei enthalten muss und was eine Aufgabe
drumherum tun muss, damit sie einmal oder hundertmal mit demselben Ergebnis geladen werden kann.
Das verlangt 4.07. Das Regelwerk der Übung selbst wird hier nicht gezeigt, und auch keine
Aufgabenreihenfolge, die sie löst.

### Eine Änderung, die du vielleicht nicht überlebst: der Totmannschalter

Eine Firewall-Änderung kann die Verbindung abschneiden, die sie ausführt. Scheitert danach das
Play, ist womöglich keine Verbindung mehr da, mit der man etwas reparieren könnte. Die
professionelle Antwort ist ein **Totmannschalter**: Zuerst ein Rückgängigmachen scharf stellen, dann
die Änderung machen, das Ergebnis über eine *neue* Verbindung testen und das Rückgängigmachen nur
abbrechen, wenn der Test gelingt. Gelingt er nie, löst es sich von selbst aus. Die Idee ist
einfach; sie funktioniert nur, wenn vier Bausteine sich richtig verhalten, und jeder lässt sich
einzeln mit etwas Harmlosem testen.

**Baustein 1: Der Rücknahme-Job lebt auf dem Target und überlebt die Aufgabe.** Das nächste Play
startet einen Job, der fünf Sekunden braucht, und zeigt, dass die Startaufgabe nicht auf ihn wartet:

```yaml
- name: A job that outlives the task that started it
  hosts: targets:!suse_family
  gather_facts: false
  tasks:
    - name: Remove the marker of an earlier run
      ansible.builtin.command: rm -f /tmp/lesson13-job
      changed_when: false
      check_mode: false
    - name: Clock before the job
      ansible.builtin.command: date +%s
      register: t0
      changed_when: false
      check_mode: false
    - name: Start a job that needs five seconds
      ansible.builtin.shell: "sh -c 'sleep 5; touch /tmp/lesson13-job' >/dev/null 2>&1 & echo started"
      changed_when: false
      check_mode: false
    - name: Clock after the start task
      ansible.builtin.command: date +%s
      register: t1
      changed_when: false
      check_mode: false
    - name: Wait for the marker
      ansible.builtin.wait_for:
        path: /tmp/lesson13-job
        timeout: 20
      check_mode: false
    - name: Clock after the marker appeared
      ansible.builtin.command: date +%s
      register: t2
      changed_when: false
      check_mode: false
    - name: Compare
      ansible.builtin.debug:
        msg: "the start task took {{ t1.stdout | int - t0.stdout | int }} s, the marker appeared after {{ t2.stdout | int - t0.stdout | int }} s"
```

Die erste Zahl enthält zwei Uhrablesungen über SSH und bleibt unter den fünf Sekunden des Jobs (auf
den Lab-Targets zwei bis drei Sekunden); die Markierung erscheint nach etwa acht: Der Job läuft für
sich. Ob er auch den Verlust der
Verbindung überlebt, hängt davon ab, wie er gestartet wurde. In einem Test über die `ssh`-Verbindung
zu einem lokalen sshd (ansible-core 2.21.6, ein Rechner) wurde die Verbindung zwei Sekunden nach
dem Start getötet: Jobs, die `shell` (einfaches `&` und `nohup`) und eine `async`-Aufgabe mit
`poll: 0` gestartet hatten, liefen trotzdem zu Ende, ein von `raw` gestarteter Job lief nicht zu
Ende (die Ursache wurde nicht untersucht). Die Lehre für einen Rollback: Teste ihn gezielt und auf
jeder Plattform, die du benutzt, und nimm es nicht einfach an.

**Baustein 2: `async` startet einen Job, aber nichts bricht ihn ab.** L09 hat `async` und
`async_status` eingeführt. `async_status` hat zwei Modi, `status` und `cleanup`, und keine
Möglichkeit, einen Job zu stoppen: `cleanup` auf einem laufenden Job löschte dessen Statusdatei,
der Job lief weiter und wurde fertig (eine Markierungsdatei erschien), und ein späteres `status`
las `finished: true` ohne Ergebnis. Ein Job, der womöglich abgebrochen werden muss, braucht eine
Identität, die das Play behält, etwa eine Prozess-ID. Wie du sie festhältst, ist Teil von 4.07.

**Baustein 3: Eine neue Verbindung ist nicht dasselbe wie eine neue Aufgabe.** Die `ansible.cfg`
des Labs setzt `ControlPersist=60s`: Die erste Aufgabe öffnet eine SSH-Verbindung, spätere
Aufgaben benutzen sie weiter. Das ist effizient und eine Falle für einen Aussperr-Test, weil die
Pakete einer bestehenden Verbindung von einer neuen Regel meist ausgenommen sind. Die
Umgebungsvariable `SSH_CONNECTION` der entfernten Sitzung (Client-Adresse, Client-Port,
Server-Adresse, Server-Port) unterscheidet Verbindungen:

```yaml
- name: Is it the same connection?
  hosts: targets:!suse_family
  gather_facts: false
  tasks:
    - name: Read the client side of the SSH connection
      ansible.builtin.command: printenv SSH_CONNECTION
      register: first
      changed_when: false
      check_mode: false
    - name: Read it again in the same play
      ansible.builtin.command: printenv SSH_CONNECTION
      register: second
      changed_when: false
      check_mode: false
    - name: Close the connection that Ansible keeps open
      ansible.builtin.meta: reset_connection
    - name: Read it on the new connection
      ansible.builtin.command: printenv SSH_CONNECTION
      register: third
      changed_when: false
      check_mode: false
    - name: Compare the client ports
      ansible.builtin.debug:
        msg: "first {{ first.stdout.split()[1] }}, second {{ second.stdout.split()[1] }}, after the reset {{ third.stdout.split()[1] }}"
```

Die ersten beiden Ports sind gleich, der dritte weicht ab: `meta: reset_connection` hat die
gehaltene Verbindung geschlossen, und die nächste Aufgabe hat eine neue geöffnet. Das Play läuft
absichtlich ohne `become`; mit `become` war die Variable auf allen acht Targets `unset` (die
Rechteausweitung reicht sie nicht weiter). In einem Test, in dem die Firewall *neue* Verbindungen
zu sshd verwarf, antwortete eine gewöhnliche `ping`-Aufgabe trotzdem über die alte Verbindung. Eine
Aufgabe, die bloß gelingt, beweist also nichts darüber, ob du dich neu verbinden könntest.

**Baustein 4: `wait_for_connection` ist der Test.** Das Modul versucht es, bis eine Verbindung
funktioniert und ein Ping durch sie gelingt. Seine Vorgaben in ansible-core 2.21.6: `timeout` 600
Sekunden, `connect_timeout` 5, `sleep` 1, `delay` 0. Gibt es auf, scheitert die Aufgabe mit
`timed out waiting for ping module test`, gefolgt vom Verbindungsfehler. Es öffnet für jeden
Versuch eine eigene Verbindung: Im selben Aussperr-Test scheiterte es mit und ohne ein
`meta: reset_connection` davor. Das explizite Zurücksetzen ist also für das, was *nach* dem Test
kommt, für Aufgaben, die nicht stillschweigend die alte Verbindung weiter benutzen sollen. Der
Test hat außerdem ein Timeout, und für das Timeout gilt eine Regel: Es muss kürzer sein als die
Verzögerung des Rollbacks. Löst der Rollback zuerst aus, repariert er den Host, während der Test
noch wartet, und der Test meldet Erfolg auf einem Host, der gerade zurückgerollt wurde. Mit den
600 Sekunden der Vorgabe ist das der Normalfall, kein Randfall. Prüfe nach dem Test auch den
aktiven Zustand.

Was der Test nicht beweisen kann: Er zeigt, dass der Kontrollknoten von seiner eigenen Adresse eine
neue Verbindung öffnen kann. Über andere Administratoren, Monitoring oder Backup-Hosts sagt er
nichts, und er kann kein Aussperren zeigen, wenn die getestete Regel den Kontrollknoten gar nicht
blockiert. Wie diese vier Bausteine um ein Regelwerk zusammenpassen, ist die Übung 4.07.

### Was einen Neustart überlebt: Datei, Dienst und aktives Regelwerk

Mit `nft` geladene Regeln leben im Kernel-Speicher. Ein Neustart oder der Neustart eines
Containers leert sie. Persistenz heißt: ein Dienst, der beim Start eine Datei lädt. Drei Dinge
müssen also stimmen, und jedes kann allein falsch sein:

- die **Datei** ist das Rezept; eine unveränderte Datei sagt nichts über den Kernel;
- der **Dienst** führt das Rezept aus, beim Start und womöglich bei Stopp und Reload;
- das **aktive Regelwerk** ist die Wahrheit; `nft list table ...` zeigt es.

Eine unveränderte Datei bei leerem Kernel ist die übliche Überraschung nach einem Neustart. Darum
sollte eine Aufgabe, die entscheidet „muss das geladen werden?“, auf den aktiven Zustand schauen
und nicht nur auf die Datei. Auf systemd-Hosts sagt dir die Unit, was der Dienst tut; unter OpenRC
das Init-Skript. Lies sie, rate nicht:

```
systemctl cat nftables.service        # systemd: ExecStart, ExecReload, ExecStop, Type
systemctl show -p ExecStop nftables   # der Stopp-Befehl, falls es einen gibt
rc-service -l | grep nftables         # OpenRC: gibt es überhaupt einen Dienst?
cat /etc/init.d/nftables              # OpenRC: was start, stop und save tun
```

Auf dem Arch-Target war die Unit `Type=oneshot` und standardmäßig deaktiviert. Eine
`oneshot`-Unit führt einen Befehl aus und ist fertig; ob systemd sie danach weiter als aktiv
anzeigt, hängt von `RemainAfterExit` ab, und in beiden Fällen ist das Regelwerk Kernel-Zustand,
den der Status der Unit nicht beschreibt. Die `Exec`-Zeilen nennen die Datei, die der Dienst lädt,
und sagen, was bei Stopp und Reload geschieht. Was ein Stopp-Befehl mit dem Regelwerk macht, macht
er mit **allen** Tabellen, nicht nur mit deiner; lies vor dem Neustart eines Firewall-Dienstes auf
einem Host mit anderen Schreibern, was er beim Herunterfahren tut. Die Ansible-Seite derselben
Unterscheidung: `enabled: true` des `service`-Moduls ändert, was beim Boot geschieht,
`state: started` handelt jetzt, und `state: restarted` stoppt immer zuerst und startet dann.

## CIS-Hintergrund

Abschnitt 4 der Benchmarks (ID `4` im [Kontrollkatalog](../../cis/controls.yml)) verlangt eine
funktionierende Host-Firewall mit einer Standardhaltung „verwerfen“ gegenüber eingehendem
Datenverkehr und ausdrücklichen Freigaben für das, was der Host wirklich anbietet. Sie schützt vor
den Diensten, die jede Paketinstallation und jedes Entwicklerwerkzeug still öffnet: eine
Datenbank, die an alle Interfaces gebunden ist, ein Debug-Port, ein Verwaltungsdienst. Eine
Firewall macht sie nicht sicher; sie macht sie von dort unerreichbar, wo niemand sie erreichen
sollte, und verschafft Zeit, wenn einer davon eine Schwachstelle hat.

„Eine“ ist das Schlüsselwort. Die Benchmarks akzeptieren nftables, firewalld, iptables oder ufw,
aber nicht zwei zugleich: Zwei Schreiber mit verschiedenen Vorstellungen von der Standard-Policy
erzeugen Regeln, die niemand entworfen hat. Deshalb ist auch firewalld, das Standard-Frontend auf
vollständigen Installationen der RedHat- und Suse-Familien (Distributionsdokumentation, im Lab nicht
geprüft), ein Entweder-oder zu einem handgeschriebenen nftables-Regelwerk. Die übliche Basis lässt
den Verkehr auf dem Loopback-Interface zu, die Antworten auf Verbindungen, die der Host selbst
begonnen hat, und die Verwaltungsports aus einem bekannten Bereich, und verwirft den Rest. Ausgehenden
Verkehr zu filtern ist eine Designentscheidung, die Wissen darüber verlangt, mit wem der Server
spricht; viele Basislinien lassen ihn offen, und die Übung bietet ihn als Bonus an. Die genauen
Empfehlungsnummern unterscheiden sich je Benchmark und Version; schlage sie im PDF deiner
Distribution nach.

## Plattformunterschiede

| os_family | nftables im Lab-Image | Andere Frontends im Image | Init | Hinweise |
|---|---|---|---|---|
| Debian | nicht installiert | keine | systemd | Paketindex im Image fehlt: vor der Installation aktualisieren |
| RedHat | nicht installiert | keine | systemd | firewalld ist auf einer vollständigen Installation das übliche Frontend |
| Suse | nicht installiert | keine | systemd | firewalld ist das übliche Frontend; 4.07 schließt diese Familie aus |
| Alpine | nicht installiert | keine | OpenRC | braucht ab 0.02 Python für die Ansible-Module |
| Archlinux | installiert (v1.1.7) | `iptables` mit dem nf_tables-Backend | systemd | `nftables.service` existiert und ist deaktiviert; `nft list tables` zeigt `ip nat` |

Das Paket heißt in allen Familien `nftables`. Die Version unterscheidet sich zwischen den Images (1.1.3 bei Debian bis 1.1.7 bei Arch); die
Fehlertexte des Lade-Beispiels waren auf allen sieben Targets identisch (der Session-Test nutzte 1.0.9).

### In den Lab-Containern

Jedes Target hat seinen eigenen Netzwerk-Namespace, die Firewall eines Containers berührt also
weder einen anderen noch den Host. Docker hält seine DNS-Regeln in diesem Namespace, das ist der
Grund für die Regel „eigene Tabelle, nie leeren“ in den [Container-Grenzen](../CONTAINER_LIMITS.de.md).
Die sieben Targets von 4.07 liegen in einem Subnetz (`172.31.250.0/24` bei dieser Installation).
Adresse und Präfix kommen aus dem Fakt `default_ipv4`, den es nur gibt, wenn die Netzwerk-Fakten
erhoben wurden: Mit `gather_subset: min` fehlt der Fakt, und ein Template, das ihn nutzt, scheitert
mit `object of type 'dict' has no attribute 'default_ipv4'`, mit `min,network` ist der Fakt da (das
Präfix ist ein String, `'24'`). Host kaputt? `./lab.sh reset <host>` stellt ihn wieder her.

## Stolperfallen

| Symptom | Ursache | Abhilfe |
|---|---|---|
| Die Prüfung besteht und SSH ist weg | die Prüfung beurteilt Syntax und Verweise, nicht was die Regeln tun | mit Rückweg ausrollen und über eine neue Verbindung testen |
| `Error: No such file or directory` bei einer Regel, die ein Set nennt | ein fehlendes Set und eine fehlende Tabelle geben denselben Text | den Positionsbereich hinter dem Dateinamen lesen; mit `nft list tables` auflisten, was existiert |
| Dieselbe Regel steht nach einem zweiten Lauf doppelt da | eine Tabellendeklaration mit Inhalt ergänzt eine bestehende Tabelle | das Laden von einem definierten Zustand aus beginnen lassen (die Tatsachen des Abschnitts zum Laden) |
| `delete table` scheitert auf einem frischen Host | es gibt noch keine Tabelle (rc 1) | das Löschen muss auch dann sicher sein, wenn nichts existiert |
| Regeln von Docker oder fail2ban verschwinden | `flush ruleset` entfernt jede Tabelle im Namespace | eine Tabelle verwalten und sonst nichts |
| `'dict object' has no attribute 'default_ipv4'` | `gather_subset: min` lässt die Netzwerk-Fakten weg | das Netzwerk-Subset erheben |
| Eine Testaufgabe gelingt nach dem Aussperren | gewöhnliche Aufgaben benutzen die offene Verbindung weiter | mit einer Aufgabe testen, die eine neue Verbindung öffnet, etwa `wait_for_connection` |
| Der Test besteht auf einem Host, der gerade zurückgerollt wurde | der Rollback löste aus, während der Test noch wartete | ein Test-Timeout kürzer als die Rollback-Verzögerung; danach den aktiven Zustand prüfen |
| Der Rollback löst nie aus | der Job starb mit seiner Sitzung (ein `raw`-Job tat es in einem Test) | den Job so starten, dass er überlebt, und das auf jeder Plattform testen |
| Die Tabelle ist nach einem Neustart weg, die Datei unverändert | die Datei ist ein Rezept, der Kernel hält den Zustand | den aktiven Zustand prüfen und über den Dienst persistieren |

## Übungen

| Übung | Was diese Lektion vorbereitet |
|---|---|
| [4.07](../../exercises/stage4-advanced/4.07-nftables-safe-rollout/README.de.md) | eine Tabelle besitzen, ein Laden prüfen und wiederholen, der Totmannschalter mit einer neuen Verbindung als Test, was ein Neustart behält |

Eine Übung startest du mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Warum verwaltet eine Firewall für einen gemeinsam genutzten Host eine Tabelle, statt ein
   vollständiges Regelwerk zu laden, das mit einem Flush beginnt?

   <details><summary>Antwort</summary>

   Ein Flush entfernt jede Tabelle im Namespace, auch die Regeln von Docker, fail2ban oder
   Kubernetes, und nichts stellt sie wieder her. Eine eigene Tabelle lässt sich als Einheit
   ersetzen, ohne die anderen anzufassen.

   </details>

2. Deine Tabelle erlaubt TCP-Port 8080, und eine andere Tabelle am selben Hook verwirft ihn. Was
   geschieht mit einer Verbindung zu diesem Port, und was, wenn die andere Tabelle ihn nur erlaubt?

   <details><summary>Antwort</summary>

   Das Paket wird verworfen: Alle Base-Chains am Hook laufen, und ein drop ist endgültig. Erlaubt
   die andere Tabelle ihn nur, entscheiden trotzdem Policy und Regeln deiner Chain, ob das Paket
   durchkommt. Ein accept beendet die Auswertung einer Chain, nicht die des Hooks.

   </details>

3. `nft -c` liefert für deine Regeldatei 0. Nenne zwei Dinge, die es dir nicht sagt.

   <details><summary>Antwort</summary>

   Ob die Regeln deine SSH-Verbindung hineinlassen (es prüft die Datei, nicht die Wirkung), und
   ob der Zustand des Kernels nach dem Laden der erwartete ist, etwa wenn eine frühere Tabelle noch
   da ist. Auch ob die Regeln zu deinem Netz passen, sagt es nicht.

   </details>

4. Eine Datei deklariert eine Tabelle mit einer Regel. Nach zwei Ladevorgängen enthält die Chain
   die Regel doppelt, und ein `delete table` auf einem frischen Host scheitert. Was sagen diese
   beiden Tatsachen über eine Regeldatei, die immer wieder geladen werden muss?

   <details><summary>Antwort</summary>

   Das Deklarieren einer bestehenden Tabelle mit Inhalt ergänzt sie, das Laden muss also von einem
   definierten Zustand ausgehen. Ein einfaches delete braucht eine existierende Tabelle. Zusammen
   heißt das: Die Datei muss ihren Boden selbst so bereiten, dass es funktioniert, ob die Tabelle
   existiert oder nicht.

   </details>

5. Der Rollback löst nach 60 Sekunden aus. Warum ist `timeout: 600` für den Verbindungstest eine
   schlechte Wahl?

   <details><summary>Antwort</summary>

   Blockieren die neuen Regeln den Kontrollknoten, repariert der Rollback den Host in Sekunde 60,
   während der Test noch wartet. Der nächste Versuch gelingt, und das Play meldet eine gesunde
   Firewall auf einem Host, der zurückgerollt wurde. Der Test muss aufgeben, bevor der Rollback
   auslösen kann.

   </details>

6. Eine Aufgabe nach der Änderung gelingt. Warum ist das kein Beweis, dass du dich noch
   verbinden kannst, und wie belegst du, dass eine neue Verbindung funktioniert?

   <details><summary>Antwort</summary>

   Mit `ControlPersist` benutzen spätere Aufgaben die offene Verbindung weiter, deren Pakete meist
   als bestehender Verkehr erlaubt sind. Ein Test muss eine neue Verbindung öffnen:
   `wait_for_connection` tut das, und `meta: reset_connection` erzwingt es für alles Folgende. Der
   Client-Port von `SSH_CONNECTION` zeigt, auf welcher Verbindung eine Aufgabe läuft.

   </details>

7. `systemctl status nftables` sagt, die Unit sei erfolgreich gelaufen. Was sagt dir das über das
   aktive Regelwerk, und wie findest du heraus, was ein Neustart des Dienstes damit macht?

   <details><summary>Antwort</summary>

   Nichts über das aktive Regelwerk: Der Zustand der Unit ist nicht der Zustand des Kernels, also
   schau mit `nft list table ...` nach. Was ein Neustart bewirkt, erfährst du, indem du die Unit
   (`systemctl cat`) oder das Init-Skript liest und ansiehst, was seine Stopp-, Start- und
   Reload-Befehle mit dem Regelwerk tun.

   </details>

## Weiterführendes

- [`ansible.builtin.meta`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/meta_module.html) - `reset_connection`
- [`ansible.builtin.wait_for_connection`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/wait_for_connection_module.html) - `timeout`, `connect_timeout`, `sleep`, `delay`
- [`ansible.builtin.async_status`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/async_status_module.html) - die Modi `status` und `cleanup`
- [nft(8)](https://manpages.debian.org/unstable/nftables/nft.8.en.html) - die Kommandozeile, `-c`, `-f` und die Verben für Tabellen und Chains
- [Netfilter hooks](https://wiki.nftables.org/wiki-nftables/index.php/Netfilter_hooks) - Hooks, Prioritäten und wie Base-Chains zusammenwirken
- [Atomic rule replacement](https://wiki.nftables.org/wiki-nftables/index.php/Atomic_rule_replacement) - warum eine Datei eine Transaktion ist
- [systemd.service(5)](https://manpages.debian.org/unstable/systemd/systemd.service.5.en.html) - `Type=oneshot`, `RemainAfterExit`, `ExecStop`
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: dead-man switch, hook (netfilter),
  nftables, `wait_for_connection`
