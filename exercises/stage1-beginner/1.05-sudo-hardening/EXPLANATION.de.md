# 1.05 - sudo: PTY erzwingen und in Datei protokollieren: Erklärung

### Was der Check prüft
`lab check 1.05` führt `check.yml` auf `targets` aus: `/etc/sudoers.d/50-cis` muss existieren,
Modus `0440` haben und `root` gehören, und der Inhalt muss die Zeilen `Defaults use_pty` und
`Defaults logfile="/var/log/sudo.log"` enthalten (Anführungszeichen optional). `visudo -c` muss
erfolgreich sein. Auf openSUSE toleriert der Check genau eine Meldung,
`/usr/etc/sudoers: bad permissions`, weil diese Vendor-Datei nicht dir gehört (siehe unten).
Danach läuft dein Playbook noch einmal mit `--check` und muss `changed=0` melden.

Nicht geprüft werden:

- `validate`: Eine Lösung ohne besteht.
- Die Gruppe der Datei sowie jeder Modus, der strenger oder lockerer als genau `0440` ist.
- Ob sudo wirklich ein PTY nutzt oder das Log schreibt; der Check liest die Datei.

### So funktioniert es

#### Warum Drop-in-Dateien
`/etc/sudoers` gehört dem Distributionspaket. `/etc/sudoers.d/` wird über `@includedir` gelesen,
deine Datei lässt sich also sauber hinzufügen und entfernen. Gemessen: Eine Datei mit einem
Punkt im Namen (`99-dot.conf`) wird **ignoriert**. `visudo -c` listet sie nicht auf, und ein darin
gesetztes `logfile` hat auf allen getesteten Hosts keine Wirkung. `50-cis.conf` würde still nichts
tun.

#### `validate` rettet dich
Ohne Validierung deaktiviert ein Tippfehler sudo, und Ansible braucht sudo, um root zu werden.
Gemessen mit einem Tippfehler im Inhalt: Der `copy`-Task scheitert mit `failed to validate` auf
allen sieben Hosts, die ihn ausgeführt haben (alpine scheiterte in einem separaten Lauf genauso),
und alle sieben Hosts waren weiter mit `become` erreichbar. Ohne Validierung bräuchte die
Wiederherstellung Konsolenzugriff, hier `./lab.sh reset <host>`.

#### Der Dateimodus zählt
Gemessen: Mit Modus `0644` beendet sich `visudo -c` mit 1 und meldet
`/etc/sudoers.d/50-cis: bad permissions, should be mode 0440`. `sudo -n true` funktionierte in
diesem Zustand weiter (rc=0). Deshalb liest der Check Modus und `visudo -c`. Nach der
Wiederherstellung auf `0440` war die Datei wieder in Ordnung.

#### Kein Handler
sudo liest seine Konfiguration bei jedem Aufruf, ein Handler ist nicht nötig.

### Hinweise je Familie
- sudo-Versionen: 1.9.16p2 auf debian, 1.9.17p1 auf opensuse, 1.9.17p2 auf den übrigen.
- Ubuntu 26.04 bietet eine Rust-Neuimplementierung (sudo-rs). Im Lab-Image ist `sudo` das
  Original: `/usr/bin/sudo` ist ein Alternatives-Link auf `/usr/bin/sudo.ws`, `visudo` ist
  `/usr/sbin/visudo.ws`, Version 1.9.17p2.
- openSUSE Leap 16 verlagert Vendor-Voreinstellungen nach `/usr/etc` (`/usr/etc/sudoers`,
  `/usr/etc/login.defs`); Dateien in `/etc` überschreiben sie. Das Paket liefert
  `/usr/etc/sudoers` mit Modus 0444, daher scheitert `visudo -c` auf einem unberührten Host
  (Exit-Code 1). Diese Datei gehört nicht dir.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Behebung |
|---|---|---|
| `failed to validate` | Tippfehler im Inhalt | Inhalt korrigieren und erneut ausführen |
| Einstellung wirkt nicht | Dateiname enthält `.` oder endet auf `~` | `50-cis`, ohne Endung |
| `visudo -c`: `bad permissions` | Modus `0644` | `0440` |
| Log zeigt Ansibles eigene Befehle | Ansible führt seine Module über sudo aus | erwartet; z. B. `COMMAND=/usr/bin/true` |

### Praxis-Hinweise
- `logfile` gilt zusätzlich zu syslog/Journal, nicht stattdessen.
- `use_pty` ist seit sudo 1.9.14 Standard (aus den sudo-Release-Notes, hier nicht gemessen); die
  ausdrückliche Angabe dokumentiert die Absicht und deckt ältere Versionen ab.
- Das Log enthält Zeilen wie `ansible : PWD=/home/ansible ; USER=root ; COMMAND=/bin/sh`; lange
  Einträge werden bei 80 Zeichen umgebrochen, ein Befehl kann also in der nächsten Zeile
  weitergehen.

### Weiterführend
- Lektion [L02 - Sichere Änderungen](../../../docs/lessons/L02-safe-changes.de.md): `validate` und `--check --diff`.
- Lektion [L03 - Basis-Härtung](../../../docs/lessons/L03-base-hardening.de.md): Pakete, Dienste, Dateien, SSH und sudo an einem Ort.
- Übung [1.03 - SSH: Root-Login und leere Passwörter verbieten](../1.03-ssh-root-login/README.de.md): dasselbe Muster aus `copy` + `validate`.

## Musterlösung

Anzeigen mit `lab solution 1.05`, anwenden mit `lab solve 1.05`.
