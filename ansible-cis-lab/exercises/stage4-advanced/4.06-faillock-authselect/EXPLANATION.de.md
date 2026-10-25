# 4.06 - Kontosperre mit pam_faillock (authselect): Erklärung

### Ein CLI idempotent kapseln
`authselect enable-feature` liefert keine verlässliche "schon aktiv → keine
Änderung"-Ausgabe, also: Zustand lesen (`authselect current`), entscheiden (`when`),
ehrlich melden (`changed_when: true`). Dasselbe Muster wie `useradd -D` in 3.02.

### Schlüssel-Logins und faillock
sshd mit Public-Key-Authentifizierung durchläuft die PAM-*auth*-Phase **nicht** - den
Schlüssel prüft sshd selbst. Es durchläuft PAM *account* und *session*. `pam_faillock`
in der account-Phase verweigert nur, wenn das Konto schon gesperrt ist. Fehlgeschlagene
*Passwort*-Versuche per SSH, Konsole, `su` oder `sudo` zählen. Deine Automatisierung ist
also sicher - es sei denn, jemand sperrt das `ansible`-Konto mit falschen `su`-Versuchen...
deshalb nehmen manche Umgebungen Dienstkonten aus.

### Warum PAM nicht bearbeiten
`authselect apply-changes` oder ein Profilwechsel erzeugt `system-auth` und
`password-auth` neu. Eine manuelle `pam_faillock`-Zeile verschwände still - die
schlimmste Art von Härtungsregression.

### Auskommentierte Defaults
`faillock.conf` kommt mit `# deny = 3`. Die Regexp `^\s*#?\s*deny\s*=` trifft den
Kommentar und ersetzt ihn an Ort und Stelle - deine Einstellung steht da, wo die
Dokumentation sie erwartet.

## Musterlösung

Anzeigen mit `lab solution 4.06`, anwenden mit `lab solve 4.06`.
