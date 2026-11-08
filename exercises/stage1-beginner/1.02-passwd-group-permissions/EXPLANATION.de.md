# 1.02 - Rechte auf /etc/passwd und /etc/group: Erklärung

### Was der Check prüft
`lab check 1.02` führt `check.yml` auf `targets` aus: `stat` auf `/etc/passwd` und `/etc/group`,
dann wird für beide `mode == '0644'`, Eigentümer `root` und Gruppe `root` geprüft. Danach läuft
dein Playbook noch einmal mit `--check` und muss `changed=0` melden.

- Der Check verlangt **genau** `0644`. CIS erlaubt "0644 oder strenger", aber `0600` fällt hier durch.
- Die Sicherungsdateien `/etc/passwd-` und `/etc/group-` prüft er nicht (Bonus 1).
- Er prüft nicht, welches Modul du benutzt hast, nur den Ergebniszustand.

### So funktioniert es

#### `file` ändert Attribute
Ohne `state` nutzt `ansible.builtin.file` `state: file`: Der Pfad muss existieren, es werden nur
Eigentümer, Gruppe und Modus angepasst. Ein zweiter Lauf meldet `ok`. Gemessen mit der
Musterlösung: im ersten Lauf `changed=2` auf jedem Host, im zweiten `changed=0`; die
Sicherungsdateien bleiben unverändert (siehe Tabelle unten).

#### Der Modus ist ein String
Der Modus läuft zuerst durch YAML:

| Du schreibst | YAML sieht | Ergebnis |
|---|---|---|
| `mode: "0644"` | String | `rw-r--r--` ✔ |
| `mode: 0644` | Oktalzahl (YAML 1.1) | funktioniert; `ansible-lint` meldet `yaml[octal-values]` |
| `mode: 644` | Dezimalzahl 644 = oktal 1204 | `-w----r-T` ✘; `ansible-lint` meldet `risky-octal` |

Ein Ad-hoc-`-a mode=644` wird als String übergeben und zeigt das Problem nicht, erst ein
Playbook tut es. Ganz ohne `mode` meldet `ansible-lint` `risky-file-permissions`. Die Lab-Ausgabe
(`callback_result_format = yaml`) zeigt den Wert als `mode: '0644'`.

#### Symbolische Modi
`mode: "u=rw,go=r"` setzt dieselben Bits und dokumentiert die Absicht. `go-w` entfernt Bits,
ohne die übrigen anzufassen, passend für "höchstens 0644" - das Ergebnis hängt dann aber vom
Startzustand ab, und der Lab-Check verlangt weiterhin genau `0644`.

#### `state: touch` und `state: file`
`touch` setzt bei jedem Lauf die Zeitstempel, ist also immer `changed` und nie idempotent. Es
legt außerdem fehlende Dateien an. `state: file` schlägt bei einem nicht vorhandenen Pfad fehl,
das ist bei Dateien, die da sein müssen, das richtige Verhalten.

### Hinweise je Familie
Beim Start des Labs stehen die beiden Dateien auf allen acht Hosts auf `0664`. Die Sicherungen
unterscheiden sich:

| Host | `/etc/passwd-` | `/etc/group-` |
|---|---|---|
| debian | 664 | 644 |
| ubuntu | 664 | 664 |
| rocky | 664 | 644 |
| alma | 644 | 644 |
| fedora | 664 | 664 |
| opensuse | 644 | 644 |
| arch | 644 | 644 |
| alpine | 644 | 644 |

Die Musterlösung ändert die Sicherungen nicht.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Behebung |
|---|---|---|
| `-w----r-T` nach `mode: 644` | YAML liest 644 als Dezimalzahl | in Anführungszeichen: `"0644"` |
| `lab check` scheitert bei strengerem Modus | Check verlangt genau `0644` | `0644` setzen |
| Sicherungen weiter `0664` | Lösung fasst nur die zwei Hauptdateien an | Bonus 1: dazunehmen |
| `state: file` schlägt fehl | Pfad existiert nicht | auf Hosts ohne Sicherung vorher mit `stat` prüfen |

### Praxis-Hinweise
- Ein gruppenbeschreibbares `/etc/passwd` erlaubt Gruppenmitgliedern, ein UID-0-Konto
  anzulegen. Deshalb nennt CIS diese Dateien.
- Auf echten Hosts können Sicherungen fehlen. Mit `stat` prüfen und `when` nutzen, wie im Bonus.

### Weiterführend
- Lektion [L02 - Sichere Änderungen](../../../docs/lessons/L02-safe-changes.de.md): `--check --diff` vor einer Änderung und was der Check-Modus vorhersagen kann.
- Lektion [L03 - Basis-Härtung](../../../docs/lessons/L03-base-hardening.de.md): Pakete, Dienste, Dateien, SSH und sudo an einem Ort.
- Übung [1.01 - Unsichere Client-Pakete entfernen](../1.01-remove-telnet/README.de.md)
- Übung [2.01 - /etc/shadow: richtige Rechte je OS-Familie](../../stage2-building-blocks/2.01-shadow-permissions-per-family/README.de.md)

## Musterlösung

Anzeigen mit `lab solution 1.02`, anwenden mit `lab solve 1.02`.
