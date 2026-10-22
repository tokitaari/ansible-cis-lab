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
| **Sprachen** | Englisch (Standard) und Deutsch: `lab lang de` |
| **CIS** | Profil Level 1 Server (+ ausgewählte Level 2); eigener Kontrollkatalog in [`cis/controls.yml`](cis/controls.yml); PDFs: siehe [`cis/README.de.md`](cis/README.de.md) |

## Schnellstart

Voraussetzungen: Docker Engine 24+ oder Docker Desktop mit Compose v2, ~8 GB freier Platz, 4 GB RAM.
Unter Windows WSL2 nutzen und das Lab **im Linux-Dateisystem** ablegen (z. B. `~/ansible-cis-lab`, nicht `/mnt/c/...`).

```bash
./lab.sh up          # bauen + starten (der erste Build dauert)
./lab.sh shell       # Shell im Control Node
lab lang de          # Texte auf Deutsch
lab placement        # Einstufungstest mit 10 Fragen → Einstiegspunkt
lab list             # alle Aufgaben mit deinem Fortschritt
lab start 0.01       # loslegen
```
Windows PowerShell: `.\lab.ps1 up`, `.\lab.ps1 shell`.

## So läuft eine Aufgabe

```bash
lab show 1.03        # Aufgabe lesen
lab start 1.03       # legt /lab/work/1.03 an (= ./work/1.03 auf dem Host - mit deiner IDE bearbeiten)
ansible-playbook playbook.yml
lab check 1.03       # Zustandsprüfung + Idempotenz (ein --check-Lauf darf nichts ändern)
lab hint 1.03 1      # sanfter Hinweis ... lab hint 1.03 3 fast die Lösung
lab explain 1.03     # nach dem Bestehen: Stolperfallen, Alternativen, Praxis
```
Host kaputt? `./lab.sh reset debian` (oder `reset all`) erzeugt ihn im Ursprungszustand neu.

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
lab.sh / lab.ps1      Host-Wrapper: up, down, reset, shell und Weiterleitung an 'lab'
control/              Image des Control Nodes, 'lab'-CLI
targets/              ein Dockerfile pro Distribution + gemeinsamer Bootstrap (pflanzt die Befunde)
ansible/              ansible.cfg, Inventar (nach OS-Familie gruppiert), gemeinsame Rollen
exercises/            stage*/<id>-<slug>/ README, HINTS, EXPLANATION (EN+DE), solution/, Check
cis/                  Kontrollkatalog + Ablage für deine CIS-PDFs
docs/                 Einstieg, Lernpfad, Container-Grenzen, Fehlerbehebung
work/                 DEINE Lösungen (eingehängt nach /lab/work)
```

## Wichtig

- Die Targets laufen **privilegiert** mit echtem Init-System, damit die meisten Kontrollen
  realistisch sind. Manche Kernel-Funktionen teilen sie mit deinem Host - die Aufgaben sagen
  genau, was im Container nicht aktiviert werden darf. Lies [`docs/CONTAINER_LIMITS.de.md`](docs/CONTAINER_LIMITS.de.md).
- Das Lab dient nur dem Training: gleiche SSH-Hostschlüssel pro Image, schlüsselbasiertes
  sudo ohne Passwort für das Konto `ansible`, absichtlich unsicherer Ausgangszustand.
