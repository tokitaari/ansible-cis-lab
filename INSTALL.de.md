# Installation

*[English](INSTALL.md)*

Das Lab braucht auf deinem Rechner **nichts außer Docker, Compose v2 und Git**. Control Node und
die acht Targets sind Container; Ansible, `ansible-lint` und die `lab`-CLI leben im Control
Node. Diese Anleitung behandelt zuerst die gemeinsamen Schritte, dann Docker unter Windows, macOS
und Linux und was an Docker auf jedem dieser Systeme besonders ist.

Kurzfassung: [Schnellstart in der README](README.de.md#schnellstart). Lies weiter, wenn Docker noch
nicht installiert ist, wenn etwas scheitert oder wenn du wissen willst, warum das Lab verlangt, was es verlangt.

## Was du brauchst

| | |
|---|---|
| Docker | Docker Engine 24+ **oder** Docker Desktop, mit dem Compose-**v2**-Plugin (`docker compose`, nicht `docker-compose`); `compose.yaml` nutzt den Service-Schlüssel `cgroup`, der Compose 2.15 oder neuer braucht |
| Git | zum Klonen des Labs (ein heruntergeladenes ZIP geht auch, lässt sich aber nicht mit `git pull` aktualisieren) |
| CPU | x86-64 ist die getestete Plattform. Arm64 (z. B. Apple Silicon): siehe [macOS](#macos); das Target `arch` hat kein offizielles arm64-Image |
| RAM und Platte | 4 GB RAM, die **Docker zur Verfügung stehen**, und etwa 8 GB freier Platz wie in der README; unter Windows und macOS ist das der Anteil, den du der Docker-VM gibst, nicht das, was der Rechner hat |
| Netzwerk | Internetzugang für den ersten Build (Basis-Images, Distributionspakete, `pip`, GitHub); das Lab veröffentlicht **keine Ports** auf deinem Host |
| Rechte | Erlaubnis, mit dem Docker-Daemon zu sprechen (Linux: Gruppe `docker`), siehe [Linux](#linux) |
| Ein Rechner, auf dem du spielen darfst | die Targets laufen `privileged` und teilen sich den Kernel des Docker-Hosts - lies [`docs/CONTAINER_LIMITS.de.md`](docs/CONTAINER_LIMITS.de.md) und nimm keinen Produktivhost |

Nicht unterstützt: **Rootless Docker** (privilegierte Targets bekommen nur die Rechte deines
User-Namespace, und cgroup-Limits brauchen zusätzliche Einrichtung) und **Podman** (`lab.sh` ruft `docker compose` auf,
und das Lab wurde nicht mit Podman ausprobiert). Beides ist ungetestet, nicht verboten - rechne damit,
die Fehlersuche selbst zu übernehmen.

**Vom Maintainer getestet:** Debian (nativer Host) mit Docker Engine und Windows mit WSL2 (Ubuntu 26.04
mit Docker Engine). Alles andere
unten ist nach der Dokumentation der Hersteller geschrieben und mit diesem Lab **nicht getestet**; die
Abschnitte sagen es. Rückmeldungen und Korrekturen sind willkommen.

## Auf jeder Plattform gleich

1. **Docker installieren** (Abschnitte unten) und prüfen:

   ```bash
   docker version
   docker compose version
   docker run --rm hello-world
   ```
   `docker compose version` muss Compose 2.15 oder neuer ausgeben. `docker version` muss einen
   *Client*- **und** einen *Server*-Teil zeigen - fehlt der Server-Teil, läuft der Daemon nicht.

2. **Das Lab klonen** - unter Windows im Linux-Dateisystem von WSL2, siehe [Windows](#windows):

   ```bash
   git clone https://github.com/tokitaari/ansible-cis-lab
   cd ansible-cis-lab
   ```

3. **Bauen und starten** (beim ersten Lauf werden die Basis-Images geladen und neun Images
   gebaut - einige Minuten, je nach Verbindung):

   ```bash
   ./lab.sh up
   ```
   Windows PowerShell: `.\lab.ps1 up`. Der Wrapper wartet, bis alle Targets SSH annehmen, und gibt
   dann den Lab-Status aus.

4. **Den Control Node öffnen** und loslegen:

   ```bash
   ./lab.sh shell
   lab placement
   ```
   Im Control Node ist `lab` die Lab-CLI; `lab list` zeigt alle Aufgaben.

5. **Das Ergebnis ansehen**, vom Host aus:

   ```bash
   ./lab.sh ps
   ```
   Neun Container (`control` sowie `debian`, `ubuntu`, `rocky`, `alma`, `fedora`, `opensuse`,
   `arch`, `alpine`) müssen *running* sein, `control` *healthy*.

Der Wrapper setzt drei Dinge für dich: `LAB_UID` und `LAB_GID` (dein Benutzer, damit die Dateien in `./work` dir gehören)
und `LAB_TZ` (deine Zeitzone, für den Control Node). Deshalb solltest du das Lab mit
`./lab.sh` starten und nicht mit einem nackten `docker compose up`.

## Windows

Container brauchen einen Linux-Kernel, also betreibt Docker unter Windows eine Linux-VM: WSL2 (Standard) oder Hyper-V.
Wähle eine von drei Routen.

| Route | Was es ist | Status |
|---|---|---|
| **A. Docker Engine in WSL2, ohne Docker Desktop** | die Linux-Schritte in einer WSL-Distribution mit systemd (Ubuntu) | empfohlen, getestet (Ubuntu 26.04) |
| B. Docker Desktop + WSL2 | Docker Desktop mit WSL-Integration, `./lab.sh` in einem WSL-Terminal | nicht getestet |
| C. Docker Desktop + PowerShell, Lab auf einem Windows-Laufwerk | `.\lab.ps1` | nicht getestet, langsamer, nicht empfohlen |

### Route A: Docker Engine in WSL2

1. **WSL2 aktivieren.** Braucht im BIOS/UEFI eingeschaltete Hardware-Virtualisierung. In einer
   PowerShell mit Administratorrechten:

   ```powershell
   wsl --install
   wsl --update
   wsl --version
   ```
   `wsl --install` installiert eine Standard-Linux-Distribution (Ubuntu); öffne sie einmal, um
   deinen Linux-Benutzer anzulegen.

2. **Prüfen, dass systemd läuft** (Dockers Dienst braucht es). Aktuelles Ubuntu unter WSL startet es
   standardmäßig:

   ```bash
   ps -p 1 -o comm=
   ```
   Die Antwort muss `systemd` lauten. Falls nicht (ältere oder andere Distributionen), aktiviere es - WSL unterstützt es ab
   Version 0.67.6 - in `/etc/wsl.conf` und starte WSL in der PowerShell mit `wsl --shutdown` neu:

   ```ini
   [boot]
   systemd=true
   ```

3. **Docker Engine installieren**, in der Distribution, mit den Debian/Ubuntu-Schritten aus [Linux](#linux),
   einschließlich der Gruppe `docker`. Schließe das Terminal und öffne es neu, prüfe dann
   `docker run --rm hello-world`. Es gibt kein Docker Desktop, keinen WSL-Integrationsschalter und keine
   Lizenzfrage zu Docker Desktop; Updates und die Gruppe `docker` verwaltest du selbst.

4. **Im Linux-Dateisystem klonen** (`~`, z. B. `/home/du/ansible-cis-lab`) und die Schritte aus
   [Auf jeder Plattform gleich](#auf-jeder-plattform-gleich) **im WSL-Terminal** ausführen:

   ```bash
   cd ~
   git clone https://github.com/tokitaari/ansible-cis-lab
   cd ansible-cis-lab
   ./lab.sh up
   ```
   Nicht unter `/mnt/c/...`: Das Windows-Laufwerk ist für alle beschreibbar eingehängt (Ansible ignoriert dort
   `ansible.cfg`, siehe [TROUBLESHOOTING](docs/TROUBLESHOOTING.de.md)), und der Dateizugriff über
   die Grenze hinweg ist langsam. Bearbeite deine Lösungen von Windows aus über `\\wsl$\<Distribution>\home\du\ansible-cis-lab\work`
   oder mit der *WSL*-Erweiterung von VS Code.

### Route B: Docker Desktop mit dem WSL2-Backend

1. **WSL2 aktivieren** wie in Schritt 1 von Route A. Nach Dockers Anforderungen für das WSL2-Backend
   brauchst du einen 64-Bit-Prozessor mit SLAT und 8 GB System-RAM sowie WSL **2.1.5 oder neuer**.

2. **Docker Desktop installieren** von [docker.com](https://www.docker.com/products/docker-desktop/)
   und auf der Konfigurationsseite *Use WSL 2 instead of Hyper-V* wählen. Installationen pro Benutzer
   (`"Docker Desktop Installer.exe" install --user`) unterstützen nur das WSL2-Backend und brauchen für Updates keine
   Administratorrechte. Unter *Settings > General* muss *Use the WSL 2 based engine* an sein, und Docker muss
   **Linux-Container** ausführen (Standard mit WSL2).

3. **Docker für deine Distribution einschalten:** *Settings > Resources > WSL integration*, deine
   Distribution aktivieren, *Apply*. Im WSL-Terminal muss `docker version` jetzt einen Server zeigen.

4. **Im WSL-Dateisystem klonen und starten**, genau wie in Schritt 4 von Route A.

### Route C: PowerShell mit dem Lab auf einem Windows-Laufwerk

`.\lab.ps1` bietet dieselben Befehle wie `./lab.sh`. Das Lab-Verzeichnis ist dann ein Windows-Ordner,
den Docker in die Linux-VM einhängt: Der Dateizugriff ist langsamer und Linux-Rechte werden
nachgebildet (`ansible.cfg` wird ignoriert, der Control Node setzt `ANSIBLE_CONFIG` selbst). Achte
auf die Zeilenenden (unten) und rechne damit, dass `LAB_UID` und `LAB_GID` auf `1000` stehen.

### Windows-Details

- **Zeilenenden.** Skripte in `control/` und `targets/` laufen **in Linux-Containern direkt
  aus deinem Klon**. Mit dem Standard `core.autocrlf=true` von Git for Windows bekommt ein auf der Windows-Seite angelegter Klon
  CRLF-Zeilenenden, und die Skripte scheitern mit Fehlern, die `\r` oder `^M` erwähnen. Klone in WSL
  (Git dort lässt die Zeilenenden in Ruhe) oder setze die Option für Route C **vor** dem Klonen:

  ```powershell
  git config --global core.autocrlf input
  ```
- **Speicher und CPUs.** Die WSL2-VM nimmt sich, was sie braucht, bis zu einer Grenze (standardmäßig ein Anteil deines
  RAM). Begrenze oder erhöhe sie in `%UserProfile%\.wslconfig` (eine Windows-Datei, **nicht** `/etc/wsl.conf`):

  ```ini
  [wsl2]
  memory=8GB
  processors=4
  swap=2GB
  ```
  Wende sie mit `wsl --shutdown` an und öffne dann deine Distribution (und Docker Desktop, falls du es nutzt) neu. Das Lab braucht 4 GB für Docker
  (siehe oben); WSL2 selbst will 8 GB System-RAM.
- **Platte.** Dockers Daten liegen in einer virtuellen Platte (VHDX). In einem Target zeigt `df /` deren
  Nenngröße, nicht den freien Platz deines Windows-Laufwerks; ist dieses voll, scheitern Schreibzugriffe,
  obwohl `df` noch reichlich meldet (siehe [`docs/CONTAINER_LIMITS.de.md`](docs/CONTAINER_LIMITS.de.md)).
  Prüfe mit `docker system df` und in Windows.
- **Kernel.** Alle Targets teilen sich den Kernel der WSL2-VM, nicht den von Windows. Kernelweite Einstellungen
  bleiben in dieser VM.
- **Lizenz.** Docker Desktop in einem Unternehmen mit mehr als 250 Beschäftigten oder mehr als
  10 Mio. USD Jahresumsatz braucht ein kostenpflichtiges Abonnement; Docker Engine in WSL2 (Route A) nicht.
- **Hyper-V-Backend.** Docker Desktop kann seine Linux-Engine auch auf Hyper-V betreiben (Windows Pro,
  Enterprise oder Education). Nicht getestet; alles andere hier gilt unverändert.

## macOS

Docker Desktop ist der dokumentierte Weg, Docker auf einem Mac zu betreiben; alle Container laufen in seiner Linux-VM.
Mit diesem Lab nicht getestet - die Schritte folgen Dockers Dokumentation.

1. **Lade** den passenden Build von [docker.com](https://www.docker.com/products/docker-desktop/) herunter:
   *Apple silicon* (M-Serie) oder *Intel chip*. Docker unterstützt die aktuelle macOS-Version und die
   beiden davor.
2. **Installieren:** `Docker.dmg` öffnen, Docker nach *Programme* ziehen und starten. Auf Apple Silicon
   ist Rosetta 2 nicht mehr nötig, aber empfohlen:

   ```bash
   softwareupdate --install-rosetta
   ```
3. **Ressourcen geben:** *Settings > Resources* - mindestens 4 GB RAM, mehr ist besser.
4. Im *Terminal* die Schritte aus [Auf jeder Plattform gleich](#auf-jeder-plattform-gleich) ausführen.

macOS-Details:

- **Dateizugriff.** `./` wird als `/lab` in die VM eingehängt; der Dateizugriff läuft über die VM-Grenze
  und ist langsamer als unter Linux. Deine Lösungen in `./work` bleiben in jedem Mac-Editor bearbeitbar.
- **Apple Silicon.** Die Basis-Images werden für arm64 geladen. Das Arch-Linux-Image hat keinen offiziellen
  arm64-Build: siehe *Image pull fails on `archlinux:latest` for arm64* in
  [TROUBLESHOOTING](docs/TROUBLESHOOTING.de.md). Rocky und Alma 10 brauchen nur auf x86-64-Hosts eine x86-64-v3-CPU.
- **Kernel.** Alle Targets teilen sich den Kernel von Dockers Linux-VM, nicht den von macOS.
- **Lizenz.** Die für Windows genannten Docker-Desktop-Bedingungen gelten auch hier.
- **Alternativen.** Colima (`brew install colima docker docker-compose`, `colima start --cpus 4 --memory 6`)
  oder OrbStack (`brew install --cask orbstack`) liefern die Docker-Engine ohne Docker Desktop.
  Nicht getestet: Beide legen einen eigenen Docker-Kontext an (`docker context ls`), und du musst prüfen,
  dass die Targets als privilegierte systemd-Container laufen (`./lab.sh ps`, alle *running*).

## Linux

Unter Linux läuft Docker **nativ**: Die Targets teilen sich den Kernel deines eigenen Rechners, die
Regeln aus [`docs/CONTAINER_LIMITS.de.md`](docs/CONTAINER_LIMITS.de.md) betreffen also deine echte Maschine. Nimm eine
virtuelle Maschine, wenn du das Risiko lieber nicht eingehst.

Prüfe vorab, dass der Host **cgroup v2** nutzt (aktuelle Debian-, Ubuntu-, Fedora-, RHEL-
9+- und Arch-Versionen tun das standardmäßig); die systemd-Targets brauchen es:

```bash
stat -fc %T /sys/fs/cgroup
```
`cgroup2fs` ist, was du sehen willst.

Docker veröffentlicht Pakete für Debian, Ubuntu, Fedora, RHEL und CentOS. Arch Linux und openSUSE
nutzen eigene Distributionspakete. Entferne kollidierende Distributionspakete
(Debian/Ubuntu: `docker.io`, `docker-compose`, `podman-docker`, `containerd`, `runc`; Fedora: das
`moby-engine` der Distribution), bevor du Dockers Repository benutzt.

### Debian und Ubuntu

Dockers apt-Repository, wie in der offiziellen Anleitung. Die Befehle gelten für **Ubuntu**; unter
**Debian** ersetze `ubuntu` in beiden URLs durch `debian`.

```bash
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
Der Dienst startet unter Debian und Ubuntu automatisch beim Booten. Derivate (Linux Mint und
Verwandte) werden nicht offiziell unterstützt - nimm den Namen des passenden Debian- oder Ubuntu-Releases.

### Fedora

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```
Die Syntax `addrepo --from-repofile` ist DNF5 (Fedora 41 und neuer); mit DNF4 nimm
`config-manager --add-repo <URL>`. Die Paketinstallation startet Docker nicht - daher `enable --now`.

### RHEL, Rocky Linux, AlmaLinux

Folge Dockers Seite zu *RHEL* oder *CentOS*: Die Repository-Datei ist
`https://download.docker.com/linux/rhel/docker-ce.repo` (RHEL) oder
`https://download.docker.com/linux/centos/docker-ce.repo` (CentOS und Ableger wie
Rocky und AlmaLinux, die Docker selbst nicht testet). Installiere dann dieselben fünf Pakete wie unter
Fedora und führe `sudo systemctl enable --now docker` aus. Mit diesem Lab nicht getestet.

### Arch Linux

Aktualisiere zuerst - ein Teil-Upgrade ist der häufigste Weg, Arch kaputt zu machen:

```bash
sudo pacman -Syu
sudo pacman -S docker docker-compose docker-buildx
sudo systemctl enable --now docker
```
Das Paket `docker-compose` liefert das Plugin `docker compose`. Dockers eigenes Arch-Paket
(Docker Desktop für Linux) kollidiert mit diesen - nimm eins von beiden.

### openSUSE

```bash
sudo zypper install docker docker-compose docker-buildx
sudo systemctl enable --now docker
```
Unter Leap 16 installiert das Paket `docker-compose` das Compose-v2-Plugin (`docker compose`; es gibt
kein Binary mit Bindestrich); Tumbleweed nutzt dieselben Paketnamen. Ältere Leap-Releases haben
das Paket womöglich nicht: Installiere das Compose-Plugin dann manuell aus Dockers Binär-Releases. Leap 16 bringt
Podman von Haus aus mit - installiere `podman-docker` nicht neben dem echten Docker.

### Docker ohne `sudo` nutzen

Nimm deinen Benutzer in die Gruppe `docker` auf, melde dich ab und wieder an (oder führe `newgrp docker` aus):

```bash
sudo usermod -aG docker $USER
docker run --rm hello-world
```
Die Mitgliedschaft in `docker` ist auf dem Host **root-äquivalent** - was die privilegierten Lab-Targets
ohnehin sind. Starte das Lab nicht mit `sudo ./lab.sh`: `id -u` wäre 0, und der
Control Node würde für `learner` einen zweiten root-Benutzer anlegen. Wenn es nicht anders geht, gib deine eigenen IDs mit:
`sudo env LAB_UID=$(id -u) LAB_GID=$(id -g) ./lab.sh up`.

### Linux-Details

- **SELinux** (Fedora, RHEL-Familie). Dockers Standard-Daemon trennt Container nicht per
  SELinux, also ändert sich nichts. Hast du `"selinux-enabled": true` in
  `/etc/docker/daemon.json` aktiviert, kann der Control Node das eingehängte Lab-Verzeichnis nicht lesen, bis
  du in `compose.yaml` die Option `z` an dieses Volume hängst (`./:/lab:z`). Nutze `Z` oder
  `z` nie auf Systemverzeichnissen.
- **Firewall.** Das Lab veröffentlicht keine Ports, `ufw` oder `firewalld` können dadurch also nicht „umgangen“ werden;
  die Container brauchen nur ausgehenden Zugriff über Dockers NAT. Docker ist mit
  `iptables-nft` und `iptables-legacy` kompatibel; direkt mit `nft` angelegte Regeln werden nicht unterstützt, solange Docker
  läuft - nie `nft flush ruleset` auf dem Host. Mit `firewalld` legt Docker eine Zone namens `docker` an.
- **Subnetz.** Das Lab-Netz ist `172.31.250.0/24`. Nutzt ein VPN oder dein LAN es schon, scheitert
  `docker compose up` mit *Pool overlaps with other one on this address space*. Ändere das
  `subnet:` in `compose.yaml`; die Hosts werden über ihren Namen angesprochen, nicht über die IP.
- **Docker Desktop für Linux** betreibt eine eigene VM mit eigenem Docker-Kontext und ist ein anderes Setup
  als Docker Engine; nicht getestet.

## Docker auf den Plattformen im Überblick

| | Linux | Windows (WSL2) | macOS |
|---|---|---|---|
| Wo die Container laufen | auf deinem Host | in der WSL2-VM | in der VM von Docker Desktop |
| Kernel, den die Targets teilen | der deines Hosts | der WSL2-Kernel | der Kernel der VM |
| Installation | Docker Engine aus der Distribution oder aus Dockers Repository | Engine in einer WSL-Distribution oder Docker Desktop | Docker Desktop (oder Colima, OrbStack) |
| Wer den Daemon nutzen darf | Mitglieder von `docker` (root-äquivalent) | Mitglieder von `docker` in der WSL-Distribution (Engine) oder dein Windows-Benutzer (Docker Desktop) | dein macOS-Benutzer, über Docker Desktop |
| Ressourcen-Limits | die des Hosts | `%UserProfile%\.wslconfig` und Docker Desktop | Docker Desktop *Settings > Resources* |
| Wo das Repo liegen sollte | beliebig | **im** WSL-Dateisystem | beliebig in deinem Home-Ordner |
| Dateizugriff auf `./work` | nativ | schnell in WSL, langsam unter `/mnt/c` | über die VM, langsamer |
| Platte | die Platte des Hosts | virtuelle Platte (VHDX); `df /` zeigt ihre Größe | virtuelle Platte der VM |
| Lizenz | Open Source | Engine: Open Source; Docker Desktop: kostenpflichtig für große Unternehmen | Docker Desktop: kostenpflichtig für große Unternehmen |
| Mit diesem Lab getestet | Debian (nativer Host) | ja (Ubuntu 26.04, Docker Engine) | nein |

## Aktualisieren, pausieren, entfernen

| Aufgabe | Befehl |
|---|---|
| Das Lab aktualisieren | `git pull --ff-only`, danach `docker compose build && docker compose up -d`, wenn sich Dockerfiles geändert haben (siehe Abschnitt *Lab aktualisieren* der README und das [CHANGELOG](CHANGELOG.md)) |
| Vorerst anhalten, Targets so lassen, wie sie sind | `./lab.sh pause`, später `./lab.sh resume` |
| Jedes Target frisch starten | `./lab.sh reset all` (oder `down`, dann `up`) |
| Container, Volumes und Lab-Images entfernen | `./lab.sh destroy` (dein `./work` und `./.lab` bleiben) |
| Das Lab ganz entfernen | `./lab.sh destroy`, dann das Verzeichnis löschen |

Docker selbst entfernst du so, wie du es installiert hast - siehe Dockers Deinstallationsanleitungen
für Docker Engine und Docker Desktop.

## Wenn etwas schiefgeht

| Symptom | Ursache | Lösung |
|---|---|---|
| `Cannot connect to the Docker daemon` | der Daemon läuft nicht | Linux und WSL: `sudo systemctl enable --now docker` (in WSL muss systemd laufen, siehe Route A Schritt 2); Docker Desktop: starten und warten, bis es *running* meldet |
| `permission denied ... /var/run/docker.sock` | dein Benutzer ist nicht in der Gruppe `docker` | [Docker ohne sudo nutzen](#docker-ohne-sudo-nutzen), dann neu anmelden |
| `docker: command not found` in einem WSL-Terminal | Docker Engine ist in dieser Distribution nicht installiert, oder (Docker Desktop) die WSL-Integration ist aus | Route A Schritt 3, oder Docker Desktop *Settings > Resources > WSL integration* |
| `Unsupported config option ... 'cgroup'` oder `'compose' is not a docker command` | das alte `docker-compose` (v1), kein Compose-Plugin oder Compose älter als 2.15 | das Compose-v2-Plugin installieren und `docker compose` nutzen |
| `Pool overlaps with other one on this address space` | `172.31.250.0/24` wird anderswo benutzt | `subnet:` in `compose.yaml` ändern |
| Ein systemd-Target beendet sich sofort | der Host nutzt nicht cgroup v2 | [Linux](#linux) und die erste Zeile von [TROUBLESHOOTING](docs/TROUBLESHOOTING.de.md) |
| `rocky` / `alma` stürzen mit `Fatal glibc error: CPU does not support x86-64-v2` ab | die CPU unterstützt nicht, was Enterprise Linux 10 braucht | [TROUBLESHOOTING](docs/TROUBLESHOOTING.de.md) |
| Skripte scheitern mit `^M` oder `\r` in der Meldung | CRLF-Zeilenenden aus einem Windows-Klon | [Windows-Details](#windows-details), dann neu klonen |
| Dateien in `./work` gehören root | das Lab wurde ohne `./lab.sh` oder mit `sudo` gestartet | als eigener Benutzer mit `./lab.sh up` starten |

Alles zum *Betrieb* des Labs (Aufgaben, UNREACHABLE-Hosts, `down` gegenüber `pause`) steht in
[`docs/TROUBLESHOOTING.de.md`](docs/TROUBLESHOOTING.de.md).

## Quellen

- [Docker Desktop für Windows](https://docs.docker.com/desktop/setup/install/windows-install/) und [das WSL2-Backend](https://docs.docker.com/desktop/features/wsl/)
- [Docker Desktop für Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
- [Docker Engine: unterstützte Plattformen](https://docs.docker.com/engine/install/), [Ubuntu](https://docs.docker.com/engine/install/ubuntu/), [Fedora](https://docs.docker.com/engine/install/fedora/) und [Schritte nach der Installation](https://docs.docker.com/engine/install/linux-postinstall/)
- [Compose-Dateireferenz: `cgroup`](https://docs.docker.com/reference/compose-file/services/) und [Paketfilterung und Firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
- [WSL: `wsl.conf` und `.wslconfig`](https://learn.microsoft.com/windows/wsl/wsl-config) und [systemd in WSL](https://learn.microsoft.com/windows/wsl/systemd)
- [Arch Wiki: Docker](https://wiki.archlinux.org/title/Docker) und [openSUSE: Docker](https://en.opensuse.org/Docker)
