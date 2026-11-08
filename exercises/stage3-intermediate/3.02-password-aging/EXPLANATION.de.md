# 3.02 - Passwortalterung und inaktive Konten: Erklärung

### Was der Check prüft
`lab check 3.02` führt `check.yml` auf `targets` aus. Er liest `/etc/login.defs` (oder
`/usr/etc/login.defs`, wenn die erste fehlt), danach jede `/usr/etc/login.defs.d/*.defs` und
`/etc/login.defs.d/*.defs`, nimmt pro Schlüssel den **letzten** Wert und liest `INACTIVE` aus
`useradd -D`. Er prüft `PASS_MAX_DAYS` 1-365, `PASS_MIN_DAYS` ≥ 1, `PASS_WARN_AGE` ≥ 7,
`ENCRYPT_METHOD` `SHA512` oder `YESCRYPT`, `INACTIVE` 1-45. Danach läuft dein Playbook noch einmal
mit `--check` und muss `changed=0` melden.

Was er nicht prüft:

- Ob der Host die Drop-ins **liest**. Gemessen: Nur rocky, alma, fedora und opensuse tun es;
  debian, ubuntu, arch und alpine ignorieren `/etc/login.defs.d` (Details unten). Eine Lösung nur
  mit Drop-in besteht dort den Check und ändert nichts.
- Eine Abschwächung: `YESCRYPT`, ersetzt durch `SHA512`, besteht; beide Werte sind erlaubt.
- Ob die Werte bei Konten ankommen. Auf arch wird `PASS_MIN_DAYS` verlangt, aber shadow 4.20
  ignoriert es.
- Bestehende Konten (Bonus 1) - nur die Defaults für neue.

### So funktioniert es

#### `login.defs` ist eine Vorlage für neue Konten
`useradd` kopiert `PASS_*` in den `shadow`-Eintrag eines Kontos, das es anlegt; `useradd -D` hält
den Inaktivitäts-Default in `/etc/default/useradd`. Gemessen mit einem per `useradd` angelegten
Konto (Felder min:max:warn:inactive aus `/etc/shadow`):

- vor der Übung: `0:99999:7:` auf debian, ubuntu, der Red-Hat-Familie und opensuse; `:::` auf arch
  und alpine, deren `login.defs` keine `PASS_*`-Zeilen hat - solche Konten altern nie;
- nach der Musterlösung: `1:365:7:45` überall außer arch, `:365:7:45`.

#### `lineinfile` mit verankertem `regexp`
`regexp: '^\s*{{ item.key }}\s'` trifft die aktive Zeile, keine auskommentierte; ohne Treffer wird
die Zeile am Ende angehängt. Gemessen in Lauf 1: `PASS_MAX_DAYS` und `PASS_MIN_DAYS` änderten sich
auf den sieben Hosts mit `/etc/login.defs`, `PASS_WARN_AGE` nur auf arch und alpine (angehängt; die
anderen hatten schon `7`). Lauf 2: `changed=0`.

#### Vendor-Split und Drop-ins
opensuse hat kein `/etc/login.defs`, nur `/usr/etc/login.defs`; die Datei in `/etc` anzulegen würde
die Vendor-Datei ersetzen, nicht ergänzen. Die Lösung schreibt stattdessen
`/etc/login.defs.d/50-cis.defs`. Ob ein Drop-in zählt, hängt davon ab, wie `shadow` gebaut wurde:
Die vier Hosts, deren `useradd` gegen `libeconf` gelinkt ist, nutzten ein Test-Drop-in
(`PASS_WARN_AGE 11` → neues Konto `11`), die vier ohne nicht (gemessen). Die Regel gilt allgemein:
Finde heraus, wie ein Programm seine Konfiguration liest, bevor du sie schreibst.

#### `ENCRYPT_METHOD`: lesen, vergleichen, dann schreiben
`slurp` + `regex_findall(...) | last | default('none')` liest das aktuelle Verfahren; der Task
schreibt `SHA512` nur, wenn es weder `SHA512` noch `YESCRYPT` ist. Gemessen: Die Zeile änderte sich
nur auf alpine, dessen `login.defs` keine hatte. yescrypt ist speicherhart und kostet einen
Angreifer mehr als SHA-512-crypt; es zu überschreiben würde den Host schwächen, ohne dass ein
Scanner es merkt.

`login.defs` ist nicht die einzige Stelle, die ein Hashverfahren wählt. Das Präfix eines mit
`chpasswd` gesetzten Hashes änderte sich durch diese Übung auf keinem Host: `$y$` auf debian,
ubuntu, der Red-Hat-Familie und arch, `$6$` auf opensuse und alpine. Auf alpine war es schon `$6$`,
bevor es irgendeine `ENCRYPT_METHOD`-Zeile gab, dort wählt also etwas anderes; sein
`/etc/pam.d/chpasswd` bindet `base-password` ein (nicht weiter verfolgt). L08 zeigt, dass eine
`pam_unix`-Zeile das Verfahren selbst nennen kann.

