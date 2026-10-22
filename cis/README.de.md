# CIS-Benchmarks

*[English](README.md)*

Die offiziellen CIS-Benchmark-PDFs sind **nicht** Teil dieses Labs: CIS stellt sie nach
Registrierung kostenlos bereit, aber unter Bedingungen, die eine Weitergabe nicht erlauben.
Lade sie selbst herunter und lege sie nach `cis/pdf/` (von Git ignoriert).

## Bezugsquelle

1. <https://www.cisecurity.org/cis-benchmarks> → *Operating Systems* → *Linux*.
2. Registrieren (kostenlos) und das PDF für jede Plattform herunterladen, auf der du übst.
3. Das Profil **Level 1 - Server** als Referenz nutzen; Level 2 nur, wo es im Lab vermerkt ist.

| Lab-Host | Herunterzuladender Benchmark | Hinweis |
|---|---|---|
| debian | Debian Linux (passende Hauptversion) | |
| ubuntu | Ubuntu Linux (passende LTS) | |
| rocky | Rocky Linux (passende Hauptversion) | |
| alma | AlmaLinux OS (passende Hauptversion) | |
| fedora | - (kein Fedora-Benchmark) | den Benchmark für Red Hat Enterprise Linux als nächste Referenz nutzen |
| opensuse | SUSE Linux Enterprise | openSUSE Leap teilt die Codebasis |
| arch | - | Kontrollen selbst übertragen - das ist Teil des Trainings |
| alpine | - | Kontrollen selbst übertragen; viele sind N/A (kein PAM, busybox) |

Vorgeschlagene Dateinamen: `cis/pdf/<plattform>-<version>-v<benchmark-version>.pdf`.
Prüfe die Release Notes jeder Benchmark-Version - Empfehlungsnummern können sich zwischen Versionen ändern.

## controls.yml

[`controls.yml`](controls.yml) ist der eigene Katalog des Labs (eigene Formulierungen, kein
CIS-Text). Er nennt pro Kontrolle den CIS-Abschnitt, das Profil-Level, ob sie in Containern
übbar ist (`full` / `config` / `no`) und welche Aufgaben sie umsetzen. So springst du zwischen
einer Aufgabe und dem passenden Kapitel des PDFs.
