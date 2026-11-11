# Ansible-CIS-Härtungslab

*[English](README.md)*

Eine eigenständige Trainingsumgebung, um Linux-Systeme mit Ansible entlang der
CIS-Benchmarks zu härten - vom ersten Ad-hoc-Kommando bis zur produktionsreifen
Multi-Distro-Rolle mit Audit-Modus, Ausnahmen und gestaffeltem Rollout.

```
              ┌─────────────────────────── Netzwerk "lab" 172.31.250.0/24 ──────────────────────────┐
  du ──► control  ──ssh──►  debian · ubuntu · rocky · alma · fedora · opensuse · arch · alpine
        (ansible-core 2.21,     systemd als PID 1 ................................ OpenRC (busybox init)
         Lint, lab-CLI)         beim ersten Start absichtlich nicht konform
```

| | |
|---|---|
| **Targets** | Debian 13, Ubuntu 26.04, Rocky 10, AlmaLinux 10, Fedora 44, openSUSE Leap 16, Arch (rolling), Alpine 3.24 |
| **Aufgaben** | 31 in 6 Stufen, ~28 h, jeweils mit Ziel, Hintergrund, Anforderungen, 3 gestaffelten Hinweisen, Bonus, Musterlösung, Erklärung, automatischem Check |
| **Lektionen** | 15 Lektionen zum Selbststudium (L00-L14, ~7 h Lesezeit) - Konzepte vor den Aufgaben, Plattformunterschiede, Stolperfallen, Selbstkontrolle: `lab lesson`; ein [Glossar](docs/GLOSSARY.de.md) der Begriffe (`lab docs glossary`) |
| **Sprachen** | Englisch (Standard) und Deutsch: `lab lang de` |
| **CIS** | Profil Level 1 Server (+ ausgewählte Level 2); eigener Kontrollkatalog in [`cis/controls.yml`](cis/controls.yml); PDFs: siehe [`cis/README.de.md`](cis/README.de.md) |

## Schnellstart

Voraussetzungen: Docker Engine 24+ oder Docker Desktop mit Compose v2, ~8 GB freier Platz, 4 GB RAM.
Unter Windows WSL2 nutzen und das Lab **im Linux-Dateisystem** ablegen (z. B. `~/ansible-cis-lab`, nicht `/mnt/c/...`).
Docker noch nicht installiert, oder etwas scheitert? Schritt für Schritt für Windows, macOS und Linux, mit den
Besonderheiten von Docker auf jedem System: [`INSTALL.de.md`](INSTALL.de.md).

<!-- parity: lang-specific -->
```bash
./lab.sh up          # bauen + starten (der erste Build dauert)
./lab.sh shell       # Shell im Control Node
lab lang de          # Texte auf Deutsch
lab placement        # Einstufungstest mit 10 Fragen → Einstiegspunkt
lab lesson           # die Lektionen und die Aufgaben, die jede vorbereitet
lab list             # alle Aufgaben mit deinem Fortschritt
lab start 0.01       # loslegen
```
Windows PowerShell: `.\lab.ps1 up`, `.\lab.ps1 shell`, `.\lab.ps1 pause` / `resume`.

## So läuft eine Aufgabe

```bash
lab lesson 1.03      # die Lektion(en) zur Aufgabe: erst die Konzepte
lab show 1.03        # Aufgabe lesen
lab start 1.03       # legt /lab/work/1.03 an (= ./work/1.03 auf dem Host - mit deiner IDE bearbeiten)
ansible-playbook playbook.yml
lab check 1.03       # Zustandsprüfung + Idempotenz (ein --check-Lauf darf nichts ändern)
lab hint 1.03 1      # sanfter Hinweis ... lab hint 1.03 3 fast die Lösung
lab explain 1.03     # nach dem Bestehen: Stolperfallen, Alternativen, Praxis
```
Host kaputt? `./lab.sh reset debian` (oder `reset all`) erzeugt ihn im Ursprungszustand neu.

**Pausieren oder zurücksetzen?** Änderungen an den Targets leben nur in ihren Containern:

| Befehl (Host) | Container | Targets danach |
|---|---|---|
| `./lab.sh pause` / `./lab.sh resume` | gestoppt / wieder gestartet | so, wie du sie verlassen hast (auch Python auf `alpine`) |
| `./lab.sh down` + `./lab.sh up` | entfernt / neu angelegt | frisch, nicht konform - wie `reset all`; für Python auf `alpine` `lab solve 0.02 -y` ausführen |
| `./lab.sh reset <host\|all>` | neu erzeugt | frisch, nicht konform |

Deine Dateien in `./work` und dein Fortschritt (`./.lab`) bleiben in jedem Fall erhalten.

## Komfort im Control Node

