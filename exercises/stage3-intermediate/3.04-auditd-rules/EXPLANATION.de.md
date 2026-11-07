# 3.04 - auditd: Regeln und Log-Aufbewahrung (Level 2): Erklärung

### Was der Check prüft
`lab check 3.04` führt `check.yml` auf allen acht Hosts aus und dann dein Playbook noch einmal
mit `--check`; erwartet wird `changed=0` (`meta.yml` sagt `idempotency: true`). `check.yml` fügt
alle `50-cis-*.rules`-Dateien zusammen, liest `99-cis-finalize.rules` und `auditd.conf` und prüft:
- die Schlüssel `scope`, `user_emulation`, `sudo_log_file`, `time-change` und `logins` kommen in
  den Regeln vor, dazu der genaue Text `/etc/shadow -p wa -k identity`;
- die Finalize-Datei hat eine Zeile `-e 2`;
- `max_log_file_action = keep_logs`, `space_left_action = email` und `admin_space_left_action`
  `single` oder `halt`.

Der Rest der README wird nicht geprüft. Mutationen der Musterlösung, die der Check akzeptiert hat
(gemessen auf einem Host der Debian-Familie): alle Regeln in einer `50-cis-all.rules` statt einer
Datei je Thema, Mode `0644`, eine zweite Zeile neben `-e 2`, kein `action_mail_acct`, `halt` statt
`single`, eine Zeile `this is not an audit rule` in einer Regeldatei und der entfernte
Dienst-Schutz (der Check liest den Dienststatus nie). Auch ein Template, das ein buchstäbliches
`\n` schreibt, sodass alle Regeln eines Themas in einer Zeile stehen, besteht. An einer Stelle ist
der Check strenger als auditd: seine regulären Ausdrücke unterscheiden Groß- und Kleinschreibung,
`KEEP_LOGS` fällt durch, obwohl `auditd.conf(5)` sagt, Namen und Werte seien case-insensitiv. Und er
braucht den Dateinamen `99-cis-finalize.rules`: die Datei umzubenennen lässt den Check
fehlschlagen. Diese Teile des Vertrags musst du selbst richtig machen.

### So funktioniert es

#### Datengetriebene Regeldateien
Ein Dict, ein Template, eine Schleife. Ein Thema hinzufügen = einen Schlüssel hinzufügen. Der
Dateiname kommt vom Dict-Schlüssel (`time_change`), der `-k`-Schlüssel von der Regelzeile
(`time-change`) - beide müssen nicht übereinstimmen. Schreibe im Template jede Regel in eine eigene
Zeile: das Template-Modul entfernt Zeilen, die nur ein Block-Tag enthalten, aber ein buchstäbliches
`\n` ist kein Zeilenumbruch (gemessen: die Datei hatte gar keinen Zeilenumbruch, und `augenrules`
fügte alle Regeln des Themas zu einer ungültigen Zeile zusammen).

Ein Thema aus dem Dict zu entfernen entfernt seine Datei nicht (gemessen: der nächste Lauf meldet
`changed=0`, und `augenrules` mischt die alten Regeln weiter ein). Dafür braucht es einen
Aufräum-Task (`find` + `file: state=absent` für `50-cis-*.rules`, die nicht im Dict stehen) - eine
schöne Erweiterung.

#### Was die Regeln erfassen
| Schlüssel | Frage, die er im Vorfall beantwortet |
|---|---|
| `scope`, `sudo_log_file` | wer hat sudo-Rechte geändert / das sudo-Log manipuliert? |
| `user_emulation` | wer hat Befehle als *anderer* Benutzer ausgeführt? |
| `time-change` | hat jemand die Uhr verstellt, um Log-Korrelation zu verwirren? |
| `identity` | wer hat Konten, PAM oder Namensauflösung angelegt/geändert? |
| `logins` | wurden Login-Aufzeichnungen angefasst? |

`-k` setzt den Schlüssel, nach dem du später suchst: `ausearch -k identity`. Die Musterlösung
schreibt nur `arch=b64`-Regeln; ein Rechner, der 32-Bit-Programme ausführt, braucht ein `b32`-Pendant
(L09).

#### Der Merge und `-e 2`
`augenrules` fügt `rules.d/*.rules` in natürlicher Reihenfolge (`ls -v`) zu `/etc/audit/audit.rules`
zusammen, und `augenrules(8)` sagt, das letzte `-e` werde immer als letzte Zeile ausgegeben.
Gemessen mit audit 3.1.2: mit der Finalize-Datei als `05-cis-finalize.rules` war die erzeugte Datei
identisch, `-e 2` stand trotzdem zuletzt. Das Präfix `99-` ist also eine Konvention für den Leser,
keine Anforderung von auditd; nur der Check besteht auf dem Namen.

`-e 2` macht den Regelsatz bis zum Neustart unveränderlich - ein Angreifer mit root kann nicht
einfach `auditctl -D` ausführen. Gemessen auf einer VM mit audit 3.1.2, nachdem die Referenzregeln
(16 Regeln, vom Kernel alle akzeptiert) mit `-e 2` geladen waren: `auditctl -w ...` antwortete `The
audit system is in immutable mode, no rule changes allowed`, `auditctl -D` antwortete `Error
deleting rule (Operation not permitted)`. Teste die Regeln entsperrt und sperre nur den
endgültigen Satz.

`augenrules --check` vergleicht die zusammengefügten Dateien mit `/etc/audit/audit.rules`, nicht
mit den geladenen Regeln, gibt `No change` oder `Rules have changed and should be updated` aus und
endet in beiden Fällen mit 0 (audit 3.1.2). Nach dieser Übung meldet es im Lab eine Änderung, weil
dort nichts die Regeln erzeugt oder lädt.

