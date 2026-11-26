# L16 - Paketsignaturen: apt, dnf, zypper, pacman und apk

*[English](L16-package-signatures.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 4.10 | 1.2 | ~25 Min. | L04, L15 |

Jedes Paket, das ein Target installiert, kommt über das Netz, und die Signaturprüfung ist das
Einzige, was das echte Paket von einem gefälschten unterscheidet. Alle fünf Paketmanager des Labs
prüfen Signaturen von Haus aus - und alle fünf haben einen Schalter, der die Prüfung abschaltet,
oft nur für ein Repository und ohne Warnung. Diese Lektion erklärt, was jeder Manager signiert und
prüft, wo seine Schalter sitzen, wie du ihn nach den wirksamen Werten fragst, und zwei
Ansible-Werkzeuge fürs Aufräumen: Listen von Dateien vergleichen und einen Abschnitt aus einer
INI-Datei entfernen.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] erklären, was eine Repository-Signatur beweist und mit welchem Schlüssel ein Manager sie prüft
- [ ] den globalen und den Repository-Schalter von apt, dnf, dnf5, zypper, pacman und apk finden und sagen, welcher gewinnt
- [ ] jeden Manager nach den wirksamen Werten fragen, statt seine Dateien zu lesen
- [ ] eine Quelle, die an ihren eigenen Schlüssel gebunden ist (`Signed-By`, `gpgkey`), von einer unterscheiden, die jedem Schlüssel des Hosts vertraut
- [ ] Daten je Manager mit `ansible_facts.pkg_mgr` wählen
- [ ] "Dateien ohne Schlüssel" mit Listenfiltern berechnen und einen INI-Abschnitt mit `ini_file` entfernen

## Theorie

### Was eine Signatur beweist

Ein Repository veröffentlicht einen Index - die Liste seiner Pakete mit ihren Prüfsummen - und
signiert ihn, oder jedes Paket, mit einem privaten Schlüssel. Der Host hat den passenden
öffentlichen Schlüssel. Stimmt die Signatur über den Index, gilt jede Prüfsumme darin, und damit
jedes Paket, das zu seiner Prüfsumme passt. Sind die Pakete selbst signiert, wird jedes einzeln
geprüft. So oder so endet die Kette bei einem öffentlichen Schlüssel auf dem Host, also zählen für
jedes Repository zwei Fragen: Ist die Prüfung an, und *welche* Schlüssel akzeptiert der Host dafür?

Ein Schlüssel, den der Host für jedes Repository akzeptiert, ist eine breite Tür: Wer den privaten
Schlüssel hat, kann Pakete für jede Quelle signieren. Ein Schlüssel, der an ein Repository gebunden
ist, signiert nur für dieses. Genau hier unterscheiden sich die Manager.

| Manager | Was signiert ist | Wo die öffentlichen Schlüssel liegen | An ein Repository gebunden? |
|---|---|---|---|
| apt | die Release-Datei (`InRelease`) mit den Prüfsummen der Indizes | die Datei aus `Signed-By`, sonst jeder Schlüssel in `/etc/apt/trusted.gpg.d/` | ja, mit `Signed-By` |
| dnf, dnf5, zypper | jedes Paket (rpm), wahlweise die Metadaten (`repomd.xml`) | die rpm-Schlüsseldatenbank, importiert aus `gpgkey=` | das Repository nennt seinen Schlüssel, aber rpm vertraut jedem importierten |
| pacman | jedes Paket; Datenbanken wahlweise | der pacman-Schlüsselbund (`pacman-key`) | nein |
| apk | der Index (`APKINDEX.tar.gz`) und jedes Paket | `/etc/apk/keys` | nein |

### apt: signierte Release-Dateien und `Signed-By`

Die Quellen von debian und ubuntu sind deb822-Dateien, eine Stanza je Gruppe von Suites:

```bash
ansible debian -m ansible.builtin.command -a "cat /etc/apt/sources.list.d/debian.sources"
```

