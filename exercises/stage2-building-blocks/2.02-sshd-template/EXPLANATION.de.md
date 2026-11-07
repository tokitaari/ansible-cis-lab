# 2.02 - SSH-Server-Härtung mit Jinja2-Template: Erklärung

### Was der Check prüft
`lab check 2.02` führt `check.yml` auf `targets` aus: Er liest die **wirksame** Konfiguration mit
`sshd -T`, liest `/etc/ssh/sshd_config.d/00-cis-hardening.conf` und prüft die Werte der README -
manche als Schranke (`MaxAuthTries` höchstens 4, `LoginGraceTime` 1-60, `ClientAliveInterval`
1-15, `ClientAliveCountMax` 1-3), `MaxStartups` genau `10:30:60`, dazu `PermitRootLogin`,
`PermitEmptyPasswords` und `X11Forwarding` auf `no`. Danach läuft dein Playbook noch einmal mit
`--check` und muss `changed=0` melden.

- Die Datei muss das Wort "ansible" enthalten (Groß-/Kleinschreibung egal). `AllowGroups ansible`
  erfüllt das bereits, die `ansible_managed`-Zeile selbst wird also nicht geprüft.
- `LogLevel INFO` besteht ebenfalls, und das ist auf allen acht Hosts der Standard.
- `AllowGroups` muss nur nicht leer sein; jede Gruppe besteht.
- Algorithmen werden gegen eine Liste schwacher Muster geprüft. Gemessen auf allen acht Hosts:
  Die Standard-`Ciphers` und -`KexAlgorithms` bestehen schon, die Standard-`MACs` nicht (sie
  enthalten `hmac-sha1`).
- Modus und Eigentümer des Drop-ins, `validate`, der Handler und der Task mit dem vollen
  `sshd -t` werden nicht geprüft. Im `--check`-Lauf wird dieser Task übersprungen (`Command would
  have run if not in check mode`).

### So funktioniert es

#### Variablen, Template, `join`
Jeder Wert ist eine Variable, Listen werden im Template verbunden: `,` für `Ciphers`, `MACs` und
`KexAlgorithms`, ein Leerzeichen für `AllowGroups` - die Trennzeichen, die `sshd_config`
erwartet. `{{ ansible_managed | comment }}` ergibt drei Zeilen (`#`, `# Ansible managed`, `#`).
Die Ausgabe ist deterministisch: Die Musterlösung meldet im ersten Lauf `changed=2` pro Host
(Template + Handler) und im zweiten `changed=0`.

#### Der erste Wert gewinnt, also jeden geprüften Schlüssel nennen
Das Lab setzt `Include /etc/ssh/sshd_config.d/*.conf` an den Anfang der Hauptdatei, und `sshd`
behält den ersten Wert, den es liest. Deine `00-`-Datei kommt zuerst. Ein Schlüssel, den sie
**nicht** setzt, kommt aus der nächsten Datei, die ihn setzt: `10-lab-legacy.conf` setzt
`PermitRootLogin yes`, `PermitEmptyPasswords yes`, `X11Forwarding yes` und `MaxAuthTries 10`,
auf den Red-Hat-Hosts setzt `50-redhat.conf` zusätzlich `X11Forwarding yes`. Gemessen mit einem
lokalen `sshd`: Ein Drop-in nur mit den Werten der README-Tabelle lässt `permitrootlogin yes` in
`sshd -T` stehen. Der Dateiname ist der aus 1.03, das Template ersetzt also diese Datei und muss
ihre zwei Zeilen mitbringen.

`DisableForwarding yes` sperrt zur Laufzeit jede Art von Forwarding, aber `sshd -T` zeigt die
einzelnen Schlüssel weiter so, wie sie irgendwo gesetzt sind: Nach der Lösung steht
`allowtcpforwarding` auf sieben Hosts auf `yes` und auf alpine auf `no` (Standard von Alpine).
Deshalb prüft der Check `X11Forwarding no` eigens.

#### Zwei Prüfebenen
`validate: /usr/sbin/sshd -t -f %s` prüft das gerenderte Fragment **allein**, bevor es die Datei
ersetzt. Es findet einen Tippfehler (`Bad configuration option: MaxAuthTry`, rc 255) oder einen
Algorithmus, den das lokale OpenSSH nicht kennt; die alte Datei bleibt dann stehen. Die anderen
Dateien sieht es nicht. Gemessen mit OpenSSH 9.6: Das Fragment besteht, der volle Test scheitert,
wenn

- es `AuthenticationMethods publickey,password` setzt und eine andere Datei
  `PasswordAuthentication no` (`AuthenticationMethods cannot be satisfied by enabled
  authentication methods`), oder
- ein anderes Drop-in eine ungültige Zeile enthält.

Daher die zweite Ebene, `sshd -t` ohne `-f`, nach dem Template-Task. Handler laufen am Ende des
Plays: Scheitert der volle Test, hört der Host vor dem Reload auf, und der laufende Daemon behält
seine alte Konfiguration. Die neue Datei liegt aber **schon auf der Platte**: Ein Neustart oder
Reboot vor deiner Korrektur startet keinen `sshd`. Sofort korrigieren und neu laufen lassen, oder
eine Kopie behalten (`backup: true`) und sie in einem `rescue`-Block zurückspielen (Lektion L02).

#### Algorithmen und OpenSSH-Versionen
`mlkem768x25519-sha256` gibt es seit OpenSSH 9.9; 9.6 lehnt das Fragment mit `Unsupported KEX
algorithm` ab. Der älteste sshd im Lab ist 9.9 (rocky, alma), die Liste funktioniert also auf
allen acht Hosts.

