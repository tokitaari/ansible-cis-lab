# 5.03 - Review: deine Rolle vs. eine Community-CIS-Rolle

## Hinweis 1

Beginne mit `defaults/main.yml` - die Variablennamen verraten das Schalter-Design. Dann `tasks/main.yml` für die Struktur. (Manche Rollen legen die Defaults in einem Verzeichnis `defaults/main/` mit mehreren Dateien ab.)

## Hinweis 2

Durchsuche die Defaults nach Wörtern wie `disruption`, `workstation`, `level`, `audit`. Auch die Tags an den Tasks gehören zum Design.

## Hinweis 3

Das Skelett von `review.md` - jede Antwort beginnt eine Zeile mit ihrer Nummer, danach sucht `lab check`:

```
1. Wie werden Kontrollen ein- und ausgeschaltet?
   - wo liegen die Variablen, wie heißen sie, eine pro Kontrolle oder pro Gruppe?
   - wie sieht eine Ausnahme in deinem Design aus, und in ihrem?
2. Level und Profile
   - Variable oder Tag? was sagen die Defaults zu Level 2 und zu Workstation?
3. Standardmäßig deaktiviert
   - welche Schalter stehen standardmäßig auf aus oder false, und was haben sie gemeinsam?
4. Zwei riskante Kontrollen
   - welcher Task, welche Absicherung (ein Schalter, eine Bedingung, eine Warnung)?
5. Audit und Bericht
   - Check-Modus oder ein separates Werkzeug? wohin geht das Ergebnis, in welchem Format?
6. Entscheidung für 500 Server: übernehmen, forken oder bauen
   - drei Risiken, drei Abnahmetests, wer prüft jedes Release?
```

Für Frage 6 gibt es keine einzig richtige Antwort. Eine starke Antwort nennt konkrete Risiken (Update-Takt, lokale Abweichungen, Review-Aufwand) und eine Teststrategie (Lab wie dieses, Molecule, gestaffelter Rollout).