Jede Stanza endet mit `Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp`: apt akzeptiert
für diese Suites nur diesen Schlüssel. Das einzeilige Format sagt dasselbe mit einer Option,
`deb [signed-by=/pfad/key.gpg] http://... suite main`. Eine Quelle ohne `Signed-By` fällt auf jeden
Schlüssel in `/etc/apt/trusted.gpg.d/` zurück, und dieses Verzeichnis ist nicht leer: Das Lab hat
auf debian neun Debian-Archivschlüssel gemessen und auf ubuntu zwei Ubuntu-Schlüssel. Für ein
Fremd-Repository gehört der Schlüssel nach `/etc/apt/keyrings/`, und die Quelle nennt ihn;
`ansible.builtin.deb822_repository` schreibt eine solche Quelle mit seinem Parameter `signed_by`.
Der alte Weg, `apt-key` und `ansible.builtin.apt_key`, legt den Schlüssel in den gemeinsamen
Schlüsselbund und ist abgekündigt.

Zwei Arten von Schaltern schalten die Prüfung ab. Je Quelle lässt `trusted=yes` (einzeilig) oder
`Trusted: yes` (deb822) apt die Quelle unsigniert annehmen. Global lassen Optionen in
`/etc/apt/apt.conf.d/` wie `Acquire::AllowInsecureRepositories` unsignierte Repositories durch.
`apt-config dump` gibt die zusammengeführte Konfiguration aus:

```bash
ansible debian,ubuntu -m ansible.builtin.shell -a "apt-config dump | grep -E 'Allow(Insecure|Weak|DowngradeToInsecure)Repositories|AllowUnauthenticated'"
```

Auf einem frischen Target stehen die drei Optionen `Acquire::Allow...` auf `"0"`, und
`AllowUnauthenticated` kommt nicht vor. Der Unterschied zwischen den Schaltern ist, wie laut sie
sind. Gemessen mit einem kleinen unsignierten Repository: ohne Schalter scheiterte `apt-get
update` mit Exit-Code 100 und "The repository ... is not signed"; mit
`Acquire::AllowInsecureRepositories "true"` gab es diese Zeile als Warnung (`W:`) aus und endete
mit 0; mit `trusted=yes` sagte es gar nichts - nur eine Zeile `Ign: ... Release.gpg` deutet an,
dass keine Signatur gesucht wurde. Ein sauberes `apt-get update` beweist nicht, dass jede Quelle
geprüft wurde; das zeigen die Quellen. debian 13 (apt 3.0) prüft mit `sqv`, ubuntu 26.04 (apt 3.2)
mit `gpgv`; das Ergebnis ist dasselbe.

### dnf und dnf5: `gpgcheck` an zwei Stellen

dnf liest `[main]` von `/etc/dnf/dnf.conf` und je Repository einen Abschnitt aus
`/etc/yum.repos.d/*.repo`. `gpgcheck` (dnf5 nennt es `pkg_gpgcheck` und behält `gpgcheck` als
Alias) schaltet die Paketprüfung, `repo_gpgcheck` die Prüfung der Metadaten, `localpkg_gpgcheck`
die Prüfung einer Paketdatei, die von der Platte installiert wird. `gpgkey=` nennt den Schlüssel
eines Repositorys; dnf importiert ihn in die rpm-Datenbank, wenn es ihn zum ersten Mal braucht. In
den Lab-Images waren die Schlüssel schon importiert (`rpm -q gpg-pubkey`).

Ein Wert in einem Repository-Abschnitt gewinnt gegen `[main]`. Gemessen auf rocky und alma: Mit
`gpgcheck=0` in `[main]` meldete jedes Repository weiter `gpgcheck` an, weil jedes selbst
`gpgcheck=1` setzt; ein Repository mit `gpgcheck=0` ist ungeprüft, egal was `[main]` sagt. Und ein
Standardwert braucht keine Zeile: `dnf.conf` von fedora enthält nur `tsflags=nodocs`, und trotzdem
ist die Prüfung an. Der Manager sagt dir, was wirksam ist. dnf5 hat Dump-Optionen:

```bash
ansible fedora -m ansible.builtin.shell -a "dnf5 --dump-main-config | grep gpgcheck"
```

Sie geben `gpgcheck = 1`, `pkg_gpgcheck = 1`, `repo_gpgcheck = 0` und `localpkg_gpgcheck = 0` aus
(und `gpgcheck_policy`); `dnf5 --dump-repo-config='*'` tut dasselbe je Repository, ein Block je
Repository, überschrieben mit seiner ID. dnf 4 auf rocky und alma hat ohne Plugin keine solche
Option (`dnf config-manager --dump` antwortete auf alma, nicht auf rocky), aber seine Python-API ist
installiert:

```bash
ansible rocky -m ansible.builtin.command -a "python3 -c 'import dnf; b = dnf.Base(); b.conf.read(); print(b.conf.gpgcheck, b.conf.repo_gpgcheck, b.conf.localpkg_gpgcheck)'"
```

`True False False`: Pakete werden geprüft, Metadaten und lokale Dateien nicht. Ein weiterer
Unterschied zwischen beiden: Ein aktiviertes Repository, dessen Metadaten sich nicht laden lassen,
stoppt `dnf makecache` auf rocky (`skip_if_unavailable=False`) und wird auf fedora übersprungen
(`skip_if_unavailable = 1`).

### zypper: drei Schalter und ein Service

zypper nutzt dieselbe rpm-Schlüsseldatenbank und dieselben drei Ideen: `gpgcheck`,
`repo_gpgcheck`, `pkg_gpgcheck`, in `[main]` von `/etc/zypp/zypp.conf` und je Repository in
`/etc/zypp/repos.d/*.repo`. Auf opensuse setzen die Dateien keinen davon - die Standardwerte
gelten -, und die Hersteller-Repositories erzeugt ein Service (`service=openSUSE`, definiert in
`/etc/zypp/services.d/`). `zypper --xmlout lr` listet jedes Repository mit den wirksamen Werten;
`raw_gpgcheck` erscheint nur dort, wo eine Datei den Wert selbst setzt:

```bash
ansible opensuse -b -m ansible.builtin.shell -a "zypper -n --xmlout lr | grep 'repo-oss (16.0)'"
ansible opensuse -b -m ansible.builtin.command -a "zypper -n refresh"
ansible opensuse -b -m ansible.builtin.shell -a "zypper -n --xmlout lr | grep 'repo-oss (16.0)'"
```

Auf einem frischen Target zeigt die erste Zeile `gpgcheck="1" repo_gpgcheck="1"
pkg_gpgcheck="1"`, die zweite (nach der Aktualisierung) `pkg_gpgcheck="0"`. Abgeschaltet wurde
nichts: Ist `pkg_gpgcheck` nicht gesetzt, prüft libzypp Paketsignaturen nur, solange die Metadaten
nicht gültig signiert sind, denn signierte Metadaten tragen schon die Prüfsummen der Pakete. "An"
heißt bei zypper deshalb `gpgcheck` und `repo_gpgcheck`.

### pacman: `SigLevel` und ein Schlüsselbund

`/etc/pacman.conf` hat einen Abschnitt `[options]` und einen Abschnitt je Repository. `SigLevel`
nimmt Wörter: `Required`, `Optional` oder `Never` für die Stärke, `TrustedOnly` oder `TrustAll`
dafür, welche Schlüssel zählen, jeweils wahlweise mit dem Präfix `Package` oder `Database`. Arch
setzt `SigLevel = Required DatabaseOptional`: Jedes Paket muss von einem vertrauenswürdigen
Schlüssel signiert sein, die Datenbanken müssen es nicht (Arch signiert sie nicht).
`LocalFileSigLevel = Optional` gilt für `pacman -U` mit einer Datei. `pacman-conf` gibt die
wirksamen Werte aus:

```bash
ansible arch -m ansible.builtin.command -a "pacman-conf SigLevel"
ansible arch -m ansible.builtin.command -a "pacman-conf -r core SigLevel"
```

Der erste Befehl gibt `PackageRequired PackageTrustedOnly DatabaseOptional DatabaseTrustedOnly`
aus, der zweite nichts: `-r` zeigt nur, was ein Repository-Abschnitt selbst setzt, und `[core]`
setzt nichts, also gilt der globale Wert. Ein Repository-Abschnitt mit eigenem `SigLevel = Optional
TrustAll` senkt die Prüfung nur für dieses Repository. Die Schlüssel liegen in einem
Schlüsselbund unter `/etc/pacman.d/gnupg` (183 öffentliche Schlüssel im Lab-Image, aus
`archlinux-keyring`), den alle Repositories teilen. Weil die Datenbanken nicht signiert sind,
beweist `pacman -Sy` nichts über Signaturen - und `-Sy` ohne `-u` ist der klassische Weg zu einem
Teil-Upgrade.

