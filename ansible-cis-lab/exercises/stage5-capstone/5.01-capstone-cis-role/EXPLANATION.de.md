# 5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus: Erklärung

### Check-Modus als Audit-Engine
Jedes idempotente Modul weiß bereits, ob der Sollzustand erfüllt ist - genau das bedeutet
`changed`. Im Check-Modus beantwortet es die Frage, ohne zu handeln. Der Behebungscode
*ist* also der Audit-Code. Die einzige Arbeit:
- lesende Tasks weiterlaufen lassen (`check_mode: false`),
- übersprungene `command`-Tasks ("would have run") als Befunde werten,
- Nebenwirkungen stoppen, die den Check-Modus umgehen (Handler, `meta`, Hintergrundjobs).

### Warum eine Registry
Eine Liste von Kontrollen mit Metadaten (id, level, title, requires) liefert: Profile
(`level`), Ausnahmen (`id`), Plattform-Anwendbarkeit (`requires`), Teilläufe
(`cis_controls_only`) und einen Bericht, der die *Titel* des Geprüften kennt. Eine
Kontrolle hinzufügen = eine Datei + eine Registry-Zeile.

### Dynamische Includes und ihr Preis
`include_tasks` in einer Schleife wird zur Laufzeit pro Host ausgewertet - `--list-tasks`
und Tags sind daher weniger nützlich als bei statischen Imports. Das ist der Preis für
Check-Modus und Protokollierung pro Kontrolle. Dokumentiere, wie man eine Teilmenge
ausführt (`-e '{"cis_controls_only": ["5.1"]}'`).

### Die Abnahmesequenz
Audit → Enforce → Audit ist genau der Weg, die Rolle in Produktion einzuführen: messen,
im Change-Fenster beheben, das Ergebnis belegen. Der zweite Enforce-Lauf mit `changed=0`
beweist Idempotenz - dein Nachweis, dass die Rolle beim täglichen Lauf kein Drift-Rauschen
erzeugt.

### Was Produktion ergänzt
CI (Lint + Molecule über alle Plattformen), versionierte Releases, den Bericht in ein
Dashboard/SIEM geschoben, regelmäßig überprüfte Ausnahmen und eine Rollout-Strategie -
nächste Aufgabe.

## Musterlösung

Anzeigen mit `lab solution 5.01`, anwenden mit `lab solve 5.01`.
