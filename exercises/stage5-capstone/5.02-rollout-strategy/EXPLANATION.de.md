# 5.02 - Rollout-Strategie: Vorabprüfung, Canary, Wellen: Erklärung

### Warum es jedes Teil gibt
- **Vorabprüfung mit `any_errors_fatal`**: ist ein Host schon vor dem Start kaputt, soll
  ein Mensch draufschauen - keine halb ausgerollte Flotte.
- **Bestätigungsvariable**: Härtung ändert Authentifizierung und Netzwerkregeln. Ein
  Pflicht-`-e cis_rollout_confirm=true` verhindert "ich wollte nur den Check-Modus"-Unfälle
  und steht in den Joblogs.
- **Canary**: ein Host pro wichtiger Plattform fängt plattformspezifische Fehler früh.
- **`serial` + `max_fail_percentage: 0`**: ein Fehler in Welle 1 stoppt Welle 2. Ohne
  `max_fail_percentage` würde Ansible fröhlich mit der nächsten Welle weitermachen.
- **Nachprüfung mit neuer Verbindung**: der bestehende SSH-Master überlebt viele Fehler;
  nur ein *frischer* Login beweist, dass der nächste Operator noch hineinkommt.

### Trockenläufe
`--check` führt die Vorabprüfung trotzdem aus (lesende Befehle mit `check_mode: false`) -
du kannst die Sperrlogik also testen, ohne Hosts anzufassen.

### Wellengrößen
`serial: [1, "30%", "100%"]` heißt 1 Host, dann 30 % der übrigen, dann der Rest. Für
2.000 Server vielleicht `[1, 10, "5%", "25%", "100%"]` - die Idee: erst Vertrauen
aufbauen, dann den Schadensradius vergrößern.

## Musterlösung

Anzeigen mit `lab solution 5.02`, anwenden mit `lab solve 5.02`.
