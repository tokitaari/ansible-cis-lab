# 0.04 - Erstes Härtungs-Playbook: SSH-Warnbanner: Erklärung

### Was der Check prüft
`lab check 0.04` führt `check.yml` auf allen acht Targets aus (mit `become`, minimale Facts). Für
`/etc/issue.net` stellt er sicher:
- der Text enthält `authorized` oder `authorised`, in beliebiger Schreibweise;
- er enthält keines von `\m`, `\r`, `\s`, `\v` (Regex `\\[mrsv]`);
- er enthält nicht den Fact `distribution` des Hosts, in beliebiger Schreibweise;
- Eigentümer `root`, Gruppe `root`, Modus `0644` (mit `stat` gelesen).

Danach führt er dein Playbook noch einmal mit `--check` aus und erwartet `changed=0`
(`meta.yml` sagt `idempotency: true`). Das ist hier ein echter Test: `copy` unterstützt den
Check-Modus.

Nicht getestet wird, gemessen mit der echten `check.yml` gegen jeden Text auf einem Host: andere
Escapes wie `\S`, `\l` oder `\n`; eine Versionsnummer ohne den Distributionsnamen; der Name einer
*anderen* Distribution; und ein Text wie "Unauthorized use is prohibited." besteht, weil
"unauthorized" das Wort "authorized" enthält. Geprüft wird nur `/etc/issue.net` - `/etc/issue`
und `/etc/motd` kommen in 2.06.

Eine Lücke zeigt sich auf arch. Der mitgelieferte Text lautet "Welcome to Arch Linux", der Fact
`distribution` ist `Archlinux` - der Check würde den Namen nicht bemerken (gemessen mit dem
Ausdruck des Checks an allen acht mitgelieferten Texten: nur arch wird übersehen). Der
mitgelieferte Text fällt wegen `\r \m` trotzdem durch, aber ein Banner, das nur die Escapes
streicht, besteht auf arch und nennt weiterhin die Distribution.

### So funktioniert es

#### `copy` und Idempotenz
`copy` vergleicht Prüfsumme, Eigentümer, Gruppe und Modus mit dem Sollzustand und handelt nur
bei Abweichungen. Die Musterlösung zeigt beim ersten Mal `changed=1` auf allen acht Hosts, beim
zweiten Mal `changed=0` (gemessen). `--check --diff` zeigt, was sich ändern würde, ohne es zu
ändern, hier auf fedora:

```
--- before: /etc/issue.net
+++ after: /etc/issue.net
@@ -1 +1 @@
-Welcome to Fedora Linux 44 (Container Image) \r \m
+Authorized access only. Activity on this system is monitored and logged.
```
Jeder Task, den du ab jetzt schreibst, muss sich so verhalten.

#### Den Modus quoten
`mode: 644` ist die YAML-Ganzzahl 644; Ansible liest sie als Dezimalzahl und schreibt oktal 1204 -
die Datei bekommt `--w----r-T` (gemessen). `mode: 0644` funktioniert, weil YAML 1.1 eine führende
Null als oktal liest, ist aber fragil, und `ansible-lint` meldet es als `yaml[octal-values]` (das
Gate des Labs prüft die Lösungen mit dem Profil `production`). Schreibe `mode: "0644"`.

#### Symbolische Links auf fedora
Auf fedora ist `/etc/issue.net` ein symbolischer Link (`-> ../usr/lib/issue.net`, 20 Byte), und
`/etc/issue` ebenso. `stat` im Check sieht den Link selbst, Modus `0777`: Auf einem frischen
fedora scheitert der Check mit `now: root:root 0777`. `copy` ersetzt den Link durch eine
reguläre Datei und lässt die Datei des Anbieters unberührt (gemessen an einem Symlink-Aufbau; im
Lab ist fedoras `/etc/issue.net` nach dem Lauf eine reguläre Datei mit 73 Byte, während
`/etc/issue` noch ein Link ist). Ein Paket-Update kann dein Banner nicht mehr über den Link
überschreiben.

