# 4.10 - Paketsignaturen: jedes Repository geprüft, keine Umgehung: Erklärung

### Was der Check prüft
`lab check 4.10` führt `check.yml` auf allen acht Targets aus und dann dein Playbook noch einmal
mit `--check` und erwartet `changed=0` (`meta.yml` sagt `idempotency: true`). Je `pkg_mgr` liest
er, was der Manager selbst ausgibt:

- **apt:** `apt-config dump` hat keinen von `Acquire::AllowInsecureRepositories`,
  `Acquire::AllowWeakRepositories`, `Acquire::AllowDowngradeToInsecureRepositories` und
  `APT::Get::AllowUnauthenticated` auf true; ein `awk`-Programm geht `sources.list` und jede
  `*.list`- und `*.sources`-Datei durch und gibt je Eintrag (einzeilig) oder Stanza (deb822) eine
  Zeile aus - jede muss `Signed-By` nennen und darf keine Option `trusted`, `allow-insecure`,
  `allow-weak` oder `allow-downgrade-to-insecure` tragen.
- **dnf, dnf5:** ein paar Zeilen Python fragen die dnf-API (dnf4) oder libdnf5 nach den wirksamen
  Werten: `gpgcheck` des Hauptabschnitts und für jedes Repository sein `gpgcheck` und ob es einen
  `gpgkey` nennt. Alles muss an sein.
- **dnf, dnf5, zypper:** eine Zeile `gpgcheck=1` (auch `yes`, `true`, `on`) in `dnf.conf` bzw.
  `zypp.conf`.
- **zypper:** `zypper --xmlout lr` listet jedes Repository mit `gpgcheck="1"`,
  `repo_gpgcheck="1"` und einem nicht leeren `gpgkey`.
- **pacman:** Für jedes Repository muss sein eigenes `SigLevel` aus `pacman-conf -r` oder, wenn es
  keines setzt, das globale `PackageRequired` enthalten und nicht `PackageTrustAll`.
- **apk:** keine Zeile `allow-untrusted` in `/etc/apk/config` oder `/lib/apk/config`, und jede
  Repository-Zeile ist eine `https://`-URL.
- **Aktualisierung** (apt, dnf, dnf5, zypper, apk): `apt-get update`, `dnf -y makecache`, `zypper -n
  refresh`, `apk update` enden mit 0 und geben nichts von `is not signed`, `NO_PUBKEY`,
  `UNTRUSTED`, `BADSIG`, `EXPKEYSIG` aus.

Nicht geprüft wird, dass die Daten in einem Dict stehen oder dass ein `assert` sie absichert, dass
der Schlüssel, den eine Quelle nennt, existiert oder der richtige ist (nur die Aktualisierung
bemerkt einen fehlenden), in welchem Abschnitt der Hauptdatei die Zeile `gpgcheck` steht,
`localpkg_gpgcheck` oder `LocalFileSigLevel`, wem die Schlüssel in `/etc/apk/keys` gehören, oder
dass du das alte Repository *entfernt* hast - es mit einem echten Schlüssel zu versehen, besteht
auch. Gemessen mit der Musterlösung: Der Check scheitert auf allen acht Hosts eines frischen Labs
(nach 0.02); der erste Lauf ändert 3 Tasks auf fedora, opensuse und alpine, 2 auf debian, ubuntu,
rocky und alma, 1 auf arch; der zweite Lauf und `--check` ändern nichts; der ganze Runner-Job
(`tools/run-solutions.sh 4.10`: Reset, 0.02, Lösung, Check, zweiter Lauf) dauerte 122 s.

### So funktioniert es

#### "Hat keinen Schlüssel" ist eine Mengendifferenz
```yaml
loop: >-
  {{ (cis_repo_all.files | map(attribute='path'))
     | difference(cis_repo_keyed.files | map(attribute='path')) | sort }}
```
Zwei `find`-Läufe über dasselbe Verzeichnis, einer mit `contains:` für eine Schlüsselzeile, geben
zwei Listen von Pfaden; was in der ersten steht und nicht in der zweiten, hat keinen Schlüssel und
fliegt. apt fügt mit `| union(...)` eine dritte Liste hinzu: Eine Quelle, die einen Schlüssel nennt
*und* `trusted=yes` sagt, ist trotzdem eine Umgehung. `contains:` wird mit `re.match` auf jede Zeile
angewendet, also beginnt ein Muster, das mitten in einer Zeile stehen kann, mit `.*`
(`(?i)(.*signed-by=|signed-by:)` deckt die einzeilige und die deb822-Form ab). Die Listen sind
sortiert, damit die Reihenfolge der Schleife und die Ausgabe von Lauf zu Lauf gleich bleiben.