### apk: signierte Indizes und eine globale Optionsdatei

apk prüft die Signatur jedes Repository-Index gegen die Schlüssel in `/etc/apk/keys` (drei im
Lab-Image, aus dem Paket `alpine-keys`) und die jedes Pakets. apk-tools 3 liest außerdem globale
Optionen aus `/etc/apk/config`, eine lange Option je Zeile - `allow-untrusted` dort akzeptiert
unsignierte Indizes und Pakete für jeden Befehl, nicht nur für ein einzelnes `apk add
--allow-untrusted`. Gelesen wird nur die erste vorhandene Datei von `/etc/apk/config` und
`/lib/apk/config` (apk(8)).

```bash
ansible alpine -m ansible.builtin.command -a "apk --version"
ansible alpine -m ansible.builtin.shell -a "ls /etc/apk/keys; cat /etc/apk/repositories"
```

Ein Repository, dessen Index die Prüfung nicht besteht, hält apk nicht auf: Gemessen mit einem
unsignierten lokalen Index gab `apk update` `WARNING: opening ...: UNTRUSTED signature` aus, ließ
dieses Repository weg und endete mit 0. Lies die Ausgabe, nicht nur den Exit-Code.

### Eine Frage, sechs Antworten: Daten je `pkg_mgr`

L04 hat Plattformdaten nach `os_family` gewählt. Für Signaturen ist der bessere Schlüssel der Fakt
`pkg_mgr`, denn der Manager bestimmt die Dateien und Befehle - und fedora (`dnf5`) unterscheidet
sich von rocky und alma (`dnf`), obwohl alle drei `RedHat` sind:

```bash
ansible targets -m ansible.builtin.setup -a 'gather_subset=min filter=ansible_pkg_mgr'
```

Er gibt `apt` für debian und ubuntu aus, `dnf` für rocky und alma, `dnf5` für fedora, `zypper`,
`pacman` und `apk` für die anderen. Ein Dict mit diesem Wert als Schlüssel, abgesichert durch ein
`assert`, funktioniert wie in L15: Ein neuer Manager stoppt das Play, statt jeden Block zu
überspringen.

### Listen vergleichen und INI-Abschnitte bearbeiten

Zwei Helfer erledigen hier den größten Teil des Aufräumens. Die Listenfilter `difference`, `union`
und `intersect` vergleichen Listen, etwa die Pfade, die zwei `find`-Läufe geliefert haben. Und
`community.general.ini_file` bearbeitet eine Option, oder einen ganzen Abschnitt, einer INI-Datei -
das Format von `dnf.conf`, `zypp.conf`, den `.repo`-Dateien und `pacman.conf`. Eine kleine Demo auf
dem Control Node:

```yaml
- name: List filters and INI sections
  hosts: localhost
  gather_facts: false
  vars:
    all_files: [/tmp/a.conf, /tmp/b.conf, /tmp/c.conf]
    signed_files: [/tmp/a.conf, /tmp/c.conf]
  tasks:
    - name: In the first list, not in the second
      ansible.builtin.debug:
        msg: "{{ all_files | difference(signed_files) }}"

    - name: A scratch INI file with a section
      community.general.ini_file:
        path: /tmp/l16-demo.ini
        section: demo
        option: enabled
        value: "1"
        no_extra_spaces: true
        mode: "0644"

    - name: The whole section goes
      community.general.ini_file:
        path: /tmp/l16-demo.ini
        section: demo
        state: absent
        create: false
```

Der erste Task gibt eine Liste aus, die nur `/tmp/b.conf` enthält. Der zweite schreibt `[demo]` und
`enabled=1` (ohne die Leerzeichen um `=`, im Stil von `dnf.conf`), der dritte entfernt die
Überschrift und jede Zeile bis zur nächsten Überschrift. Die Demo ist absichtlich nicht idempotent:
Jeder Lauf legt den Abschnitt an und entfernt ihn wieder. Mit nur `section:` und `state: absent`
entfernt `ini_file` den ganzen Abschnitt; mit zusätzlich `option:` nur diese Zeile. `create: false`
verhindert, dass es eine fehlende Datei anlegt.