#### Wer welche Datei liest
`/etc/issue` gibt der Konsolen-getty vor dem Login-Prompt aus, und die getty ersetzt darin
Escapes (`\r` Kernel-Release, `\m` Architektur; siehe `issue(5)`). sshd schickt die Datei, auf die
`Banner` zeigt, unverändert: Mit einem lokalen sshd kam eine Datei mit `Welcome to Testdistro 1.0
\r \m` mit wörtlichem `\r \m` an (gemessen). Über SSH verrät also der Distributionsname etwas, an
der Konsole auch Kernel und Architektur. CIS behandelt alle Banner-Dateien gleich.

sshd zeigt `/etc/issue.net` nur, wenn `Banner /etc/issue.net` konfiguriert ist. Das ist die
sshd-Härtung in 2.02; 2.06 hält fest, dass die Hosts ohne Banner starten.

#### Einordnung im Katalog
Control 1.6 in `cis/controls.yml` ("Login banners contain a legal warning and no OS
information", Level 1) nennt die Übungen 0.04, 2.06, 3.01 und 5.01. Diese hier deckt
`/etc/issue.net` ab; 2.06 alle drei Dateien.

### Hinweise je Familie
Alle acht Targets starten mit einem Text der Form "Welcome to <Distribution> <Version> \r \m"
(gemessen am 2026-11-07); nach der Lösung ist jede `/etc/issue.net` eine reguläre Datei mit 73
Byte.

| `os_family` | Hosts | `/etc/issue.net` am Anfang |
|---|---|---|
| Debian | debian, ubuntu | reguläre Datei: 46 Byte (Debian GNU/Linux 13 (trixie)), 36 Byte (Ubuntu 26.04.1 LTS) |
| RedHat | rocky, alma, fedora | rocky 47 und alma 48 Byte (mit dem Release-Namen in Klammern); fedora: symbolischer Link, 20 Byte |
| Suse | opensuse | reguläre Datei, 36 Byte (openSUSE Leap 16.0) |
| Archlinux | arch | reguläre Datei, 28 Byte ("Arch Linux", siehe die Lücke oben) |
| Alpine | alpine | reguläre Datei, 36 Byte (Alpine Linux v3.24) |

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| Die Datei bekommt den Modus `1204` (`--w----r-T`) | `mode: 644` ist eine YAML-Ganzzahl | `mode: "0644"` |
| Auf fedora sagt der Check `now: root:root 0777` | `/etc/issue.net` ist ein symbolischer Link | das Playbook ausführen, `copy` ersetzt den Link |
| Der Check besteht auf arch, aber das Banner sagt "Arch Linux" | er sucht nach `Archlinux` | gar keinen Distributionsnamen im Text |
| Der Check besteht mit `\S`, `\l` oder `\n` im Text | er sucht nur nach `\m \r \s \v` | gar keine Escapes in deinem Text |
| Über SSH sieht niemand das Banner | `Banner` ist in sshd nicht gesetzt | 2.02 (und 2.06) |

### Praxis-Hinweise
Bannertexte sind oft rechtliche Vorgaben (Betriebsrat, Rechtsabteilung). Halte sie in einer
Variable, damit sie zentral änderbar sind - das machst du in 2.06. Der Text vor der Anmeldung
(das `Banner` von sshd) warnt einen Eindringling; die Tagesmeldung kommt erst nach dem Login.

### Weiterführend
- Lektion [L00 - Lab-Aufbau und Ansible-Grundlagen](../../../docs/lessons/L00-lab-and-ansible-basics.de.md): Idempotenz, `--check --diff` und der CIS-Hintergrund zu Control 1.6.
- Übung [2.02 - SSH-Server-Härtung mit Jinja2-Template](../../stage2-building-blocks/2.02-sshd-template/README.de.md): wo `Banner` gesetzt wird.
- Übung [2.06 - Alle Login-Banner aus einem Template](../../stage2-building-blocks/2.06-banners-template-loop/README.de.md): dieselbe Idee für `/etc/issue`, `/etc/issue.net` und `/etc/motd`.
- [Modul `ansible.builtin.copy`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html)
- [`sshd_config(5)`: `Banner`](https://man.openbsd.org/sshd_config) und [`issue(5)`](https://man7.org/linux/man-pages/man5/issue.5.html)

## Musterlösung

Anzeigen mit `lab solution 0.04`, anwenden mit `lab solve 0.04`.
