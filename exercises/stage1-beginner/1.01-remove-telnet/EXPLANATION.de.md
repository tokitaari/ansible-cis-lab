# 1.01 - Unsichere Client-Pakete entfernen: Erklärung

### Was der Check prüft
`lab check 1.01` führt `check.yml` auf `targets` aus: Es sammelt `package_facts` und prüft, dass
`'telnet' not in ansible_facts.packages` gilt. Danach führt es dein Playbook noch einmal mit
`--check` aus und erwartet `changed=0` (`meta.yml` sagt `idempotency: true`).

Der Check schaut nur auf den **Paketnamen**:

- Er prüft Anforderung 3 nicht. Eine Lösung mit `apt`, `dnf` oder `shell` besteht, solange das
  Paket weg ist.
- Er prüft nicht, dass das Programm weg ist. Auf Debian und Ubuntu besteht die Musterlösung,
  obwohl `/usr/bin/telnet` weiter funktioniert (gemessen, siehe unten).

### So funktioniert es

#### `package` wählt den Paketmanager
`ansible.builtin.package` ist ein Action-Plugin. Es liest den Fakt `ansible_facts.pkg_mgr` (oder
den Parameter `use:`) und ruft das passende Modul auf: `apt`, `dnf` (auf Fedora `dnf5`),
`zypper`, `pacman` oder `apk`. In ansible-core 2.21.6 werden die letzten drei nach
`community.general` umgeleitet. Für eine einfache Installation oder Entfernung ist es das
richtige Werkzeug. Sobald du Optionen eines Managers brauchst (`autoremove`, `purge`,
`update_cache`), nimmst du das spezifische Modul; `service` und `systemd` folgen demselben Gedanken
in [1.04](../1.04-disable-ftp-server/README.de.md).

#### `state: absent` ist tolerant
Ein nicht installiertes Paket ergibt `ok`, keinen Fehler. Gemessen mit der Musterlösung auf
frischen Targets: `changed=1` auf debian, ubuntu, rocky, alma, fedora und opensuse, `ok` auf arch
und alpine, und im zweiten Lauf überall `changed=0`. Auf arch und alpine ist `telnet` nicht einmal
ein Paketname (`pacman -Si telnet`: "was not found"; `apk info -e telnet`: no package named
telnet), und die Aufgabe ist trotzdem `ok`. Das beantwortet Bonus 3 für diese beiden Manager; dnf
und zypper wurden mit einem unbekannten Namen nicht getestet.

#### Der Paketname ist nicht das Programm
Das Programm steckt in unterschiedlichen Paketen:

- **Debian-Familie:** `inetutils-telnet`. `telnet` ist ein leeres Übergangspaket
  ("transitional dummy package for inetutils-telnet default switch") mit
  `Depends: inetutils-telnet`.
- **Arch:** `inetutils`, das auch `/usr/bin/hostname` liefert (`pacman -Ql`). Wer es entfernt,
  entfernt auch `hostname`.
- **Alpine:** `busybox-extras` (`/usr/bin/telnet` ist ein Link auf `/bin/busybox-extras`) oder
  `inetutils-telnet`. Das BusyBox des Basis-Images hat kein `telnet`-Applet.

Die Lab-Images liefern nur auf den Debian-, Red-Hat- und SUSE-Hosts einen Client mit. Einen von
Hand installierten Client auf arch oder alpine entfernt die Lösung nicht: Gemessen mit `inetutils`
auf arch und `busybox-extras` auf alpine meldet die Aufgabe `ok`, und `command -v telnet` gibt
weiter `/usr/bin/telnet` aus. Paketnamen je Familie führt Stufe 2 ein
([2.01](../../stage2-building-blocks/2.01-shadow-permissions-per-family/README.de.md)).

#### Debian und Ubuntu: das Übergangspaket
Gemessen auf Debian 13 und Ubuntu 26.04: `inetutils-telnet` ist als automatisch installiert
markiert, und `/usr/bin/telnet` ist ein `update-alternatives`-Link auf `/usr/bin/inetutils-telnet`.
Nach der Lösung ist `telnet` weg, `inetutils-telnet` nicht, `command -v telnet` gibt weiter
`/usr/bin/telnet` aus, und `apt-get -s autoremove` führt `inetutils-telnet` als entfernbar auf.
`lab check 1.01` besteht trotzdem.

