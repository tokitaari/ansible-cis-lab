# Lernpfad

*[English](LEARNING_PATH.md)*

Das Lab ist so gebaut, dass **Einsteiger und erfahrene Admins dieselben Aufgaben nutzen**,
ohne sich zu langweilen oder überfordert zu sein:

| Mechanismus | Für Einsteiger | Für Erfahrene |
|---|---|---|
| Lektionen (`lab lesson`) | vor den Aufgaben lesen | überfliegen, mit der Selbstkontrolle Lücken finden |
| Einstufungstest (`lab placement`) | Start bei 0.01 | Sprung zu Stufe 2 oder 3, frühere per `lab solve` |
| Drei gestaffelte Hinweise pro Aufgabe | Hinweis 1 → 2 → 3, bis es klickt | ignorieren |
| Anforderungen als Checkliste | klares Ziel | das Minimum, nicht das Ziel |
| Bonus-Aufgaben | optional | hier liegt die eigentliche Tiefe |
| Erklärungen nach dem Bestehen | Konzept festigen | Stolperfallen, Alternativen, Praxis |
| Automatische Checks inkl. Idempotenz | sofortiges Feedback | fängt "läuft einmal"-Lösungen ab |

## Stufen

| Stufe | Danach kannst du ... | Zeit |
|---|---|---|
| **0 Grundlagen** | ein Inventar lesen, Ad-hoc-Kommandos ausführen, einen Host ohne Python bootstrappen, Facts nutzen, ein idempotentes Playbook schreiben | ~1,5 h |
| **1 Einsteiger** | Pakete entfernen, Rechte korrigieren, sshd und sudo *sicher* ändern (validate, Handler), Bedingungen nutzen | ~2 h |
| **2 Bausteine** | Plattformunterschiede als Daten ausdrücken, Schleifen, Templates, Collections nutzen, namespaced von globalen Kernel-Einstellungen trennen | ~3,5 h |
| **3 Mittelstufe** | alles als Rolle mit Tags strukturieren, CLIs idempotent kapseln, mit PAM-Werkzeugen arbeiten, Audit-Regeln entwerfen | ~4,5 h |
| **4 Fortgeschritten** | reine Audit-Berichte schreiben, Profile und Ausnahmen umsetzen, datengetriebene Multi-Plattform-Rollen bauen, Geheimnisse verwalten, Firewalls sicher ausrollen, lange Jobs asynchron ausführen | ~9,5 h |
| **5 Abschluss** | eine produktionsreife CIS-Rolle mit Audit-/Enforce-Modus und sicherem Rollout liefern und fremde Rollen kritisch prüfen | ~7 h |

## Lektionen

Jede Lektion erklärt die Konzepte hinter einer Gruppe von Aufgaben - Theorie, CIS-Hintergrund,
Plattformunterschiede, Stolperfallen und eine Selbstkontrolle. Lies sie, bevor du die Aufgaben
beginnst: `lab lesson <n>` oder `lab lesson <aufgaben-id>`; `lab lesson <n> answers` zeigt die
Antworten der Selbstkontrolle. L01 gehört zu keiner einzelnen Aufgabe: lies sie nach L00. Das
[Glossar](GLOSSARY.de.md) (`lab docs glossary`) erklärt die Begriffe in wenigen Zeilen und verweist
auf die Abschnitte der Lektionen.