#### Der Wert im Repository gewinnt
`gpgcheck=0` in `[main]` von `dnf.conf` änderte keines der Repositories von rocky und alma: Jedes
setzt selbst `gpgcheck=1`, und die dnf-API meldete für jedes weiter `True`. Umgekehrt ist ein
Repository mit `gpgcheck=0` ungeprüft, egal was `[main]` sagt. Deshalb fragt der Check beides ab,
und deshalb schaltet die Lösung die Repository-Zeilen mit `replace` in jeder Datei ein, die einen
Schlüssel hat. Auf fedora enthält `dnf.conf` nur `[main]` und `tsflags=nodocs`; die Prüfung ist
standardmäßig an (`dnf5 --dump-main-config`: `gpgcheck = 1`, `pkg_gpgcheck = 1`), aber ein Audit,
das die Datei liest, findet nichts, also wird die Zeile ausdrücklich geschrieben.

#### Der wirksame Wert ist die Antwort des Managers
Keiner der Manager verlangt, dass du seine Dateien parst: dnf4 hat seine Python-API (`dnf
config-manager --dump` antwortete auf alma, nicht auf rocky), dnf5 hat `--dump-main-config` und
`--dump-repo-config`, zypper `--xmlout lr`, pacman `pacman-conf`. Zwei Antworten wollen genau
gelesen werden. `pacman-conf -r core SigLevel` gab nichts aus: Es zeigt nur, was ein Abschnitt
setzt, und ein Abschnitt ohne `SigLevel` nimmt den globalen Wert. Bei zypper wechselte
`pkg_gpgcheck` nach dem ersten `zypper ref` auf denselben Repositories von `1` auf `0`: Ist es
nicht gesetzt, prüft libzypp Paketsignaturen nur, solange die Metadaten nicht gültig signiert
sind - signierte Metadaten tragen die Prüfsummen der Pakete. Der Check verlangt deshalb `gpgcheck`
und `repo_gpgcheck`, nicht `pkg_gpgcheck`.

#### Einen INI-Abschnitt entfernen
`community.general.ini_file` mit nur `section:` und `state: absent` löscht die Überschrift und
jede Zeile bis zur nächsten Überschrift, Kommentare eingeschlossen; `pacman.conf` mit zwei
Abschnitten `[options]` war kein Problem (gemessen in der Session und auf arch). `create: false`
hält das Modul davon ab, eine fehlende Datei anzulegen, und erfüllt `risky-file-permissions` von
`ansible-lint`.

### Hinweise je Familie
| `pkg_mgr` | Hosts | Eingepflanzt | Die Lösung ändert | Hinweise |
|---|---|---|---|---|
| `apt` | debian, ubuntu | `lab-legacy.list` mit `[trusted=yes]` | entfernt sie, `apt-get update` | debian apt 3.0.4 prüft mit `sqv`, ubuntu apt 3.2.1 mit `gpgv`; 9 / 2 Archivschlüssel in `trusted.gpg.d` |
| `dnf` | rocky, alma | deaktiviertes Repository `lab-legacy`, `gpgcheck=0`, kein Schlüssel | entfernt es, `dnf makecache` | dnf 4.20; `skip_if_unavailable=False` |
| `dnf5` | fedora | dasselbe; keine Zeile `gpgcheck` in `dnf.conf` | `gpgcheck=1` in `[main]`, entfernt das Repository, Aktualisierung | dnf5 5.4.6, rpm 6.0; `skip_if_unavailable = 1` |
| `zypper` | opensuse | dasselbe in `/etc/zypp/repos.d/` | `gpgcheck=1` in `zypp.conf`, entfernt das Repository, `zypper ref` | die Hersteller-Repositories kommen vom Service `openSUSE` |
| `pacman` | arch | `[lab-legacy]` mit `SigLevel = Optional TrustAll` | entfernt den Abschnitt | `SigLevel = Required DatabaseOptional` |
| `apk` | alpine | alte Repository-Zeile, `allow-untrusted` in `/etc/apk/config` | entfernt beide Zeilen, `apk update` | apk-tools 3.0.9 |

