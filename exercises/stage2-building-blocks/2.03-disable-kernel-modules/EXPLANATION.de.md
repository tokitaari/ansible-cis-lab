# 2.03 - Unnötige Kernelmodule deaktivieren: Erklärung

### Was der Check prüft
`lab check 2.03` führt `check.yml` auf `targets` aus: Für jedes der sechs Level-1-Module (mit
`-e cis_level=2` auch für die sechs Level-2-Module) liest er `/etc/modprobe.d/00-cis-<modul>.conf`
und prüft eine Zeile `install <modul> /bin/false` (oder `/usr/bin/false`) und eine Zeile
`blacklist <modul>`. Auf den Hosts, deren `modprobe -V` kmod nennt (alle außer alpine), fragt er
danach `modprobe --show-depends <modul>`, welche Regel **gilt**, und erwartet als Antwort deine
`install`-Zeile. Danach läuft dein Playbook noch einmal mit `--check` und muss `changed=0` melden.

- Die Dateinamen sind fest, in der Schreibweise der README: `00-cis-usb-storage.conf`, nicht
  `00-cis-usb_storage.conf` oder `cis-usb-storage.conf`.
- Nach `/bin/false` darf nichts mehr stehen: Ein `# Kommentar` am Zeilenende fällt durch, `/bin/true`
  (aus älteren Benchmark-Versionen) ebenfalls.
- Eigentümer, Modus und zusätzliche Zeilen werden nicht geprüft.
- Eine Regel, die eine früher sortierte Datei überstimmt, fällt auf den kmod-Hosts durch (gemessen
  auf opensuse mit einer zusätzlichen `00-aaa-cramfs.conf`). Auf alpine zählen nur die Dateien
  (BusyBox ignoriert `install`).
- Übrig gebliebene Dateien mit anderen Namen stören nicht, solange `00-cis-...` zuerst sortiert
  (gemessen mit den alten Namen `cis-<modul>.conf` neben den neuen).

### So funktioniert es

#### Eine Datei pro Modul
`copy` mit `loop` schreibt pro Listenelement eine Datei; `content: |` liefert die zwei Zeilen und
einen abschließenden Zeilenumbruch. Gemessen: Die Musterlösung meldet im ersten Lauf `changed=1`
pro Host (das `copy` mit Schleife; `/etc/modprobe.d` gibt es auf allen acht Hosts, der
Verzeichnis-Task ist also `ok`) und im zweiten `changed=0`; der Entlade-Task wird übersprungen
(`lab_in_container`). Eine Datei pro Modul macht eine Ausnahme billig - eine Datei löschen - und
hält Diffs lesbar.

#### `install` und `blacklist`
`install <modul> /bin/false` ersetzt das Laden durch einen Befehl, der scheitert, und zwar bei
jedem `modprobe` dieses Namens. `blacklist` verhindert nur das Laden über die Aliase des Moduls;
ein einfaches `modprobe <name>` ignoriert es, außer mit `-b`. Lektion L05 zeigt beides mit
`modprobe -n -v`. Gemessen auf allen sieben kmod-Hosts nach der Lösung (Level 2 eingeschlossen):
`modprobe -n -v` und `modprobe --show-depends` geben für alle zwölf Module `install /bin/false` aus.

#### Bindestrich und Unterstrich
Das Kernelmodul heißt `usb_storage`. kmod behandelt `-` und `_` als dasselbe Zeichen,
`install usb-storage /bin/false` trifft es also: `modprobe -n -v usb_storage` und `usb-storage`
zeigen beide die Regel (gemessen auf allen sieben kmod-Hosts), und `modprobe -c` führt sie als
`usb_storage` (Test in der Session).