#### Entscheidungen in auditd.conf
- `keep_logs` - rotieren ohne zu löschen (Plattenplanung wird deine Aufgabe!).
- `space_left_action = email` → Frühwarnung; `admin_space_left_action = single` → lieber das System
  anhalten als ohne Audit weiterlaufen. Das ist eine Geschäftsentscheidung; L2 heißt "du
  akzeptierst diesen Kompromiss". Diese drei Werte sind die, die der Abschnitt NOTES von
  `auditd.conf(5)` empfiehlt. `email` braucht `/usr/lib/sendmail` (Handbuch). Ausgeliefert sind auf
  allen acht Hosts `rotate`, `syslog` und `suspend`, alle drei Werte ändern sich also (L09).
- `action_mail_acct = root` ist auf Ubuntu 24.04 schon der ausgelieferte Wert: dieser Task meldet
  `ok`. Die Datei enthält dort alle vier Schlüssel, `lineinfile` ersetzt also die Zeile; Ubuntu
  schreibt die Werte in Großbuchstaben (`ROTATE`).
- Der Daemon liest `auditd.conf` beim Start; `SIGHUP` lässt ihn die Datei neu einlesen
  (`auditd(8)`). Die Musterlösung hat keinen Handler, weil das Lab den Daemon nie startet - auf einem
  echten Host brauchst du einen, und die Regeln zählen erst, wenn sie geladen sind (L09).

#### Die Container-Lektion
Kernel-Funktionen fallen in zwei Gruppen: namespaced (Netzwerk, Mounts, PIDs, manche sysctls) und
global (Audit, Module, die meisten `kernel.*`). Container isolieren nur die erste Gruppe.
Härtungscode braucht einen Schalter für Umgebungen, in denen er die zweite Gruppe nicht anfassen
darf - genau das bildet `lab_in_container` ab. In den Lab-Targets scheitert sogar `auditctl -s` auf
allen acht Hosts (L09).

### Hinweise je Familie
| `os_family` | Hosts | Paket (audit-Version) | Ausgeliefert in `rules.d` | Nach der Installation |
|---|---|---|---|---|
| Debian | debian, ubuntu | `auditd` (4.0.2, 4.1.2) | `-D`, `-b 8192`, `--backlog_wait_time 60000`, `-f 1` | `auditd.service` und `audit-rules.service` aktiviert |
| RedHat | rocky, alma, fedora | `audit` (4.0.3, 4.0.3, 4.2.1) | rocky, alma: wie Debian; fedora: `-D`, `-a task,never` | beide aktiviert; `auditd` auf rocky `activating`, auf alma und fedora `failed` |
| Suse | opensuse | `audit` (4.0) | `-D`, `-a task,never` | beide aktiviert, `auditd` inaktiv; er führt nach dem Start `augenrules --load` aus |
| Alpine | alpine | `audit` (4.1.2) | keine | OpenRC-Skript `/etc/init.d/auditd`, gestoppt |
| Archlinux | arch | `audit` (4.2.1) | keine | beide Units vorhanden, deaktiviert |

Alle Werte sind die Messungen der Lektion L09 auf den Targets des Labs (Debian-Familie mit
unterdrücktem Dienststart). `auditd.conf` hat auf allen acht Hosts dieselben Standardwerte.

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Lösung |
|---|---|---|
| `No package matching 'auditd' is available` auf Debian/Ubuntu | das Image liefert einen leeren Index, und `cache_valid_time` hält sein Verzeichnis für frisch | `update_cache: true` ohne `cache_valid_time`, oder wie die Lösung zuerst nach `*_Packages*` suchen |
| Alle Regeln eines Themas in einer Zeile, Check grün | buchstäbliches `\n` im Template | echte Zeilenumbrüche, eine Regel je Zeile |
| `The audit system is in immutable mode` | `-e 2` wurde geladen | Neustart; entsperrt testen |
| Der Check scheitert mit `KEEP_LOGS` | seine regulären Ausdrücke unterscheiden Groß-/Kleinschreibung | klein schreiben, wie in der README |
| Ein entferntes Thema wird weiter auditiert | seine Datei liegt noch in `rules.d` | Aufräum-Task |
| `augenrules --check` ist "erfolgreich" | sein Exit-Code ist in beiden Fällen 0 | seinen Text lesen |

### Praxis-Hinweise
- Rolle Regeln in zwei Schritten aus: erst die Dateien schreiben, dann laden (`augenrules --load`,
  in einem Handler oder durch Neustart des Dienstes). Nur der endgültige Satz trägt `-e 2`.
- Plane zuerst die Platte: `keep_logs` verliert für sich nichts und lässt die Platte daher volllaufen,
  und `single` hält dann die Maschine an. Viele Betreiber leiten das Log zusätzlich an einen zentralen
  Host weiter.

### Weiterführend
- Lektion [L09 - Auditing und Integrität](../../../docs/lessons/L09-auditing-and-integrity.de.md): das Audit-Subsystem, Regelarten, `rules.d` und `-e 2`, die Aktionen in `auditd.conf` - die Konzepte vor dieser Übung.
- Übung [4.08 - Dateiintegrität mit AIDE](../../stage4-advanced/4.08-aide-async/README.de.md): die zweite Hälfte der Lektion.

## Musterlösung

Anzeigen mit `lab solution 3.04`, anwenden mit `lab solve 3.04`.
