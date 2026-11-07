# 4.05 - Custom Facts: Hosts beschreiben ihre eigene Härtung: Erklärung

### Was der Check prüft
`lab check 4.05` führt `check.yml` aus und dann dein Playbook noch einmal mit `--check`; erwartet
wird `changed=0` (`meta.yml` sagt `idempotency: true`). `check.yml` hat zwei Plays:
- auf allen acht Targets, mit `become`: er sammelt `ansible_local` selbst und prüft
  `cis.baseline == 'lab-cis'`, dass `cis.version` und `cis.level` existieren,
  `cis_live.uid0_accounts` mindestens 1 und ein nicht leeres `cis_live.permit_root_login`;
  `cis.fact` muss `0644` sein, `cis_live.fact` `0755` und root gehören;
- auf `localhost`: `inventory.md` im Arbeitsverzeichnis (`$LAB_WORK_DIR/4.05`) enthält den Namen
  jedes Targets.

Nicht geprüft wird: die Werte von `version`, `level` und `managed_by`, die Gruppe der Dateien,
dass dein Play nach dem Ausrollen neu sammelt (der Check sammelt selbst), Spalten und Werte des
Berichts (jede Datei, die die acht Hosts nennt, besteht), und ob `permit_root_login` echt ist -
der Rückfallwert `unknown` besteht. Einen Zeitstempel in `cis.fact` fängt erst der zweite Lauf.

### So funktioniert es

#### Statische und ausführbare Facts
| | statische `.fact` | ausführbare `.fact` |
|---|---|---|
| Inhalt | JSON oder INI, von Ansible geschrieben | die Ausgabe des Skripts |
| beantwortet | "was haben wir angewendet?" | "was gilt gerade jetzt?" |
| Kosten | keine | läuft bei *jedem* Sammeln der Facts |

Gemessen für Lektion L10: JSON behält Typen und Groß-/Kleinschreibung der Schlüssel (`level`
bleibt die Zahl 1); INI liefert Strings und schreibt die Optionsnamen klein. Eine Datei mit dem
Ausführungsbit des Eigentümers wird immer ausgeführt, nie gelesen (Quelltext von ansible-core).

#### Wann Facts gelesen werden
Facts werden zu Beginn eines Plays gesammelt - bevor deine Dateien existieren. Direkt nach den
`copy`-Tasks hat `ansible_local` noch den alten Wert (beim ersten Lauf leer), bis ein
`ansible.builtin.setup` mit `filter: ansible_local` neu sammelt. Das zweite Play liest die
frischen Werte über `hostvars[h].ansible_local`; ohne das erneute Sammeln hat sein erster Bericht
in jeder Zelle ein `-`. Unter `--check` wird nichts geschrieben, ausführbare Facts, die schon auf
der Platte liegen, laufen trotzdem.

#### Facts laufen mit den Rechten des Plays
Gemessen für Lektion L10: das Fact-Skript lief ohne `become` als Benutzer `ansible` und mit
`become` als root. Das zählt hier: `sshd -T` braucht die Host-Schlüssel und gibt als normaler
Benutzer nur `sshd: no hostkeys available -- exiting.` aus (gemessen), also meldet das Skript
`unknown` - und der Check akzeptiert das. Deshalb `become: true` am Play. Die Kehrseite: ein
`facts.d`, in das jemand anders schreiben kann, ist Codeausführung als root beim nächsten
Ansible-Lauf. Halte es bei `0755 root:root`.

#### Was ein langsamer Fact kostet
Jedes Sammeln führt jeden ausführbaren Fact aus, für jedes Play, das sammelt. `gather_timeout`
schützt dich nicht: mit `gather_timeout: 2` und einem Skript, das 8 Sekunden schläft, wartete der
`setup`-Task 9 Sekunden (gemessen; der Sammler für lokale Facts ruft das Skript ohne Zeitlimit
auf). Bonus 2, beantwortet: halte das Skript billig, stell im Skript ein `timeout` vor den
langsamen Befehl, oder lass einen geplanten Job die Messung als *statischen* Fact schreiben.
Plays, die keine lokalen Facts brauchen, überspringen sie mit einem `gather_subset` wie
`['!all', '!min']` (L10).