| | |
|---|---|
| Shell | bash mit [oh-my-bash](https://github.com/ohmybash/oh-my-bash) (Theme `font`; `OSH_THEME` in `~/.bashrc` ändern, Themes in `/opt/oh-my-bash/themes`), Tab-Vervollständigung für `lab` |
| Editor | `vim` (Syntax, YAML mit 2 Leerzeichen, Cursorspalte für YAML), `nano`; `EDITOR=vim` |
| Markdown | überall gerendert (Links zeigen ihren Text): `lab view <datei.md>`, `lab lesson [n]`, `md <datei.md>`, `less <datei.md>`, `lab docs [name]`; vom Host `./lab.sh view <datei.md>` / `.\lab.ps1 view <datei.md>` |
| Aliase | `ap` = ansible-playbook, `al` = ansible-lint --offline |

## Lab aktualisieren

```bash
git pull --ff-only
docker compose build && docker compose up -d     # nur nötig, wenn sich Dockerfiles geändert haben
```
Skripte in `control/` (`lab`, `lab-view`, Shell- und vim-Konfiguration) laufen **live aus dem Repository** -
ein `git pull` reicht. Image-Änderungen (Pakete, oh-my-bash, Basis-Images, `targets/`) brauchen den Build.

**Was ein Update überlebt** (alles in von Git ignorierten Ordnern deines Klons):

| Bleibt erhalten | Wo |
|---|---|
| deine Lösungen | `./work/` |
| Fortschritt (`lab progress`), Sprache, Shell-Historie | `./.lab/` |
| SSH-Schlüssel des Labs | Docker-Volume `lab-keys` (nur `./lab.sh destroy` entfernt es) |

**Was zurückgesetzt wird:** die Targets, sobald sich ihr Image ändert oder du `./lab.sh reset` ausführst -
sie starten wieder nicht konform (dein Fortschritt bleibt vermerkt, `lab check` scheitert, bis du neu anwendest).
Verloren nur durch `git clean -fdx`, Löschen des Klons oder einen neuen Klon an anderer Stelle - Sicherung mit
`tar czf lab-backup.tgz work .lab`.

Änderungen pro Version und was neu gebaut werden muss: [`CHANGELOG.md`](CHANGELOG.md).

Du änderst das Lab selbst (Aufgaben, Doku, Lösungen)? Führe vor dem Pull Request
`tools/static-check.sh` aus - im Control Node: `docker compose exec control /lab/tools/static-check.sh`.
CI führt dieselben Prüfungen aus. Änderst du Aufgaben, Lösungen, Checks, Images oder das
`lab`-Werkzeug, führe zusätzlich den Laufzeittest auf dem Host aus (Lab läuft):
`tools/run-solutions.sh stage2` setzt vor jedem Lauf alle Targets zurück (ihr Zustand geht verloren,
`./work` und `lab progress` bleiben), wendet jede Musterlösung der Stufe an, führt ihren `lab check`
aus und einen zweiten Lauf, der nichts ändern darf (`--list` zeigt den Plan, `--help` die Details).
`tools/run-solutions.sh chain` führt die aufbauenden Aufgaben 3.01-5.02 so aus, wie Lernende sie
bearbeiten: ein Reset, dann jeder Schritt auf dem Zustand, den die Schritte davor hinterlassen.
`tools/run-solutions.sh 5.01` prüft eine aufbauende Rolle frisch (nur 0.02 davor), `all` führt
alles aus (über zwei Stunden). CI führt die Stufen 0-4, die Kette und die frischen Läufe von 4.03
und 5.01 aus, jeweils in einem eigenen Job (Workflow `runtime`).

## Lernpfad

| Stufe | Schwerpunkt | Aufgaben |
|---|---|---|
| 0 Grundlagen | Inventar, Ad-hoc, raw-Bootstrap, Facts, erstes Playbook | 0.01-0.04 |
| 1 Einsteiger | package, file, copy + validate, Handler, service | 1.01-1.05 |
| 2 Bausteine | Variablen, Schleifen, Templates, Daten pro Familie, Collections | 2.01-2.06 |
| 3 Mittelstufe | Rollen, PAM, Passwortrichtlinie, auditd, Konten-Audit | 3.01-3.05 |
| 4 Fortgeschritten | Audit-Berichte, Profile/Ausnahmen, datengetriebene Multi-Plattform, Vault, Custom Facts, faillock, Firewall mit Rollback, async | 4.01-4.08 |
| 5 Abschluss | Rolle mit Audit-/Enforce-Modus, Rollout-Strategie, Review einer Community-Rolle | 5.01-5.03 |

Details: [`docs/LEARNING_PATH.de.md`](docs/LEARNING_PATH.de.md) · Übersicht: [`exercises/INDEX.de.md`](exercises/INDEX.de.md)

## Aufbau

```
compose.yaml          Control + 8 Targets (privilegiert, siehe docs/CONTAINER_LIMITS.de.md)
lab.sh / lab.ps1      Host-Wrapper: up, pause, resume, down, reset, shell und Weiterleitung an 'lab'
INSTALL.md            Installation unter Windows, macOS und Linux, inkl. Docker-Hinweisen je Plattform
control/              Image des Control Nodes, 'lab'-CLI
targets/              ein Dockerfile pro Distribution + gemeinsamer Bootstrap (pflanzt die Befunde)
ansible/              ansible.cfg, Inventar (nach OS-Familie gruppiert), gemeinsame Rollen
exercises/            stage*/<id>-<slug>/ README, HINTS, EXPLANATION (EN+DE), solution/, Check
cis/                  Kontrollkatalog + Ablage für deine CIS-PDFs
docs/                 Lernpfad, lessons/ (L00-L14), Glossar, Container-Grenzen, Fehlerbehebung
tools/                Prüfskripte für Maintainer: Release-Hygiene, statisches Qualitäts-Gate,
                      Laufzeittest der Musterlösungen (alle drei in CI)
work/                 DEINE Lösungen (eingehängt nach /lab/work)
```

## Wichtig

- Die Targets laufen **privilegiert** mit echtem Init-System, damit die meisten Kontrollen
  realistisch sind. Manche Kernel-Funktionen teilen sie mit deinem Host - die Aufgaben sagen
  genau, was im Container nicht aktiviert werden darf. Lies [`docs/CONTAINER_LIMITS.de.md`](docs/CONTAINER_LIMITS.de.md).
- Das Lab dient nur dem Training: gleiche SSH-Hostschlüssel pro Image, schlüsselbasiertes
  sudo ohne Passwort für das Konto `ansible`, absichtlich unsicherer Ausgangszustand.