Die rpm-Schlüssel waren in allen vier rpm-Images schon importiert (`rpm -q gpg-pubkey`: rocky 2,
alma 1, fedora 1, opensuse 6). Ein deaktiviertes Repository mit `gpgcheck=0` ändert beim
Installieren nichts, aber das CIS-Audit liest jede Repository-Datei, aktiviert oder nicht.

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Abhilfe |
|---|---|---|
| `apt-get update` schweigt zum alten Mirror | `trusted=yes` und `Trusted: yes` schalten die Prüfung ohne Warnung ab (nur `Ign: ... Release.gpg`) | die Quellen lesen; den Eintrag entfernen |
| Eine unsignierte Quelle scheitert mit rc 100 "is not signed" | die Prüfung wirkt - bis `Acquire::AllowInsecureRepositories "true"` daraus eine `W:`-Zeile und rc 0 macht | keine globale Umgehung in `apt.conf.d` |
| `gpgcheck=0` in `[main]`, jedes Repository prüft trotzdem | der Wert im Repository gewinnt | beide Ebenen prüfen und setzen |
| `find` mit `contains: signed-by=` findet nichts | `re.match` ab dem Zeilenanfang | `.*signed-by=` |
| zypper `pkg_gpgcheck="0"` nach einer Aktualisierung | nicht gesetzt, folgt es der Metadatensignatur | `gpgcheck` + `repo_gpgcheck` verlangen |
| `pacman-conf -r core SigLevel` ist leer | es gibt nur den eigenen Wert des Abschnitts aus | auf `pacman-conf SigLevel` zurückfallen |
| `apk update` endet mit 0 und `UNTRUSTED signature` | apk lässt das Repository weg und macht weiter | die Ausgabe durchsuchen, nicht nur den Exit-Code |
| Ein aktiviertes Repository ohne Metadaten: `dnf makecache` rc 1 auf rocky, rc 0 auf fedora | `skip_if_unavailable` False (el10) / 1 (fedora) | nicht auf Fehler verlassen; die Konfiguration lesen |
| `pacman -Sy` mit einem Scratch-`--dbpath` aus `mktemp -d`: "Permission denied" | pacman 7 lädt als Benutzer `alpm` herunter, das Verzeichnis ist 0700 | keine Aktualisierung bei pacman (seine Datenbanken sind nicht signiert) |
| Ein von `lineinfile` geleertes `/etc/apk/config` bleibt | das Modul entfernt Zeilen, nicht die Datei; apk liest nur die erste vorhandene Konfigurationsdatei (apk(8)), also verdeckt sie `/lib/apk/config` | im Lab harmlos; leer löschen |

`gpgcheck=0`, in eine Repository-Datei des zypper-Service geschrieben, überstand `zypper refs`:
Der Service schrieb die Datei nicht neu, solange er selbst unverändert war.

### Praxis-Hinweise
- Eine Aktualisierung beweist die Metadatensignatur nur dort, wo die Metadaten signiert und
  geprüft werden: apt (InRelease), zypper (`repo_gpgcheck`) und apk (signierter Index). dnf mit
  `repo_gpgcheck=0` und pacman mit `DatabaseOptional` prüfen stattdessen jedes Paket bei der
  Installation.
- Binde einen Fremdschlüssel an seine Quelle (`Signed-By` in `/etc/apt/keyrings/`, `gpgkey=` je
  Repository). Einem Schlüssel in `/etc/apt/trusted.gpg.d/` wird für jede Quelle vertraut; `apt-key`
  und `ansible.builtin.apt_key` sind aus diesem Grund abgekündigt.
- "Entfernt" ist die sichere Antwort für einen internen Mirror ohne Schlüssel. Die eigentliche
  Lösung ist, ihn zu signieren (ein eigener Repository-Schlüssel) und diesen Schlüssel mit derselben
  Automatisierung zu verteilen.
- Signaturen sagen, wer ein Paket gebaut hat, nicht, dass es fehlerfrei ist: Halte die Updates am
  Laufen (die Benchmarks führen das neben den Signaturpunkten, als manuellen).

### Weiterführend
- Lektion [L16 - Paketsignaturen](../../../docs/lessons/L16-package-signatures.de.md): die Vertrauenskette je Manager, globale und Repository-Schalter, die Sicht auf die wirksamen Werte - die Konzepte vor dieser Übung.
- Übung [4.09 - Systemprotokollierung](../4.09-system-logging/README.de.md): dieselbe Frage nach dem wirksamen Wert für journald und rsyslog.

## Musterlösung

Anzeigen mit `lab solution 4.10`, anwenden mit `lab solve 4.10`.