#### Kaputte Facts halten das Play nicht an
Eine statische Datei, die kein gültiges JSON oder INI ist, oder ein Skript mit Exit-Code ungleich
0 hinterlässt einen String in `ansible_local.<name>` (`error loading facts as JSON or ini - please
check content: <path>`, `Failure executing fact script (<path>), rc: 3, err: `), und das Play läuft
weiter (L10). Der Check scheitert dann an den fehlenden Schlüsseln - lies den Wert, den er
ausgibt.

#### Keine Zeitstempel
`"last_run": "{{ now() }}"` ändert die Datei bei jedem Lauf - nie `changed=0`, und deine
Drift-Berichte werden zu Rauschen. Brauchst du eine Lauf-Historie, schick sie in ein Log oder in
den Bericht auf dem Control-Node, nicht in verwalteten Zustand.

#### Nutzung in AWX/AAP
Mit aktiviertem Fact-Caching am Job-Template speichert AWX/AAP die gesammelten Facts je Host und
zeigt sie in den Host-Details; Smart-Inventories können Hosts nach diesen Facts filtern. Das wurde
im Lab nicht getestet - prüf die Filtersyntax in der Dokumentation deiner Version.

### Hinweise je Familie
| `os_family` | Hosts | `/bin/sh` (führt das Skript aus) |
|---|---|---|
| Debian | debian, ubuntu | dash |
| RedHat | rocky, alma, fedora | bash |
| Suse | opensuse | bash |
| Archlinux | arch | bash |
| Alpine | alpine | BusyBox |

`/etc/ansible/facts.d` existiert zu Beginn auf keinem der acht Targets. Schreib das Skript für die
kleinste Shell (POSIX-`sh`, BusyBox-`awk`), dann läuft es überall.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| Der erste Bericht zeigt für jeden Host `-` | die Facts wurden gesammelt, bevor die Dateien existierten | `setup` mit `filter: ansible_local` nach dem Ausrollen |
| `permit_root_login` ist `unknown` | das Skript lief ohne root, `sshd -T` fand keine Host-Schlüssel | `become: true` am Play |
| `ansible_local.cis_live` ist ein String mit `error loading facts` | das Skript gab kein gültiges JSON aus, oder der Datei fehlt das Ausführungsbit | das Skript von Hand testen, Modus `0755` |
| `changed=1` bei jedem Lauf | ein Zeitstempel oder ein anderer wandernder Wert in `cis.fact` | nur stabile Werte in verwalteten Dateien |
| Jedes Play auf einem Host ist langsam geworden | ein teurer ausführbarer Fact | `timeout` im Skript, oder ein statischer Fact, den ein Job schreibt |

### Praxis-Hinweise
- Versioniere die Baseline im Fact (`version`) und erhöhe sie mit der Rolle: "welche Hosts laufen
  noch mit 1.0.0?" wird zur Abfrage statt zum Audit.
- Halte ausführbare Facts lesend und schnell; sie laufen bei jedem Play, auch bei solchen, die mit
  Härtung nichts zu tun haben.

### Weiterführend
- Lektion [L10 - Compliance-Berichte: Audit-Modus, Enforce-Modus und Custom Facts](../../../docs/lessons/L10-compliance-reporting.de.md): `facts.d`, das erneute Sammeln, Check-Modus und Berichte - die Konzepte vor dieser Übung.
- Übung [4.01 - Reiner Audit-Lauf mit Compliance-Bericht](../4.01-audit-only-report/README.de.md): die Berichtsseite, ohne die Hosts zu ändern.
- Übung [5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus](../../stage5-capstone/5.01-capstone-cis-role/README.de.md): wo Facts und Berichte zusammenkommen.

## Musterlösung

Anzeigen mit `lab solution 4.05`, anwenden mit `lab solve 4.05`.