| Lektion | Bereitet vor | Lesezeit |
|---|---|---|
| [L00 - Lab-Aufbau und Ansible-Grundlagen](lessons/L00-lab-and-ansible-basics.de.md) | 0.01, 0.02, 0.03, 0.04 | ~25 Min. |
| [L01 - CIS Benchmarks: Aufbau, Levels und der Lab-Katalog](lessons/L01-cis-benchmarks.de.md) | - | ~25 Min. |
| [L02 - Sichere Änderungen: Check-Modus, validate, Handler und Bedingungen](lessons/L02-safe-changes.de.md) | 1.01, 1.02, 1.03, 1.04, 1.05 | ~25 Min. |
| [L03 - Basis-Härtung: Pakete, Dienste, Dateirechte, SSH und sudo](lessons/L03-base-hardening.de.md) | 1.01, 1.02, 1.03, 1.04, 1.05, 2.01 | ~25 Min. |
| [L04 - Plattformunterschiede als Daten: Dictionaries, Schleifen, Jinja2 und Templates](lessons/L04-platform-differences-as-data.de.md) | 2.01, 2.02, 2.06 | ~25 Min. |
| [L05 - Kernel-Härtung: Module und sysctl](lessons/L05-kernel-modules-and-sysctl.de.md) | 2.03, 2.04 | ~25 Min. |
| [L06 - Job-Scheduler: wer führt was aus und wer darf planen](lessons/L06-job-schedulers.de.md) | 2.05 | ~25 Min. |
| [L07 - Rollen, Tags und Projektstruktur: eine Baseline, viele Schalter](lessons/L07-roles-tags-project-structure.de.md) | 3.01 | ~35 Min. |
| [L08 - Konten und PAM: wer sich anmelden darf, wie und mit welchem Passwort](lessons/L08-accounts-and-pam.de.md) | 3.02, 3.03, 3.05, 4.06 | ~30 Min. |
| [L09 - Auditing und Integrität: auditd, AIDE und langlaufende Tasks](lessons/L09-auditing-and-integrity.de.md) | 3.04, 4.08 | ~35 Min. |
| [L10 - Compliance-Berichte: Audit-Modus, Enforce-Modus und Custom Facts](lessons/L10-compliance-reporting.de.md) | 4.01, 4.05, 5.01 | ~30 Min. |
| [L11 - Profile, Ausnahmen und datengetriebene Rollen: eine Rolle, viele Adressaten](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md) | 4.02, 4.03 | ~35 Min. |
| [L12 - Geheimnisse mit Ansible Vault: ein Passwort aus Git und aus dem Log heraushalten](lessons/L12-secrets-with-ansible-vault.de.md) | 4.04 | ~30 Min. |
| [L13 - Host-Firewall mit nftables: die Regeln ändern, über die du den Host erreichst](lessons/L13-host-firewall-nftables.de.md) | 4.07 | ~30 Min. |
| [L14 - Rollout in Produktion: Fehlerbehandlung, Vorabprüfung, Wellen und Community-Rollen](lessons/L14-production-rollout.de.md) | 5.02, 5.03 | ~35 Min. |

## Empfohlene Reihenfolge und Abhängigkeiten

- **0.02 zuerst** (oder `lab solve 0.02`): Alpine braucht Python für jedes spätere Modul.
- Die Aufgaben in Stufe 2 sind voneinander unabhängig.
- **3.01** fasst 0.04-2.06 zu einer Rolle zusammen; **4.03** erweitert sie um Stufe 3; **5.01** macht daraus das Abschlussprojekt.
- 4.01, 4.02, 4.04-4.08 sind unabhängige "Werkzeugkasten"-Aufgaben - nach Interesse wählen.
- **Starter-Dateien** gibt es für die Playbook-Übungen der Stufen 0-2, dazu das leere Rollengerüst von 3.01. Ab Stufe 3 erweiterst du
  deine eigene Rolle und Playbooks, `lab start` legt dann meist nur das Arbeitsverzeichnis an.
- `lab start` warnt, wenn eine Übung auf einer aufbaut, die du noch nicht bestanden hast (`requires` in ihrer `meta.yml`).
- Vor 3.01, 4.03 und 5.01: `./lab.sh reset all`, damit die Regressionschecks beweisen, dass deine Rolle auf frischen Hosts funktioniert.

## Arbeitsweise, die sich auszahlt

1. Vor dem Start die Lektion der Aufgabe lesen (`lab lesson <id>`).
2. README lesen **und** zuerst den Ist-Zustand ansehen (`ansible ... -m command -a ...`).
3. Vor dem Anwenden mit `--check --diff` laufen lassen.
4. `lab check` → Meldungen lesen → erst dann Hinweise nutzen.
5. Nach dem Bestehen immer `lab explain` lesen - dort steckt das meiste übertragbare Wissen.
6. Deine Lösungen in `./work` unter Git halten; erst danach mit `lab solution` vergleichen.