Um das Programm zu entfernen, nenne das Paket, das es enthält. Gemessen auf ubuntu:
`ansible.builtin.package` mit `name: inetutils-telnet` und `state: absent` meldet `changed`,
`command -v telnet` gibt danach nichts aus, und die Musterlösung ist danach `changed=0`. Die
Alternative `ansible.builtin.apt` nur mit `autoremove: true` meldete auf debian `ok` und ließ das
Binary in unserem Lauf stehen (nicht untersucht): Nimm den expliziten Namen. Der Name existiert
nur in der Debian-Familie, in einem Play für alle Hosts gehört er also in Daten je Familie.

#### Check-Modus zeigt den Plan des Managers
`--check --diff` gibt auf debian den Probelauf von apt aus: "The following packages will be
REMOVED: telnet" und den Hinweis, `inetutils-telnet` "was automatically installed and is no
longer required". Dieser Hinweis ist das Übergangspaket-Problem in einer Zeile. Der Recap zeigt
`changed=1` auf sechs Hosts und `ok` auf arch und alpine (die Antwort auf Bonus 1).

### Hinweise je Familie
| Host | Client am Anfang | Paket | Nach der Lösung |
|---|---|---|---|
| debian 13 | `/usr/bin/telnet` | `telnet` 0.17+2.6 (leer) + `inetutils-telnet` | Übergangspaket weg, Binary bleibt |
| ubuntu 26.04 | `/usr/bin/telnet` | `telnet` 0.17+2.7 (leer) + `inetutils-telnet` | Übergangspaket weg, Binary bleibt |
| rocky 10.2, alma 10.2 | `/usr/bin/telnet` | `telnet-0.17-94.el10` | entfernt, Binary weg |
| fedora 44 | `/usr/bin/telnet` | `telnet-0.17-96.fc44` | entfernt, Binary weg |
| opensuse 16.0 | `/usr/bin/telnet` | `telnet-1.2` | entfernt, Binary weg |
| arch | keiner | kein Paket `telnet`; `inetutils` 2.8-1 im Repository | `ok` |
| alpine 3.24 | keiner | kein Paket `telnet`; `busybox-extras` und `inetutils-telnet` im Repository | `ok` |

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| `lab check` besteht, `telnet` startet auf Debian oder Ubuntu trotzdem | nur das Übergangspaket wurde entfernt | auch `inetutils-telnet` entfernen; mit `command -v telnet` testen |
| `which telnet` meldet "command not found" | `which` fehlt auf rocky, alma, fedora und opensuse | `command -v telnet` in einer Shell oder `ansible.builtin.stat` |
| arch oder alpine meldet `ok`, der Client ist noch da | `telnet` ist dort kein Paketname | `inetutils` oder `busybox-extras` je Familie beim Namen entfernen |
| das Playbook scheitert auf einer Familie | ein Manager-spezifisches Modul (`apt`, `dnf`) wurde benutzt | `ansible.builtin.package` |

### Praxis-Hinweise
Prüfe die Wirkung, nicht die Paketliste: `command -v telnet` (oder das Audit-Werkzeug deines
Benchmarks) beantwortet, ob der Client noch benutzbar ist. Dasselbe gilt für jede
Paketentfernung, bei der ein Paket umbenannt oder aufgeteilt wurde. Wer einen Client entfernt,
entfernt unter Umständen auch andere Programme aus demselben Paket (arch: `hostname`), lies also
vorher die Dateiliste.

### Weiterführend
- Lektion [L02 - Sichere Änderungen](../../../docs/lessons/L02-safe-changes.de.md): `--check --diff`, was sich ändert und was nur so aussieht.
- Lektion [L03 - Basis-Härtung](../../../docs/lessons/L03-base-hardening.de.md): Pakete, Dienste, Dateien, SSH und sudo an einem Ort.
- Übung [1.04 - FTP-Server stoppen und deaktivieren](../1.04-disable-ftp-server/README.de.md): `package_facts` neben `service`.
- [Modul `ansible.builtin.package`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/package_module.html) und [Modul `ansible.builtin.package_facts`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/package_facts_module.html)

## Musterlösung

Anzeigen mit `lab solution 1.01`, anwenden mit `lab solve 1.01`.