#### crypto-policies (Bonus 3)
Auf rocky, alma und fedora kommt die systemweite Crypto-Policy über das Drop-in
`40-redhat-crypto-policies.conf` zu `sshd` (vor der Übung weichen ihre Listen von denen der
anderen Hosts ab, z. B. kein `aes192-ctr`). Deine `00-`-Datei wird davor gelesen, deine Listen
gewinnen also: Nach der Lösung zeigen die drei Hosts genau die Listen des Templates.
`50-redhat.conf` enthält andere Standardwerte, keine Algorithmen. rocky und alma melden die
Policy `DEFAULT`; das fedora-Image des Labs hat kein `update-crypto-policies`. Ein eigenes
Policy-Modul (im Lab nicht getestet) setzt Algorithmen systemweit.

#### Aussperr-Analyse (Bonus 1)
- `AllowGroups ansible`: Die einzige Gruppe des Lab-Kontos ist seine primäre Gruppe `ansible`
  (gemessen auf allen acht Hosts), und `AllowGroups` zählt die primäre Gruppe mit. In Produktion
  muss die Liste deine Admin-Gruppe *und* die Gruppe des Automatisierungskontos enthalten.
- `PermitRootLogin no`: Ansible meldet sich als `ansible` an und nutzt sudo.
- `ClientAliveInterval 15`, `ClientAliveCountMax 3`: Ein Client, der nicht mehr antwortet, fliegt
  nach etwa 45 Sekunden raus; ein untätiger Client, der antwortet, bleibt. Die dauerhaften
  Verbindungen von Ansible antworten.
- Ein Reload behält offene Sitzungen (gemessen in 1.03), ein Fehler fällt also erst beim nächsten
  Login auf.

### Hinweise je Familie
| os_family | OpenSSH | Unit | Drop-ins außer `10-lab-legacy.conf` |
|---|---|---|---|
| Debian | debian 10.0p2, ubuntu 10.2p1 | `ssh` | keine |
| RedHat | rocky und alma 9.9p1, fedora 10.2p1 | `sshd` | `40-redhat-crypto-policies.conf`, `50-redhat.conf`; alma zusätzlich `25-permitrootlogin.conf` |
| Suse | 10.0p2 | `sshd` | keine |
| Alpine | 10.3p1 | `sshd` (OpenRC) | keine |
| Archlinux | 10.6p1 | `sshd` | `20-systemd-userdb.conf`, `99-archlinux.conf` |

`/usr/sbin/sshd` ist auf arch und fedora ein Link auf `/usr/bin/sshd`, derselbe Pfad funktioniert
also auf allen acht Hosts. `sshd -T` auf Arch gibt die Schlüssel in gemischter Schreibweise aus
(`PermitRootLogin`); der Check wandelt sie in Kleinbuchstaben um.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Behebung |
|---|---|---|
| `sshd -T` zeigt nach deinem Lauf `permitrootlogin yes` | das Template setzt es nicht, die Legacy-Datei schon | jeden Schlüssel setzen, den der Check prüft |
| `x11forwarding yes` trotz `DisableForwarding yes` | `sshd -T` zeigt jeden Schlüssel einzeln | zusätzlich `X11Forwarding no` |
| `Bad configuration option: ...`, rc 255, in `validate` | Tippfehler im Template | korrigieren; die alte Datei bleibt |
| `Unsupported KEX algorithm` | OpenSSH älter als der Algorithmus | Liste je Host oder Algorithmus weglassen |
| Play stoppt beim vollen `sshd -t` | eine andere Datei oder eine Kombination von Dateien | jetzt korrigieren - die neue Datei liegt schon da |
| `Permission denied` für einen Admin nach dem Lauf | in keiner Gruppe von `AllowGroups` | Gruppe ergänzen; zweiten Login testen, bevor du den ersten schließt |

### Praxis-Hinweise
- Halte eine Sitzung offen und teste einen **neuen** Login, bevor du sie schließt.
- `sshd -T -C user=<name>,host=<host>,addr=<ip>` zeigt die Werte, die ein `Match`-Block dieser
  Verbindung geben würde.
- Ausnahmen gehören in Variablen auf einer engeren Ebene (`group_vars`, `host_vars`), nicht in eine
  Kopie des Templates (Lektion L04).

### Weiterführend
- Lektion [L02 - Sichere Änderungen](../../../docs/lessons/L02-safe-changes.de.md): `validate`, Handler, `backup` und `rescue`.
- Lektion [L03 - Basis-Härtung](../../../docs/lessons/L03-base-hardening.de.md): mehrere sshd-Dateien, ein wirksamer Wert.
- Lektion [L04 - Plattformunterschiede als Daten](../../../docs/lessons/L04-platform-differences-as-data.de.md): Templates, `join`, `ansible_managed`.
- Übung [1.03 - SSH: Root-Login und leere Passwörter verbieten](../../stage1-beginner/1.03-ssh-root-login/README.de.md)
- Übung [2.06 - Alle Login-Banner aus einem Template](../2.06-banners-template-loop/README.de.md)
- [`sshd_config(5)`](https://man.openbsd.org/sshd_config) - `Include`, `Match`, `DisableForwarding`, die Schlüsselwörter für Algorithmen

## Musterlösung

Anzeigen mit `lab solution 2.02`, anwenden mit `lab solve 2.02`.
