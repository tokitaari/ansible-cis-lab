# 2.01 - /etc/shadow: richtige Rechte je OS-Familie: Erklärung

### Was der Check prüft
`lab check 2.01` führt `check.yml` auf `targets` aus: `stat` auf `/etc/shadow` und
`/etc/gshadow`, dann wird für jede vorhandene Datei geprüft: Eigentümer `root`, Gruppe `root`
oder `shadow`, für niemanden ein Ausführungsbit, kein Schreibrecht der Gruppe und keinerlei
Zugriff für andere. Danach läuft dein Playbook noch einmal mit `--check` und muss `changed=0`
melden.

- Er prüft eine **Schranke**, nicht die Konvention der Familie: `root:root 0600` oder `0000` auf
  jedem Host besteht, auch dort, wo ein Helfer die Gruppe `shadow` braucht (siehe *Wer die
  Gruppe braucht*).
- Die Sicherungen `/etc/shadow-` und `/etc/gshadow-` prüft er nicht. Auf vier Hosts sind sie zu
  Beginn für alle lesbar (Tabelle unten), ein bestandener Check kann also lesbare Hash-Kopien
  zurücklassen.
- Fehlende Dateien werden übersprungen, setuid-, setgid- und Sticky-Bit werden nicht geprüft.
- Wie du zum Ergebnis kommst (Dictionary, `stat`, Schleife), prüft er nicht, nur den Zustand.

### So funktioniert es

#### Daten statt Bedingungen
Fünf Tasks mit `when: ansible_facts.os_family == '...'` würden funktionieren, aber jede neue
Distribution berührt jeden Task. Ein Dictionary mit dem Fact als Schlüssel trennt *was sich
unterscheidet* (Gruppe, Modus) von *was zu tun ist* (ein `file`-Task):
`shadow_perms[ansible_facts.os_family].mode`. Die Schlüssel müssen die Fact-Werte `Debian`,
`RedHat`, `Suse`, `Alpine` und `Archlinux` sein. Ein fehlender Schlüssel beendet den Task mit
`object of type 'dict' has no attribute 'RedHat'` (gemessen). Für einen Sicherheitswert ist das
die richtige Reaktion: Eine neue Familie fällt auf, statt einen geratenen Wert zu bekommen.
`| default({...})` würde die Lücke verdecken; Lektion L04 erklärt, warum das hier falsch ist.

#### Was ein `register` mit Schleife enthält
Ein `stat`-Task mit `loop` legt pro Element einen Eintrag in `shadow_files.results` ab. Jeder
Eintrag hat die Eingabe unter `item` und das Modulergebnis unter `stat`; die zweite Schleife
nimmt also `item.item` für den Pfad und `item.stat.exists` für die Entscheidung.
`when: item.stat.exists` listet fehlende Dateien als `skipping`;
`shadow_files.results | selectattr('stat.exists') | list` nimmt sie ganz aus der Schleife. Ohne
`loop_control.label` gibt Ansible das ganze Element aus - bei einem registrierten Ergebnis alles,
was `stat` geliefert hat, auch die SHA1-Prüfsumme der Datei (gemessen). `get_checksum: false` am
`stat`-Task spart den Hash und hält ihn aus Logs heraus.

#### Warum `0000` funktioniert
Root umgeht die Lese- und Schreibbits einer normalen Datei (`CAP_DAC_OVERRIDE`), `0000` kostet
root also nichts und sperrt alle anderen aus. Eigentümer bleibt `root`, damit nur root den Modus
ändern kann.

#### Wer die Gruppe braucht
Programme, die ein Passwort prüfen, ohne als root zu laufen (zum Beispiel eine Bildschirmsperre in
deiner Sitzung), rufen den PAM-Helfer `unix_chkpwd` auf. Ob dieser Helfer die Datei über die Gruppe
liest, hängt davon ab, wie die Distribution ihn installiert (gemessen):

- Debian, Ubuntu, Alpine: setgid `shadow` (`rwxr-sr-x root:shadow`). Er braucht das Leserecht der
  Gruppe, `root:root` macht dort diese Passwortprüfungen kaputt, obwohl der Lab-Check besteht.
- openSUSE: setuid root, Gruppe `shadow` (`rwsr-xr-x`). Die Gruppe ist Konvention, keine
  Voraussetzung.
- Rocky, Alma, Fedora, Arch: setuid root, und eine Gruppe `shadow` gibt es nicht. `group: shadow`
  scheitert dort mit `chgrp failed: failed to look up group shadow`.