Ein Detail von `ansible.builtin.find` zählt für solche Listen: `contains:` wird mit `re.match` gegen
jede Zeile verglichen, also ab dem Zeilenanfang. Ein Muster, das mitten in einer Zeile stehen kann,
braucht ein `.*` am Anfang.

## CIS-Hintergrund

Abschnitt 1.2 der Benchmarks behandelt die Paketverwaltung ([der
Kontrollkatalog](../../cis-catalogue/controls.yml): 1.2, Level 1). In eigenen Worten verlangen die
Empfehlungen: die Signaturschlüssel des Paketmanagers eingerichtet und bekannt; die
Signaturprüfung global eingeschaltet und für kein Repository abgeschaltet; nur Repositories
eingerichtet, denen die Organisation vertraut; und Updates eingespielt. Die Punkte zu Schlüsseln
und Repositories sind oft *manuell*: Ein Werkzeug kann Schlüssel und Quellen auflisten, aber nur du
weißt, welche dorthin gehören. Die automatisierten Punkte lesen die Konfigurationsdateien - ein
Audit durchsucht typischerweise `dnf.conf` und jede `.repo`-Datei nach `gpgcheck`, also kann ein
Standardwert, der an ist, aber nirgends steht, trotzdem durchfallen. Manche Benchmarks führen die
Metadatenprüfung (`repo_gpgcheck`) getrennt.

Die Bedrohung ist ein gefälschtes Paket: von einem kompromittierten Mirror, einem Man-in-the-Middle
auf einem Mirror mit einfachem HTTP oder einem "internen Mirror", den jemand in Eile hinzugefügt
hat. Eine Signaturprüfung schließt alle drei, aber nur für Repositories, deren Schlüssel stimmt; ein
Schlüssel, dem für jede Quelle vertraut wird, öffnet die Tür wieder. Die Abwägungen sind klein -
ein signiertes internes Repository kostet einen Schlüssel und einen Signaturschritt in seinem
Build -, deshalb verlangen die Benchmarks die Prüfung ohne Ausnahmen.

## Plattformunterschiede

| os_family | Hosts | `pkg_mgr` | Globaler Schalter | Schalter je Repository | Schlüssel | Wirksame Werte |
|---|---|---|---|---|---|---|
| Debian | debian, ubuntu | `apt` | `Acquire::Allow...`, `APT::Get::AllowUnauthenticated` in `apt.conf.d` | `trusted=yes`, `allow-insecure=yes` | Datei aus `Signed-By`; sonst `trusted.gpg.d` (9 / 2 Schlüssel) | `apt-config dump`; die Quellen |
| RedHat | rocky, alma / fedora | `dnf` / `dnf5` | `gpgcheck` in `[main]` (fedora: keine Zeile, standardmäßig an) | `gpgcheck=` je Repository | `gpgkey=`, rpm-Datenbank (importiert) | dnf-Python-API / `dnf5 --dump-*-config` |
| Suse | opensuse | `zypper` | `gpgcheck` in `[main]` von `zypp.conf` (nicht gesetzt) | `gpgcheck=` je Repository (nicht gesetzt) | `gpgkey=`, rpm-Datenbank (6 Schlüssel) | `zypper --xmlout lr` |
| Alpine | alpine | `apk` | `allow-untrusted` in `/etc/apk/config` | - | `/etc/apk/keys` (3, `alpine-keys`) | die Dateien; Ausgabe von `apk update` |
| Archlinux | arch | `pacman` | `SigLevel` in `[options]` | `SigLevel` je Abschnitt | `/etc/pacman.d/gnupg` (183 Schlüssel) | `pacman-conf` |

Gemessene Versionen: apt 3.0.4 (debian 13) und 3.2.1 (ubuntu 26.04); dnf 4.20 mit rpm 4.19 (rocky,
alma 10.3); dnf5 5.4.6 mit rpm 6.0.2 (fedora 44); zypper 1.14.101 mit rpm 4.20 (Leap 16.0);
pacman 7.1; apk-tools 3.0.9 (Alpine 3.24).

### In den Lab-Containern