#### Die erste `install`-Zeile gewinnt
kmod führt `/etc/modprobe.d`, `/run/modprobe.d` und `/usr/lib/modprobe.d` zusammen und liest die
Dateien in der Byte-Reihenfolge ihrer **Namen**; eine Datei in `/etc` ersetzt eine gleichnamige in
`/usr/lib`. Bei `install` zählt die erste gefundene Zeile. openSUSE liefert
`60-blacklist_fs-<fs>.conf` für 29 Dateisysteme mit, fünf davon aus der Level-1-Liste, jeweils mit
`blacklist <fs>` und
`install <fs> /usr/lib/module-init-tools/unblacklist <fs>; /sbin/modprobe --ignore-install <fs>`.
Diese Regel sperrt nicht: Ohne Terminal gestartet, wie durch den Kernel, endet `unblacklist`
sofort (suse-module-tools 16.0.65 auf dem Target), und `modprobe --ignore-install` lädt das Modul.
`00-cis-<modul>.conf` sortiert vor `60-...` und gewinnt; der alte Name dieser Übung,
`cis-<modul>.conf`, sortierte danach und verlor (gemessen). Kein anderes Target hat eine
`install`-Zeile für eines der zwölf Module (frische Hosts).

#### Geladene Module: Der Probelauf schweigt
Hat der Kernel das Modul schon, bricht `modprobe -n -v` ab, bevor es `install` ansieht, gibt nichts
aus und endet mit 0 - und der Kernel im Lab ist der deines PCs. Gemessen mit `ac`, im WSL2-Kernel
des Hosts geladen, und einem vorübergehenden `install ac /bin/false`: `-n -v` gab auf allen sieben
kmod-Hosts nichts aus, `modprobe --show-depends ac` gab `install /bin/false` aus. `--show-depends`
ignoriert, ob ein Modul geladen ist, deshalb nutzt der Check es. Keines der zwölf Module war auf
dem Messhost geladen.

#### Alpine: BusyBox ignoriert `install`
`/sbin/modprobe` ist auf alpine BusyBox 1.37.0. Sein Konfigurationsparser kennt nur `alias`,
`options`, `include` und `blacklist` (BusyBox-Quelltext; ein Test mit BusyBox 1.36.1 bestätigt
es): Die `install`-Zeile wird ignoriert, ein einfaches `modprobe cramfs` würde versuchen, das
Modul zu laden, und `blacklist` greift für den einfachen Namen nur mit `-b`. BusyBox hat außerdem
kein `-n`, es gibt also keinen Probelauf, mit dem du die Regel prüfen könntest; der Check
überspringt diesen Teil dort (`modprobe -V`: `unrecognized option`).

#### Was der Container nicht zeigen kann
Der Kernel im Lab ist der des Hosts (bei der Messung ein WSL2-Kernel), und die Targets haben kein
Modulverzeichnis: Vor der Regel endet `modprobe -n -v cramfs` mit `Module cramfs not found in
directory /lib/modules/...`. Braucht der Kernel selbst ein Modul - beim Einhängen eines
Dateisystemtyps, beim Öffnen eines Sockets mit einem ungewöhnlichen Protokoll -, startet er
`/sbin/modprobe` in den Namespaces des Hosts, er liest also das `modprobe.d` des **Hosts**, nie
das des Containers. Im Lab sind die sechs Dateien Konfiguration, die ein echter Host nutzen würde.
Deshalb läuft der Entlade-Task der Lösung (`community.general.modprobe`, `state: absent`) nur mit
`lab_in_container: false`.

#### Level 2 (Bonus)
`squashfs` ist Level 2, weil Snaps und viele Live- und Installer-Images es brauchen. `dccp`,
`tipc`, `rds` und `sctp` hatten Schwachstellen, die unprivilegierte Benutzer erreichen konnten,
aber manche Telekommunikationssoftware braucht SCTP. Dafür gibt es die Aufteilung in Profile.

