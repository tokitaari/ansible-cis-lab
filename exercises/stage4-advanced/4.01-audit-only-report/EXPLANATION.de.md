# 4.01 - Reiner Audit-Lauf mit Compliance-Bericht: Erklärung

### Was der Check prüft
`lab check 4.01` führt `check.yml` auf `localhost` aus. Es liest die Dateien in `/lab/work/4.01`:

- `report.json` und `report.md` existieren;
- die JSON-Schlüssel sind genau die Hosts von `targets`, alle acht Werte haben einen numerischen
  `score`, jeder hat mindestens zehn `results`, jedes Ergebnis hat eine `id`, und es kommt kein
  anderer Status als `pass`, `fail` und `n/a` vor.

Danach läuft dein Playbook noch einmal mit `--check` und muss auf jedem Target `changed=0` melden;
die Recap-Zeile von `localhost` wird nicht angesehen.

Nicht geprüft: der Inhalt von `report.md` (eine leere Datei besteht), die Scores, welche
Kontrollen du auswertest, `ignore_errors` und `changed=0` im normalen Lauf. Ein von Hand
geschriebenes `report.json` mit `score: 123` und zehn Kopien von `{"id": "x", "status": "pass"}`
hat in unserem Test bestanden, ebenso ein Bericht, der von einem früheren Lauf übrig ist. Vergleiche
den Bericht selbst mit den Hosts (Werte unten).

### So funktioniert es