Signaturen verhalten sich wie auf einer virtuellen Maschine; nichts hier hängt vom Kernel des
Hosts ab. Jedes Image kommt mit einem "internen Mirror", dem ein früherer Admin ohne Schlüssel
vertraut hat - ein lokales, leeres Repository in `/opt/lab/legacy-repo`, damit sein Entfernen
nichts bricht und nie etwas daraus installiert werden kann: eine apt-Quelle mit `trusted=yes`, ein
deaktiviertes dnf- und zypper-Repository mit `gpgcheck=0` und ohne Schlüssel, ein pacman-Abschnitt
mit `SigLevel = Optional TrustAll` und eine apk-Repository-Zeile samt `allow-untrusted` in
`/etc/apk/config`. `./lab.sh reset` bringt ihn zurück. Eine Aktualisierung braucht das Netz, wie
jede Paketinstallation im Lab.

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| `apt-get update` ist sauber, trotzdem ist eine Quelle ungeprüft | `trusted=yes` schaltet die Prüfung still ab | die Quellen lesen, nicht die Ausgabe der Aktualisierung |
| `gpgcheck=0` in `[main]`, jedes Repository prüft trotzdem (oder umgekehrt) | der Wert im Repository gewinnt | beide Ebenen prüfen und setzen |
| Ein Audit scheitert auf fedora, die Prüfung ist an | der Standardwert braucht keine Zeile; das Audit liest die Datei | `gpgcheck=1` in `[main]` schreiben |
| zypper zeigt nach einer Aktualisierung `pkg_gpgcheck="0"` | nicht gesetzt, folgt es der Metadatensignatur | zypper nach `gpgcheck` und `repo_gpgcheck` beurteilen |
| `pacman-conf -r core SigLevel` gibt nichts aus | `-r` zeigt nur den eigenen Wert des Abschnitts | auf das globale `SigLevel` zurückfallen |
| `apk update` endet mit 0 und `UNTRUSTED signature` | apk lässt das Repository weg und macht weiter | die Ausgabe ansehen |
| `find` mit `contains: signed-by=` findet nichts | `re.match` ab dem Zeilenanfang | `.*signed-by=` |
| Ein Fremdschlüssel in `trusted.gpg.d` | ihm wird für jede Quelle vertraut | `/etc/apt/keyrings/` + `Signed-By` |

## Übungen

| Übung | Was diese Lektion vorbereitet |
|---|---|
| [4.10](../../exercises/stage4-advanced/4.10-package-signatures/README.de.md) | die Schalter und Schlüsselorte der fünf Manager, die wirksamen Werte, Daten je `pkg_mgr`, Listenfilter, `ini_file`-Abschnitte |

Starte eine Übung mit `lab start <id>`; `lab show <id>` gibt ihre README aus.

## Selbstkontrolle

1. Eine Quellzeile lautet `deb [trusted=yes] http://mirror.example/debian trixie main`, und
   `apt-get update` läuft ohne eine einzige Warnung. Wird das Repository geprüft?

   <details><summary>Antwort</summary>

   Nein. `trusted=yes` sagt apt, die Quelle ohne gültige Signatur anzunehmen, und apt warnt nicht
   davor; nur eine Zeile `Ign: ... Release.gpg` deutet es an. Ein globales
   `Acquire::AllowInsecureRepositories` würde wenigstens eine `W:`-Zeile ausgeben. Wissen kannst du
   es nur, wenn du die Quellen liest (oder `apt-config dump` für die globalen Optionen), nicht aus
   der Ausgabe der Aktualisierung.

   </details>

2. Warum ist eine Quelle mit `Signed-By` sicherer als dieselbe Quelle ohne, auch wenn beide mit dem
   richtigen Schlüssel signiert sind?

   <details><summary>Antwort</summary>

   Ohne `Signed-By` akzeptiert apt eine Signatur mit jedem Schlüssel in `/etc/apt/trusted.gpg.d/`.
   Wer den privaten Schlüssel irgendeines davon hat, kann dann auch für diese Quelle Pakete
   signieren. Mit `Signed-By` zählt für die Quelle nur der genannte Schlüssel, und ein
   Fremdschlüssel, der für ein Repository hinzugefügt wurde, kann nicht für die anderen signieren.

   </details>

