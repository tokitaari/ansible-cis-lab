# 4.03 - Datengetriebene Rolle für alle Plattformen (inkl. Alpine): Erklärung

### Was der Check prüft
`lab check 4.03` startet `check.sh`, danach dein Playbook noch einmal mit `--check` und erwartet
`changed=0` (`idempotency: true` in `meta.yml`). `check.sh` prüft:
- `4.03/site.yml` existiert, und die Rolle hat `section5_password_policy.yml`, `section5_pam.yml`,
  `section5_accounts.yml` und `section6_logging.yml`;
- keine Zeile unter `tasks/` enthält einen Fakten-Vergleich: ein `grep` auf `os_family` oder
  `distribution` gefolgt von `==`, `!=` oder ` in `, ohne Kommentare, ohne Zeilen mit `first_found`
  und ohne Zeilen, die auf `.yml` enden; und `tasks/main.yml` enthält das Wort
  `distribution_major_version`;
- `ansible-lint --offline --profile moderate` läuft auf der Rolle durch;
- die Zustands-Checks von 15 früheren Übungen bestehen (0.04, 1.01-1.05, 2.01-2.06, 3.02, 3.03,
  3.05), mit `-e cis_level=2` sind es 16 (3.04 kommt dazu). Ohne gibt der Check einen Hinweis aus,
  dass 3.04 nicht geprüft wurde; Variablen als `-e @Datei` werden nicht ausgewertet.

Seine Grenzen (das `grep` wurde an Beispielzeilen ausprobiert): Es übersieht einen Filter vor dem
Vergleich (`os_family | lower == 'debian'`), einen Vergleich ohne `==`, `!=` oder ` in `
(`distribution_major_version | int >= 10`, `is match(...)`) und eine auf zwei Zeilen verteilte
Bedingung. Ein Kommentar, der `distribution_major_version` erwähnt, erfüllt den Loader-Test. Der
Check kann nicht beurteilen, ob die Lookup-Liste in der richtigen Reihenfolge steht oder die
Dateien die richtigen Flags enthalten; die früheren Checks zeigen das nur indirekt und nur auf den
acht Hosts des Labs.

### So funktioniert es

#### Daten schlagen Verzweigungen
Vergleiche:
```yaml
# verzweigt
- when: ansible_facts.os_family in ['Debian', 'RedHat']
# datengetrieben
- when: cis_pwquality_supported
```
Die zweite Version sagt, *warum* der Task läuft. Eine neue Plattform zu unterstützen heißt dann:
eine vars-Datei und eine Prüfung der Flags - keine Änderung an der Task-Logik, kein Risiko für
bestehende Plattformen. In der Musterlösung fragen die Tasks vier Plattform-Flags ab:
`cis_pwquality_supported`, `cis_pam_tool`, `cis_cron_allow_supported` und
`cis_apt_cache_refresh`. Namen, Pfade und Modi (`cis_sshd_service`, `cis_pam_password_stack`,
`cis_shadow_mode`) sind ebenfalls Daten, brauchen aber kein `when`.

#### Die Variablenhierarchie
Der Loader probiert `<distribution>-<major>.yml`, `<distribution>.yml`, `<os_family>.yml` und
`default.yml` und lädt die erste vorhandene Datei: **eine** Datei. Was die Ziele des Labs daraus
machen, zeigt die Tabelle unten. Drei Folgen:
- Ubuntu gehört zur Debian-Familie und die Musterlösung hat keine `Ubuntu.yml`, also bedient
  `Debian.yml` beide. Arch ist rollierend: Seine "Hauptversion" ist das Image-Datum, deshalb würde
  `Archlinux-20261101.yml` nie wieder passen. openSUSE meldet `openSUSE Leap` mit Leerzeichen; eine
  Datei dieses Namens würde in `first_found` funktionieren, das Lab nimmt `Suse.yml`.
- Ein mit `include_vars` geladener Wert schlägt `group_vars` und Play-Variablen; nur `-e` gewinnt
  (gemessen in L11). Flags in `vars/` sind Tatsachen der Plattform; was ein Betreiber je Host
  einstellen soll, gehört in `defaults/`.
- Weil es nur diese eine Datei gibt, muss sie vollständig sein. Gemessen mit der Musterlösung und
  einer `vars/Ubuntu.yml`, die nur `cis_cron_allow_supported: false` setzt, auf einem Ubuntu-Host:
  der erste Task bricht mit `'cis_apt_cache_refresh' is undefined` ab; setzt man dieses Flag auf der
  Kommandozeile, sind `cis_audit_package`, `cis_pam_tool` und `cis_sshd_service` undefiniert.
  Schichten löst das: erst `default.yml` laden, dann die Familiendatei, dann die vorhandenen
  Distributionsdateien, allgemein zuerst. Mit diesem Loader bekam derselbe Host
  `cis_cron_allow_supported` aus `Ubuntu.yml` und alles andere aus `Debian.yml`; ohne `Ubuntu.yml`
  kamen alle Werte aus `Debian.yml`.

#### Alpine als vollwertige Plattform
Alpine erzwingt die ehrlichen Fragen. Gemessen in L08: `/etc/pam.d` existiert und das Modul
`faillock` wird mitgeliefert, aber es gibt dort keine `pam_unix`-Passwortzeile und pwquality ist
nicht installiert, "kein PAM" wäre also zu stark; die Rolle sagt `cis_pam_tool: none` und
`cis_pwquality_supported: false`. Das BusyBox-crontab ignoriert `cron.allow` (L06), daher
`cis_cron_allow_supported: false` und stattdessen ein eingeschränktes Cron-Spool-Verzeichnis. Python
gibt es erst nach dem Bootstrap, darum beginnt `site.yml` mit einem Play für `alpine_family`, das es
per `raw` installiert. Jede Frage wird ein Flag mit Kommentar zur kompensierenden Kontrolle oder
dokumentierten Lücke.