#### Befehle: erst lesen, dann handeln
`useradd -D` läuft mit `changed_when: false` und `check_mode: false`, also auch unter `--check`;
`useradd -D -f 45` läuft nur, wenn `INACTIVE=45` fehlt, und meldet `changed` ehrlich. Gemessen: In
Lauf 1 auf allen acht geändert, in Lauf 2 übersprungen. Auf opensuse legte es
`/etc/default/useradd` an (es gab keine, auch nicht in `/usr/etc`).

#### shadow 4.20 und das Mindestalter
arch hat shadow 4.20.0, das das Mindestalter für Passwörter entfernt hat: `PASS_MIN_DAYS` ist noch
ein bekannter Schlüssel (keine Warnung "unknown item", shadow-Quelltext), aber `useradd` ignoriert
ihn und leert das Feld. Die Zeile aus dieser Übung verlangt der Check also, auf arch wirkt sie nicht
(neues Konto: leeres Min-Feld). `chage --mindays` gibt es dort nicht; 4.04 zeigt, wie man das
erkennt.

### Hinweise je Familie
| os_family | shadow | `login.defs` am Start | Liest `login.defs.d` | `ENCRYPT_METHOD` am Start | Neues Konto nach der Lösung | Hash von `chpasswd` |
|---|---|---|---|---|---|---|
| Debian | 4.17.4 | `/etc`, `PASS_*` vorhanden | nein | `YESCRYPT` | `1:365:7:45` | `$y$` |
| RedHat | 4.15.0 (rocky, alma), 4.19.0 (fedora) | `/etc`, `PASS_*` vorhanden | ja | `YESCRYPT` | `1:365:7:45` | `$y$` |
| Suse | 4.17.2 | nur `/usr/etc` | ja | `SHA512` | `1:365:7:45` | `$6$` |
| Alpine | 4.18.0 | `/etc`, kein `PASS_*`, kein Verfahren | nein | keins → `SHA512` geschrieben | `1:365:7:45` | `$6$` (auch vorher) |
| Archlinux | 4.20.0 | `/etc`, kein `PASS_*` | nein | `YESCRYPT` | `:365:7:45` | `$y$` |

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| Check besteht, neue Konten bekommen weiter `99999` | Werte nur in einem Drop-in auf einem Host ohne `libeconf` | `/etc/login.defs` bearbeiten, wo es existiert |
| opensuse verliert seine Vendor-Defaults | `/etc/login.defs` neben `/usr/etc/login.defs` angelegt | Drop-in in `/etc/login.defs.d` |
| Aus `YESCRYPT` wurde `SHA512` | `lineinfile` ohne Bedingung | erst das Verfahren lesen |
| `useradd -D -f 45` meldet bei jedem Lauf `changed` | kein Leseschritt | erst `useradd -D`, `when` auf dessen Ausgabe |
| Min-Feld auf arch leer trotz `PASS_MIN_DAYS 1` | shadow 4.20 ignoriert den Schlüssel | erwartet; die Fähigkeit erkennen (4.04) |
| Bestehende Konten behalten `99999` | `login.defs` gilt nur für neue Konten | `chage --maxdays` / `user: password_expire_max` |

### Praxis-Hinweise
- Korrigiere auch bestehende Konten (Bonus 1): CIS prüft den Default und jedes Konto mit Passwort.
  Überspringe gesperrte (`!`) und passwortlose (`*`) Einträge.
- Prüfe die Wirkung, nicht die Datei: Testkonto anlegen, seine `shadow`-Felder lesen, löschen.
- Halte die Wahl des Hashverfahrens pro Familie an einer Stelle und prüfe sowohl `login.defs` als
  auch den PAM-Stack.

### Weiterführend
- Lektion [L08 - Konten und PAM](../../../docs/lessons/L08-accounts-and-pam.de.md): `shadow`-Felder, Hash-Präfixe, Vendor-Split.
- Übung [3.03 - Passwortqualität mit pam_pwquality](../3.03-password-quality/README.de.md)
- Übung [4.04 - Ansible Vault: Notfall-Admin-Konto](../../stage4-advanced/4.04-vault-break-glass-account/README.de.md): `--mindays` erkennen.
- [`login.defs(5)`](https://man.archlinux.org/man/login.defs.5), [`shadow(5)`](https://man.archlinux.org/man/shadow.5), [`chage(1)`](https://man.archlinux.org/man/chage.1), [`useradd(8)`](https://man.archlinux.org/man/useradd.8)

## Musterlösung

Anzeigen mit `lab solution 3.02`, anwenden mit `lab solve 3.02`.
