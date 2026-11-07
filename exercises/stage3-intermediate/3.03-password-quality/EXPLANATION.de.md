# 3.03 - Passwortqualität mit pam_pwquality: Erklärung

### Was der Check prüft
`lab check 3.03` führt `check.yml` auf der Debian- und der Red-Hat-Familie aus (fünf Hosts) und
dann dein Playbook noch einmal mit `--check`; erwartet wird `changed=0` (`meta.yml` sagt
`idempotency: true`). `check.yml` liest `/etc/security/pwquality.conf.d/50-cis.conf` und die
PAM-Datei der Familie (`common-password` oder `system-auth`) und prüft:
- das letzte `minlen` ist mindestens 14, das letzte `minclass` mindestens 4, die letzten
  `maxrepeat` und `maxsequence` liegen zwischen 1 und 3;
- eine Zeile `dictcheck = 1` und eine Zeile, die nur aus `enforce_for_root` besteht;
- der Text `pam_pwquality` irgendwo in der PAM-Datei.

Nicht geprüft wird: Eigentümer und Modus des Drop-ins, das Paket, andere Drop-ins mit
niedrigeren Werten, ob der Treffer `pam_pwquality` eine aktive Zeile oder ein Kommentar ist, und
die Rollendatei `section5_pam.yml` mit ihrem Tag. Auf der Red-Hat-Familie beweist die PAM-Prüfung
nichts über dein Play: `system-auth` und `password-auth` enthalten `pam_pwquality` schon auf
frischen rocky-, alma- und fedora-Hosts. Dort prüfen nur die Werte im Drop-in deine Arbeit.

### So funktioniert es

#### Drop-ins
`pwquality.conf` gehört dem Paket. `pwquality.conf.d/50-cis.conf` gehört dir - Paket-Updates
kollidieren nie damit, und die Kontrolle zu entfernen heißt, eine Datei zu entfernen.
libpwquality liest die Drop-ins in Namensreihenfolge, eine spätere Datei gewinnt
(`pwquality.conf(5)`). Das Verzeichnis ist nicht immer da: die Red-Hat-Hosts haben es zu Beginn,
Debian und Ubuntu haben gar kein pwquality, und die Installation von `libpam-pwquality` legte es
nicht an (gemessen auf Ubuntu 24.04). Leg es im Play an.

#### Wem PAM gehört
PAM-Dateien von Hand zu bearbeiten ist der häufigste Weg, Logins zu zerstören, *und* der häufigste
Grund, warum Härtung still zurückgedreht wird:
- **Debian/Ubuntu**: `pam-auth-update` erzeugt `common-*` neu aus Profilen in
  `/usr/share/pam-configs`. Eine Handänderung wird beim nächsten Paket überschrieben, das es
  aufruft.
- **RHEL/Fedora**: `system-auth` und `password-auth` sind symbolische Links nach
  `/etc/authselect/` (gemessen auf allen drei Hosts; das Profil ist `local` ohne Features).
  `authselect select ... --force` oder `authselect apply-changes` überschreiben Handänderungen.
Arbeite *mit* dem Werkzeug: Profile und Features aktivieren, nie erzeugte Dateien flicken.

#### Auf Debian verdrahtet schon das Paket PAM
Die Installation von `libpam-pwquality` ruft selbst `pam-auth-update` auf (gemessen auf Ubuntu
24.04): sie fügt `password requisite pam_pwquality.so retry=3` vor `pam_unix` ein und gibt der
`pam_unix`-Zeile `use_authtok try_first_pass`. Ein zweites `pam-auth-update --enable pwquality`
lässt die Datei unverändert. Das bedingte `pam-auth-update` der Lösung läuft also normalerweise
nie - es ist das Sicherheitsnetz für einen Host, auf dem jemand das Profil abgeschaltet hat.
`lab solve 3.03` meldete auf frischen Hosts `changed=3` auf debian und ubuntu (Paket, Verzeichnis,
Drop-in) und `changed=1` auf den Red-Hat-Hosts (nur das Drop-in).