#### Regressionstests
Du hast gerade eine Rolle geändert, die acht Plattformen härtet. Die früheren Checks sind dein
Sicherheitsnetz: 15 davon (16 bei Level 2) müssen nach **einem** Lauf auf frisch zurückgesetzten
Hosts bestehen, und der zweite Lauf mit `--check` darf nichts ändern. `lab check 4.03` erledigt
beides. Ein Level-2-Lauf braucht `-e cis_level=2` für das Playbook und für `lab check`.

### Hinweise je Familie

| os_family | Hosts | `distribution` / Major | Geladene Datei | `cis_pam_tool` | `cis_pwquality_supported` | `cis_cron_allow_supported` |
|---|---|---|---|---|---|---|
| Debian | debian, ubuntu | Debian 13, Ubuntu 26 | `Debian.yml` für beide | `pam-auth-update` | true | true |
| RedHat | rocky, alma, fedora | Rocky 10, AlmaLinux 10, Fedora 44 | `RedHat.yml` | `authselect` | true | true |
| Suse | opensuse | `openSUSE Leap` 16 | `Suse.yml` | `manual` | false | true |
| Archlinux | arch | Archlinux 20261101 | `Archlinux.yml` | `manual` | false | true |
| Alpine | alpine | Alpine 3 | `Alpine.yml` | `none` | false | false |

| os_family | sshd- / Cron-Dienst | Shadow-Gruppe, Modus | Audit-Paket | apt-Index auffrischen |
|---|---|---|---|---|
| Debian | `ssh` / `cron` | `shadow`, `0640` | `auditd` | true |
| RedHat | `sshd` / `crond` | `root`, `0000` | `audit` | false |
| Suse | `sshd` / `cron` | `shadow`, `0640` | `audit` | false |
| Archlinux | `sshd` / `cronie` | `root`, `0600` | `audit` | false |
| Alpine | `sshd` / `crond` | `shadow`, `0640` | `audit` | false |

Distribution, Major-Version und geladene Datei wurden mit dem Loader der Musterlösung auf allen
acht Zielen gemessen (sie ändern sich, wenn ein Image neu gebaut wird); Flags und Werte stammen aus
den `vars/`-Dateien der Musterlösung. Suse und Arch tragen `manual` und ein falsches pwquality-Flag
als dokumentierte Lücken: Die Rolle installiert und konfiguriert dort kein pwquality (bei Suse
überlässt der Kommentar in `Suse.yml` die pam-config-Arbeit dem Bonus von 3.03).

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Lösung |
|---|---|---|
| `'cis_apt_cache_refresh' is undefined` (oder ein anderes Flag) | eine Teildatei `Ubuntu.yml` im Ein-Datei-Loader | die Datei vervollständigen oder die Ladungen schichten, allgemein zuerst |
| `Conditional result (True) was derived from value of type 'str' at "<CLI option '-e'>"` | `-e cis_apt_cache_refresh=false` ist der String `"false"` | `-e '{"cis_apt_cache_refresh": false}'` |
| `can only concatenate list (not "CapturedExceptionMarker") to list` | ein geschichteter Loader, dessen Lookup für optionale Dateien kein `skip` bekam (neben dem Dict übergeben hatte es im Test keine Wirkung) | `'skip': true` in das Parameter-Dict schreiben |
| eine Versionsdatei für arch wird nie ein zweites Mal verwendet | rollierende Distribution, die "Hauptversion" ist das Image-Datum | die Distributions- oder Familiendatei nehmen |
| der Check ist grün, obwohl ein Task `os_family \| lower == ...` vergleicht | das `grep` endet an einer Pipe | ein Flag verwenden; der Check unterstützt nur deine Durchsicht |
| `interpreter /usr/bin/python3 not found` auf alpine | kein Python vor dem Bootstrap | das Pre-Play von `site.yml` oder `lab solve 0.02 -y` |

### Praxis-Hinweise
- Wo sich eine Fähigkeit auf dem Host prüfen lässt (ein Befehl existiert oder nicht), schlägt
  Prüfen eine Tabelle von Versionen. Flags bleiben für das, was sich nicht prüfen lässt:
  Grundsatzentscheidungen wie das PAM-Werkzeug, das die Rolle verwaltet.
- `default.yml` entscheidet, was eine unbekannte Plattform bekommt. Auf Werte zurückfallen, die
  nichts aktivieren, dessen die Rolle nicht sicher ist, und den Bericht (5.01) die übersprungenen
  Kontrollen als nicht anwendbar zeigen lassen: ein stilles Überspringen ist ein Loch, ein
  Default, der alles aktiviert, bricht den ersten Host, den niemand getestet hat.

### Weiterführend
- Lektion [L11 - Profile, Ausnahmen und datengetriebene Rollen](../../../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.de.md): Flags, eine Datei oder Schichten, Test von außen.
- Lektion [L04 - Plattformunterschiede als Daten](../../../docs/lessons/L04-platform-differences-as-data.de.md): Dictionaries, Schleifen und Templates hinter den vars-Dateien.

## Musterlösung

Anzeigen mit `lab solution 4.03`, anwenden mit `lab solve 4.03`.