3. Auf rocky sagt `[main]` von `dnf.conf` `gpgcheck=1`. Eine Repository-Datei sagt `gpgcheck=0`.
   Welcher Wert gilt für dieses Repository, und wie findest du es heraus, ohne die Dateien zu lesen?

   <details><summary>Antwort</summary>

   `gpgcheck=0`: Der Wert im Repository gewinnt gegen `[main]`. dnf sagt es dir selbst - mit seiner
   Python-API bei dnf 4 (das Attribut `gpgcheck` des Repositorys) oder mit `dnf5
   --dump-repo-config` bei dnf5. Deshalb muss ein Härtungs-Play beide Ebenen ansehen.

   </details>

4. Auf opensuse meldet ein Skript direkt nach einem `zypper refresh` "Paketsignaturprüfung aus" für
   jedes Repository. Was ist los?

   <details><summary>Antwort</summary>

   Das Skript liest `pkg_gpgcheck`. Ist es nicht gesetzt, prüft libzypp Paketsignaturen nur,
   solange die Metadaten des Repositorys nicht gültig signiert sind; nach einer Aktualisierung sind
   die Metadaten signiert und tragen die Prüfsummen der Pakete, also steht `pkg_gpgcheck` auf `0`.
   Abgeschaltet ist nichts. Die Werte, die sagen, ob zypper prüft, sind `gpgcheck` und
   `repo_gpgcheck`.

   </details>

5. Warum hilft es, die Daten eines Signatur-Plays nach `pkg_mgr` und nicht nach `os_family` zu
   wählen?

   <details><summary>Antwort</summary>

   Der Manager bestimmt die Dateien, die Namen der Optionen und die Befehle, die die wirksamen Werte
   zeigen. fedora ist `RedHat` wie rocky und alma, nutzt aber dnf5, dessen Dump-Optionen und
   Python-Bibliothek sich von dnf 4 unterscheiden. Nach `pkg_mgr` gewählt, passt jeder Wert des
   Dicts zu einem Werkzeug, und ein `assert` stoppt einen Host mit einem Manager, den die Daten nicht
   kennen.

   </details>

## Weiterführendes

- [sources.list(5)](https://manpages.debian.org/trixie/apt/sources.list.5.en.html) - einzeiliges und deb822-Format, `Signed-By`, `Trusted`
- [apt-secure(8)](https://manpages.debian.org/trixie/apt/apt-secure.8.en.html) - wie apt ein Repository prüft und was die `Allow...`-Optionen tun
- [dnf.conf (dnf 4)](https://dnf.readthedocs.io/en/latest/conf_ref.html) - `gpgcheck`, `repo_gpgcheck`, `localpkg_gpgcheck`, `gpgkey`, `skip_if_unavailable`
- [dnf5.conf(5)](https://dnf5.readthedocs.io/en/latest/dnf5.conf.5.html) - `pkg_gpgcheck` und sein Alias `gpgcheck`
- [zypp.conf(5) (libzypp)](https://github.com/openSUSE/libzypp/blob/master/zypp/doc/zypp.conf.5.txt) - `gpgcheck`, `repo_gpgcheck`, `pkg_gpgcheck` und wie die nicht gesetzten Werte `gpgcheck` folgen
- [pacman.conf(5)](https://man.archlinux.org/man/pacman.conf.5) - `SigLevel`, `LocalFileSigLevel`, Repository-Abschnitte
- [Pacman/Package signing](https://wiki.archlinux.org/title/Pacman/Package_signing) - der Schlüsselbund und `pacman-key`
- [apk(8)](https://man.archlinux.org/man/apk.8) - `--allow-untrusted`, `/etc/apk/config`, die Schlüsselverzeichnisse
- [`ansible.builtin.deb822_repository`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/deb822_repository_module.html) - eine Quelle mit `signed_by`
- [`community.general.ini_file`](https://docs.ansible.com/projects/ansible/latest/collections/community/general/ini_file_module.html) - Optionen und Abschnitte, `state: absent`
- [Filters: set theory](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_filters.html#selecting-from-sets-or-lists-set-theory) - `difference`, `union`, `intersect`
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: `gpgcheck`, keyring, `pkg_gpgcheck`, `SigLevel`,
  `Signed-By`, `trusted=yes`
