# 5.03 - Review: deine Rolle vs. eine Community-CIS-Rolle: Erklärung

### Worauf du bei jeder fremden Härtungsrolle achtest
- **Granularität der Schalter**: eine Variable pro Kontrolle ist essenziell - du *wirst*
  Ausnahmen brauchen.
- **Störende Kontrollen**: gute Rollen kennzeichnen sie (oft ein Schalter im Stil von
  `disruption_high`) und lassen sie standardmäßig aus. Firewall, PAM, Mount-Optionen,
  SELinux/AppArmor im Enforcing-Modus, GRUB-Passwörter sind typisch.
- **Audit-Fähigkeit**: separates Audit-Werkzeug (z. B. goss-basiert) liefert eine
  unabhängige Zweitmeinung - dein Check-Modus-Ansatz nutzt denselben Code für beides,
  einfacher, aber nicht unabhängig.
- **Benchmark-Versionsbezug**: sagt die Rolle, welche CIS-Benchmark-Version sie umsetzt?
  Bilden Release Notes Änderungen auf Kontroll-IDs ab?
- **Testmatrix**: welche OS-Versionen und Szenarien testet die CI?

### Bauen vs. übernehmen - ein typisches Fazit
Eine gepflegte Rolle zu übernehmen spart enormen Aufwand bei der Abdeckung; dein Beitrag
verlagert sich auf *Konfiguration* (welche Kontrollen, welche Ausnahmen), *Tests* (ein Lab
wie dieses) und *Betrieb* (Rollout, Berichte). Selbst bauen lohnt sich für kleine Umfänge,
ungewöhnliche Plattformen (wie hier Alpine) oder wenn du jede Zeile kontrollieren musst.
Viele Teams machen beides: übernehmen, in eine eigene Rolle für organisationsspezifische
Einstellungen und Berichte einbetten und Korrekturen upstream beisteuern.

### Nie ungeprüft ausführen
Eine Härtungsrolle ist root-Code, der auf jedem Server Authentifizierung und Netzwerk
anfasst. Prüfe sie, wie du einen Kernel-Patch für Produktion prüfen würdest - dein Lab ist
der Ort, das gefahrlos zu tun.

## Musterlösung

Anzeigen mit `lab solution 5.03`, anwenden mit `lab solve 5.03`.