#### Sammeln mit lesenden Modulen
`package_facts`, `service_facts`, `stat` und `slurp` unterstützen den Check-Modus und laufen unter
`--check` einfach mit. Ein `command`-Task nicht: Im Check-Modus wird er mit der Meldung "Command
would have run if not in check mode" übersprungen, `sshd -T` und `sysctl -n` liefern dann nichts,
und die Auswertung scheitert (gemessen). `check_mode: false` lässt diese Leser trotzdem laufen,
`changed_when: false` hält das Recap sauber. `sshd -T` braucht root (sonst "no hostkeys
available", siehe 4.05), daher `become: true`. Gemessen: Lauf 1, Lauf 2 und `--check` melden auf
allen Targets `changed=0`.

#### Auswerten in einem `set_fact`
Jeder Status ist ein Jinja-Ausdruck, eine nicht erfüllte Kontrolle kann den Host also nicht
stoppen: Jeder Host bekommt alle zehn Ergebnisse. Die Hilfswerte stehen in Task-`vars:`, die beim
Lauf des Tasks pro Host ausgewertet werden:

- `sshd` macht aus den Zeilen von `sshd -T` ein Dict. Die Schlüsselwörter müssen kleingeschrieben
  werden: Sieben Hosts geben `permitrootlogin` aus, arch (OpenSSH 10.6p1) `PermitRootLogin` und
  `MaxAuthTries`.
- `slurp` der fehlenden `/etc/sudoers.d/50-cis` scheitert; `failed_when: false` hält den Host am
  Leben, das Ergebnis hat kein `content`, und `default('')` macht daraus einen leeren String.
- `uid0` zerlegt `/etc/passwd` in Felder; `selectattr('2', 'equalto', '0')` funktioniert, weil
  Jinja das Attribut `'2'` in den Listenindex 2 umwandelt.
- `vsftpd` heißt in `service_facts` auf systemd-Hosts `vsftpd.service`, auf Alpines OpenRC
  `vsftpd` (mit `runlevels`); der Ausdruck liest beides.

`assert` würde den Host bei der ersten nicht erfüllten Kontrolle stoppen; Ausdrücke liefern Daten.

#### Zusammenführen auf `localhost`
Das zweite Play läuft über `groups['targets']` und liest `hostvars[h].cis_results`. Zwei
Fehlerfälle, gemessen: Ein Host, der vor dem `set_fact` scheitert, fehlt still im Bericht (der
Filter `if ... is defined`), `ansible-playbook` endet mit rc 2, und der Check scheitert an der
Struktur. Scheitern *alle* Targets, startet das `localhost`-Play gar nicht, und das alte
`report.json` bleibt unverändert - ein veralteter Bericht sieht aus wie ein frischer.

#### n/a und der Score
`n/a` zählt weder als pass noch als fail: Als pass bläht es den Score auf, als fail bestraft es
eine Plattform. BusyBox-`crond` auf Alpine liest `cron.allow` nicht (siehe 2.05), daher ist 2.4 dort
`n/a`, und Alpines Score ist 2 von 9 = 22.2. `[p + f, 1] | max` schützt die Division für einen
Host, dessen Ergebnisse alle `n/a` sind.

#### Was eine Kontrolle wirklich misst
- **2.2** prüft nur den Paketnamen. Nach 1.01 ist das Debian/Ubuntu-Dummy-Paket `telnet` weg, und
  der Bericht sagt `pass`, während `/usr/bin/telnet` aus `inetutils-telnet` weiter funktioniert
  (siehe die Erklärung zu 1.01). Arch und Alpine haben gar kein Paket `telnet` und bestehen von
  Anfang an.
- **5.2** liest nur das Drop-in des Labs, `/etc/sudoers.d/50-cis` (1.05). Zu Beginn ist `use_pty`
  auf allen acht Hosts (sudo 1.9.16p2-1.9.17p2) schon wirksam - `sudo -V` als root listet "Always
  run commands in a pseudo-tty", debian und ubuntu setzen es zusätzlich in `/etc/sudoers` -, und
  die Referenz meldet trotzdem `fail`. `sudo -V` zeigt den wirksamen Wert (die Zeile verschwindet
  mit `Defaults !use_pty`); `sudo -l` listet nur ausdrückliche `Defaults`.
- **5.1** und **3.3** lesen wirksame Werte (`sshd -T`, den laufenden sysctl), keine Dateien.

### Hinweise je Familie
Gemessen auf frisch zurückgesetzten Hosts (nach 0.02):

| Host | Score zu Beginn | Erfüllt zu Beginn | Schlüsselwörter von `sshd -T` |
|---|---|---|---|
| debian | 0.0 | keine | klein (OpenSSH 10.0p2) |
| ubuntu | 10.0 | 5.4.2 | klein (10.2p1) |
| rocky | 0.0 | keine | klein (9.9p1) |
| alma | 10.0 | 5.4.2 | klein (9.9p1) |
| fedora | 10.0 | 5.4.2 | klein (10.2p1) |
| opensuse | 10.0 | 5.4.2 | klein (10.0p2) |
| arch | 20.0 | 2.2, 5.4.2 | `PermitRootLogin`, `MaxAuthTries` (10.6p1) |
| alpine | 22.2 | 2.2, 5.4.2 (2.4 `n/a`) | klein (10.3p1) |

Alle acht starten mit `permitrootlogin yes`, `maxauthtries 10` und `ip_forward=1`; debian und rocky
haben das zusätzliche UID-0-Konto `toor` (3.05). Nach 5.01 (enforce, Level 1) hat jeder Host 100.0.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| Nur arch: "`dict` has no attribute `permitrootlogin`" | OpenSSH auf arch gibt die Schlüsselwörter wie geschrieben aus | Schlüssel kleinschreiben |
| Derselbe Fehler auf allen Hosts, nur unter `--check` | `command` wird übersprungen, `sshd -T` liefert nichts | `check_mode: false` an Lesern |
| `sshd -T`: "no hostkeys available" | Play läuft ohne `become` | `become: true` |
| 5.2 `fail`, obwohl `use_pty` wirkt | Nur das Drop-in wird gelesen | `sudo -V` als root lesen oder sagen, was du misst |
| Ein Host fehlt im Bericht, rc 2 | Der Host ist vor dem `set_fact` gescheitert | Recap lesen; Host reparieren |
| `report.json` nach einem Lauf unverändert | Alle Targets gescheitert, das `localhost`-Play lief nie | Alten Bericht vorher entfernen oder Zeitstempel prüfen |

### Praxis-Hinweise
Lies wirksame Werte, wo das System sie anbietet (`sshd -T`, `sysctl -n`, `sudo -V`), und schreib
auf, welche Quelle eine Kontrolle nutzt - 5.2 zeigt, wie Datei und wirksamer Wert auseinanderliegen.
Bewahre Exit-Code und Recap des Playbooks neben dem Bericht auf, damit eine veraltete Datei nicht
als frisch durchgeht.

**Bonus - der Zeitstempel:** gemessen mit einem Feld `generated` in `report.json`: `localhost` meldet
dann bei jedem Lauf `changed=1`, auch unter `--check`; die Targets bleiben bei `changed=0`, und
`lab check` ignoriert `localhost`, aber ein Schlüssel auf oberster Ebene neben den Hostnamen bricht
`keys == targets`. Der Preis liegt auf dem Control Node: Jeder Bericht ist anders, ein Diff zeigt
keine echte Drift mehr. L10 legt die Zeit in den Dateinamen oder in ein Log.

**Bonus - Kontrollen als Daten:** Eine Liste in Play-`vars` mit `ok: "{{ ... }}"` je Eintrag
funktioniert: Play-Variablen werden verzögert pro Host ausgewertet und lieferten in unserem Test
echte Booleans. Strings, die per `from_json` aus einer Datei kamen, blieben wörtlicher Text
(ansible-core 2.21.6): Daten werden kein zweites Mal als Template ausgewertet. Die Registry von
5.01 ist die größere Fassung dieser Idee, mit einer Task-Datei je Kontrolle.

### Weiterführend
- Lektion [L10 - Compliance-Berichte: Audit-Modus, Enforce-Modus und Custom Facts](../../../docs/lessons/L10-compliance-reporting.de.md): Check-Modus, Ergebnisse festhalten, Berichtsformate.
- Übung [1.01 - Unsichere Client-Pakete entfernen](../../stage1-beginner/1.01-remove-telnet/README.de.md)
- Übung [1.05 - sudo: PTY erzwingen und in Datei protokollieren](../../stage1-beginner/1.05-sudo-hardening/README.de.md)
- Übung [2.05 - Job-Scheduler: cron-Rechte und Zugriff](../../stage2-building-blocks/2.05-cron-hardening/README.de.md)
- Übung [5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus](../../stage5-capstone/5.01-capstone-cis-role/README.de.md)

## Musterlösung

Anzeigen mit `lab solution 4.01`, anwenden mit `lab solve 4.01`.