#### `enforce_for_root` und die Werkzeuge von root
pwquality bewertet ein Passwort, wann immer ein Programm es über den PAM-*password*-Stack ändert.
Welche Programme das tun, ist je Familie verschieden (gemessen als root, mit einem Testbenutzer
und dem Passwort `abc`):
- **Debian, Ubuntu**: `/etc/pam.d/chpasswd` bindet `common-password` ein. Ohne
  `enforce_for_root` geben `passwd` und `chpasswd` `BAD PASSWORD: The password is shorter than 14
  characters` aus und setzen das Passwort trotzdem (rc 0). Mit der Option lehnen sie ab:
  `chpasswd` endet mit 1 und `password not changed`.
- **Red Hat (rocky, alma, fedora)**: es gibt kein `/etc/pam.d/chpasswd`. `chpasswd` setzte `abc`
  kommentarlos, `enforce_for_root` eingeschlossen.
- **Jede Familie**: ein fertiger Hash umgeht die Prüfung - `chpasswd -e` und `usermod -p` setzen
  ihn (rc 0).
Qualitätsregeln schützen interaktive Änderungen. Massenwerkzeuge und Provisionierung mit Hashes
liegen außerhalb ihrer Reichweite - das ist in Ordnung, wenn du es weißt.

#### Container
Die Lab-Images haben echte PAM-Stacks, die Konfiguration ist also dieselbe wie in einer VM. Was
du hier nicht testen kannst, ist ein Konsolen-Login.

### Hinweise je Familie
| `os_family` | Hosts | Zu Beginn | `chpasswd` als root mit `abc` nach der Lösung |
|---|---|---|---|
| Debian | debian, ubuntu | kein pwquality-Modul, kein `pwquality.conf.d`; `common-password` ohne `pam_pwquality` | abgelehnt (rc 1) |
| RedHat | rocky, alma, fedora | `pam_pwquality` in `system-auth` und `password-auth`, `pwquality.conf.d` vorhanden; authselect-Profil `local` | angenommen (rc 0), kein `/etc/pam.d/chpasswd` |

Außerhalb des Umfangs (Bonus 1 und 2): opensuse, arch und alpine haben zu Beginn kein
`pam_pwquality`. `chpasswd` nutzt PAM auf arch (`system-auth`) und alpine (`base-password`);
opensuse hat kein `/etc/pam.d/chpasswd`.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| `No package matching 'libpam-pwquality' is available` | das Image enthält einen leeren Index, und `cache_valid_time` hält sein Verzeichnis für frisch | `update_cache: true` ohne `cache_valid_time`, oder vorher nach `*_Packages*` suchen wie die Lösung |
| Debian/Ubuntu: `Destination directory /etc/security/pwquality.conf.d does not exist` | das Paket legt es nicht an | vorher ein `file`-Task mit `state: directory` |
| Der Check ist auf Red Hat grün, bevor du anfängst | `pam_pwquality` steht schon in `system-auth` | deine Arbeit am Drop-in messen |
| Ein schwaches root-Passwort wird mit Warnung angenommen | `enforce_for_root` fehlt | die nackte Zeile `enforce_for_root` ergänzen |
| Deine Werte werden ignoriert | ein Drop-in, das in Namensreihenfolge später kommt, setzt andere | ein Drop-in je Einstellung, ein klares Präfix |

### Praxis-Hinweise
- Von Automatisierung angelegte Konten bekommen meist einen Hash, kein Passwort -
  Qualitätsregeln sehen ihn nie. Erzeuge diese Passwörter lang genug, oder nutze nur Schlüssel.
- Zentrale Identitätssysteme haben ihre eigene Passwortrichtlinie; pwquality schützt lokale
  Konten.

### Weiterführend
- Lektion [L08 - Konten und PAM: wer sich anmelden darf, wie und mit welchem Passwort](../../../docs/lessons/L08-accounts-and-pam.de.md): PAM-Stacks, die Werkzeuge, denen sie gehören, pwquality und faillock - die Konzepte vor dieser Übung.
- Übung [3.02 - Passwortalterung und inaktive Konten](../3.02-password-aging/README.de.md): die andere Hälfte der Passwortrichtlinie.
- Übung [4.06 - Kontosperre mit pam_faillock (authselect)](../../stage4-advanced/4.06-faillock-authselect/README.de.md): das nächste PAM-Modul, auf dieselbe Weise verwaltet.

## Musterlösung

Anzeigen mit `lab solution 3.03`, anwenden mit `lab solve 3.03`.