Auf den sechs Hosts mit `getcap` hat der Helfer keine File Capabilities.

### Hinweise je Familie
Gemessen auf frischen Targets: `/etc/shadow` ist zu Beginn überall `0644` (vom Lab gesetzt), mit
der Gruppe der Familie. Die Musterlösung meldet `changed=1` pro Host (ein Task mit Schleife) und
im zweiten Lauf `changed=0`.

| os_family | Gruppe `shadow` | `unix_chkpwd` | Sicherungen zu Beginn (`shadow-` / `gshadow-`) | Nach der Lösung |
|---|---|---|---|---|
| Debian | ja (gid 42) | setgid `shadow` | debian `644` / `640`, ubuntu `644` / `644` | alle vier `0640 root:shadow` |
| RedHat | nein | setuid root | rocky `644` / `0`, alma `0` / `0`, fedora `644` / `644` | alle vier `0000 root:root` |
| Suse | ja (gid 15) | setuid root, Gruppe `shadow` | `640` / keine gshadow-Dateien | `shadow`, `shadow-` `0640 root:shadow` |
| Alpine | ja (gid 42) | setgid `shadow` | `640` / keine gshadow-Dateien | `shadow`, `shadow-` `0640 root:shadow` |
| Archlinux | nein | setuid und setgid, `root:root` | `600` / `600` | alle vier `0600 root:root` |

Die für alle lesbaren Sicherungen liegen genau auf den vier Hosts, auf denen der Build des Labs
*nach* dem Setzen von `0644` ein Konto anlegt (debian und rocky: `toor`; ubuntu und fedora:
`guest`): Die Kontowerkzeuge kopieren die Datei samt Modus, bevor sie sie ändern. `/etc/gshadow`
gibt es auf opensuse und alpine nicht, deshalb braucht der Task zuerst `stat`: `file` auf einem
fehlenden Pfad scheitert mit `file (/etc/gshadow) is absent, cannot continue`.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Behebung |
|---|---|---|
| `object of type 'dict' has no attribute 'Arch'` | Schlüssel anders geschrieben als der Fact | Schlüssel `Debian`, `RedHat`, `Suse`, `Alpine`, `Archlinux` |
| `chgrp failed: failed to look up group shadow` | die Gruppe fehlt auf RedHat- und Arch-Hosts | Gruppe aus dem Dictionary nehmen |
| `file (/etc/gshadow) is absent, cannot continue` | `file` ohne `stat` auf opensuse oder alpine | über die `stat`-Ergebnisse laufen, nur bei `stat.exists` handeln |
| `has no attribute 'stat'` oder ein Pfad, der wie ein Dictionary aussieht | `item` ist in der zweiten Schleife ein Ergebnis, kein Pfad | Pfad `item.item`, Daten `item.stat` |
| `lab check` besteht, `shadow-` ist weiter `0644` | der Check ignoriert die Sicherungen | in die Liste aufnehmen (Bonus 1) |
| Die Ausgabe zeigt eine Prüfsumme von `/etc/shadow` | `stat` berechnet standardmäßig SHA1, kein Label | `get_checksum: false`, `loop_control.label` |

### Praxis-Hinweise
- CIS hat eigene Empfehlungen für `/etc/shadow-` und `/etc/gshadow-`. Korrigiere zuerst die
  Hauptdatei: Das nächste `useradd` oder `passwd` kopiert ihren Modus wieder in die Sicherung.
- Behalte die Konvention der Distribution bei. Ein einheitliches `0000` besteht die meisten
  Scanner und macht den setgid-Helfer der Debian- und Alpine-Familie kaputt.
- In einer Rolle wird das Dictionary zu einer Variablendatei je Familie (Übung 4.03, Lektion L11).

### Weiterführend
- Lektion [L03 - Basis-Härtung](../../../docs/lessons/L03-base-hardening.de.md): Modi als Schranke, warum root die Bits ignoriert.
- Lektion [L04 - Plattformunterschiede als Daten](../../../docs/lessons/L04-platform-differences-as-data.de.md): Dictionaries mit einem Fact als Schlüssel, registrierte Schleifenergebnisse.
- Übung [1.02 - Rechte auf /etc/passwd und /etc/group](../../stage1-beginner/1.02-passwd-group-permissions/README.de.md)
- Übung [4.03 - Datengetriebene Rolle für alle Plattformen (inkl. Alpine)](../../stage4-advanced/4.03-data-driven-multi-platform-role/README.de.md)

## Musterlösung

Anzeigen mit `lab solution 2.01`, anwenden mit `lab solve 2.01`.
