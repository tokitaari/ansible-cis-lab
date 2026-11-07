# 1.03 - SSH: Root-Login und leere Passwörter verbieten: Erklärung

### Was der Check prüft
`lab check 1.03` führt `check.yml` auf `targets` aus. Er liest die wirksame Konfiguration
(`sshd -T`, Schlüsselwörter in Kleinbuchstaben verglichen) und prüft `permitrootlogin == 'no'`
und `permitemptypasswords == 'no'`. Außerdem ruft er `stat` auf
`/etc/ssh/sshd_config.d/00-cis-hardening.conf` auf: Die Datei muss existieren, Modus `0600`
haben und `root` gehören. Danach läuft dein Playbook noch einmal mit `--check` und muss
`changed=0` melden.

Nicht geprüft werden:

- Die Gruppe der Datei (die Anforderung nennt `root:root`, der Check sieht nur den Eigentümer).
- `validate` und der Handler: Eine Lösung ohne beides besteht.
- Dass die Legacy-Datei unangetastet bleibt. Auch das Löschen von `10-lab-legacy.conf` bestünde.

### So funktioniert es

#### Der erste Treffer gewinnt
Bei den meisten Schlüsselwörtern nutzt sshd den **ersten** gelesenen Wert. `Include
/etc/ssh/sshd_config.d/*.conf` steht in Zeile 2 (arch) bis 24 (ubuntu) der Hauptdatei, und die
Dateien werden in lexikalischer Reihenfolge gelesen: `00-cis-hardening.conf` kommt vor
`10-lab-legacy.conf`. Gemessen vor der Lösung melden alle acht Hosts `permitrootlogin yes` und
`permitemptypasswords yes`, definiert in der Legacy-Datei (Zeilen 2 und 3). Auf alma liegt
dazwischen `25-permitrootlogin.conf` (`PermitRootLogin yes`); woher diese Datei kommt, wurde nicht
untersucht. Ein Name mit `99-` verliert gegen beide. Red-Hat-Hosts bringen außerdem
`40-redhat-crypto-policies.conf` und `50-redhat.conf` mit, arch `20-systemd-userdb.conf` und
`99-archlinux.conf`.

#### `validate`
Ansible schreibt den Inhalt in eine temporäre Datei, führt `sshd -t -f <tempfile>` aus und
verschiebt sie nur bei Exit-Code 0 an ihren Platz. Gemessen mit einem Tippfehler
(`PermitRootLogn`) auf debian und alpine: Der Task scheitert mit `failed to validate`, Exit-Status
255, stderr `Bad configuration option: PermitRootLogn`, und die bestehende Datei behält ihren
Inhalt. Das Fragment wird allein als Hauptkonfiguration geprüft, nicht zusammen mit den anderen
Drop-ins.

#### Handler
Handler laufen einmal am Ende des Plays und nur, wenn sie benachrichtigt wurden. Der erste Lauf
zeigt `changed` für die Kopie und für `Reload sshd`, der zweite keines von beiden.

#### `reloaded` oder `restarted`
Gemessen auf allen acht Hosts: Eine offene SSH-Sitzung überlebte sowohl Reload als auch Restart.
Auf den sieben systemd-Hosts hat die Unit `KillMode=process`, ein Restart beendet bestehende
Sitzungsprozesse also nicht (auf arch ist der Unit-Typ `notify-reload`, sonst `notify`). Auf
alpine (OpenRC) überlebte die Sitzung ebenfalls. Reload bleibt die schonendere Gewohnheit.

#### Warum nicht `lineinfile` auf `sshd_config`?
Es geht, aber Distributionen liefern unterschiedliche Hauptdateien, und Updates können sie
ersetzen. Ein Drop-in, das dir allein gehört, ist leichter zu durchschauen und zu entfernen.

#### `sshd -T` lesen
Schlüsselwörter sind nicht case-sensitiv, die Schreibweise unterscheidet sich: debian, ubuntu,
Red Hat, SUSE und alpine geben `permitrootlogin no` aus, arch (OpenSSH 10.6) `PermitRootLogin no`.
Vergleiche in Kleinbuchstaben.

### Hinweise je Familie
| Host | OpenSSH | Dienst | Weitere Drop-ins neben der Legacy-Datei |
|---|---|---|---|
| debian | 10.0p2 | `ssh` | keine |
| ubuntu | 10.2p1 | `ssh` | keine |
| rocky | 9.9p1 | `sshd` | `40-redhat-crypto-policies`, `50-redhat` |
| alma | 9.9p1 | `sshd` | `25-permitrootlogin`, `40-...`, `50-redhat` |
| fedora | 10.2p1 | `sshd` | `40-redhat-crypto-policies`, `50-redhat` |
| opensuse | 10.0p2 | `sshd` | keine; bindet zusätzlich `/usr/etc/ssh/sshd_config.d/*.conf` ein |
| arch | 10.6p1 | `sshd` | `20-systemd-userdb`, `99-archlinux` |
| alpine | 10.3p1 | `sshd` (OpenRC) | keine |

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Behebung |
|---|---|---|
| `sshd -T` sagt weiter `yes` | deine Datei sortiert nach der Legacy-Datei | niedriges Präfix wie `00-` |
| `failed to validate` | Tippfehler im Fragment | stderr lesen; die alte Datei bleibt unberührt |
| Handler läuft nicht | Name weicht von `notify` ab | der Name muss exakt übereinstimmen |
| Gäste mit leerem Passwort konnten sich anmelden | `PermitEmptyPasswords yes` | die Lösung schließt das: danach `Permission denied` auf ubuntu und fedora |

### Praxis-Hinweise
Bevor du in Produktion an sshd gehst: eine zweite Sitzung offen halten, `validate` nutzen und in
Chargen ausrollen (`serial`, Stufe 5).

### Weiterführend
- Lektion [L02 - Sichere Änderungen](../../../docs/lessons/L02-safe-changes.de.md): `validate`, Handler und `--check --diff`.
- Lektion [L03 - Basis-Härtung](../../../docs/lessons/L03-base-hardening.de.md): Pakete, Dienste, Dateien, SSH und sudo an einem Ort.
- Übung [2.02 - SSH-Server-Härtung mit Jinja2-Template](../../stage2-building-blocks/2.02-sshd-template/README.de.md)

## Musterlösung

Anzeigen mit `lab solution 1.03`, anwenden mit `lab solve 1.03`.