### Hinweise je Familie
| os_family | `/sbin/modprobe` | `/bin/false` zeigt auf | Vendor-`install`-Zeilen für die zwölf Module | `modprobe -n -v cramfs` nach der Lösung |
|---|---|---|---|---|
| Debian | kmod 34.2 | `/usr/bin/false`; ubuntu: Rust-Coreutils (`/usr/lib/cargo/bin/coreutils/false`) | keine | `install /bin/false` |
| RedHat | kmod 31 (rocky, alma), 34.2 (fedora) | `/usr/bin/false` | keine | `install /bin/false` |
| Suse | kmod 34.2 | `/usr/bin/false` | `60-blacklist_fs-*.conf` für fünf davon (nach `00-cis-`) | `install /bin/false` |
| Alpine | BusyBox 1.37.0 | BusyBox | keine (BusyBox ignoriert `install` ohnehin) | kein Probelauf in BusyBox |
| Archlinux | kmod 34.3 | `/usr/bin/false` | keine | `install /bin/false` |

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Behebung |
|---|---|---|
| Der Check scheitert, die Datei sieht richtig aus | Kommentar am Zeilenende, `/bin/true`, `00-cis-usb_storage.conf` oder der alte Name `cis-<modul>.conf` | genau die zwei Zeilen, die Dateinamen der README |
| `kmod uses '...' for <modul>` | eine früher sortierte Datei in `/etc`, `/run` oder `/usr/lib/modprobe.d` | mit `grep -r '^install <modul>'` in den drei Verzeichnissen finden |
| `modprobe -n -v <modul>` gibt nichts aus, Rückgabewert 0 | der (Host-)Kernel hat das Modul schon geladen | `modprobe --show-depends <modul>` zeigt die Regel trotzdem |
| `Module cramfs not found in directory /lib/modules/...` | kein Modulverzeichnis im Container, noch keine Regel | erwartet; nach der Regel zeigt der Probelauf `install ...` |
| `Error running install command '/bin/false'` | die Regel wirkt; du hast ein echtes `modprobe` ausgeführt | die Regel mit `modprobe -n -v` lesen, nicht zum Testen laden |
| `modprobe -n` scheitert auf alpine | BusyBox hat kein `-n` | die Datei lesen; BusyBox setzt `install` ohnehin nicht durch |
| Ein Modul wurde auf deinem PC entladen | `modprobe -r` oder `rmmod` in einem Target | nie im Lab; mit `lab_in_container` absichern |

### Praxis-Hinweise
- Prüfe, was gilt, nicht was du geschrieben hast: `modprobe --show-depends <modul>` auf jeder
  Plattform mit kmod (`-n -v` schweigt bei einem geladenen Modul). Ein Scanner, der nur deine Datei
  durchsucht, übersieht eine frühere Vendor-Regel, und ein Paket-Update kann jederzeit eine
  hinzufügen.
- Eine Regel stoppt neues Laden. Auf einem echten Host lade geladene Module auch aus und baue die
  initramfs neu, die eine eigene Kopie von `modprobe.d` enthält (L05).
- Prüfe, welches `modprobe` deine Hosts nutzen (`readlink -f /sbin/modprobe`), bevor du dich auf
  `install` verlässt.

### Weiterführend
- Lektion [L05 - Kernel-Härtung](../../../docs/lessons/L05-kernel-modules-and-sysctl.de.md): `install`, `blacklist`, Probeläufe, Container-Grenzen.
- Übung [2.04 - Kernelparameter: Netzwerk-Härtung per sysctl](../2.04-sysctl-network/README.de.md)
- Übung [3.01 - Alles in eine Rolle überführen](../../stage3-intermediate/3.01-build-the-cis-role/README.de.md)
- [Container-Grenzen](../../../docs/CONTAINER_LIMITS.de.md)
- [`modprobe.d(5)`](https://man.archlinux.org/man/modprobe.d.5) - `install`, `blacklist` und die anderen Schlüsselwörter

## Musterlösung

Anzeigen mit `lab solution 2.03`, anwenden mit `lab solve 2.03`.
