# Lernpfad

*[English](LEARNING_PATH.md)*

Das Lab ist so gebaut, dass **Einsteiger und erfahrene Admins dieselben Aufgaben nutzen**,
ohne sich zu langweilen oder überfordert zu sein:

| Mechanismus | Für Einsteiger | Für Erfahrene |
|---|---|---|
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

## Empfohlene Reihenfolge und Abhängigkeiten

- **0.02 zuerst** (oder `lab solve 0.02`): Alpine braucht Python für jedes spätere Modul.
- Die Aufgaben in Stufe 2 sind voneinander unabhängig.
- **3.01** fasst 0.04-2.06 zu einer Rolle zusammen; **4.03** erweitert sie um Stufe 3; **5.01** macht daraus das Abschlussprojekt.
- 4.01, 4.02, 4.04-4.08 sind unabhängige "Werkzeugkasten"-Aufgaben - nach Interesse wählen.
- Vor 3.01, 4.03 und 5.01: `./lab.sh reset all`, damit die Regressionschecks beweisen, dass deine Rolle auf frischen Hosts funktioniert.

## Arbeitsweise, die sich auszahlt

1. README lesen **und** zuerst den Ist-Zustand ansehen (`ansible ... -m command -a ...`).
2. Vor dem Anwenden mit `--check --diff` laufen lassen.
3. `lab check` → Meldungen lesen → erst dann Hinweise nutzen.
4. Nach dem Bestehen immer `lab explain` lesen - dort steckt das meiste übertragbare Wissen.
5. Deine Lösungen in `./work` unter Git halten; erst danach mit `lab solution` vergleichen.
