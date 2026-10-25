# 3.03 - Passwortqualität mit pam_pwquality: Erklärung

### Warum Drop-ins
`pwquality.conf` gehört dem Paket. `pwquality.conf.d/50-cis.conf` gehört dir -
Paket-Updates kollidieren nie damit, und die Kontrolle zu entfernen heißt, eine Datei
zu entfernen.

### PAM-Zuständigkeit
`/etc/pam.d/*` von Hand zu bearbeiten ist der häufigste Weg, Logins kaputt zu machen,
*und* der häufigste Grund, warum Härtung still zurückgedreht wird:
- **Debian/Ubuntu**: `pam-auth-update` erzeugt `common-*` aus Profilen neu. Eine manuelle
  Änderung wird beim nächsten Paket, das es aufruft, überschrieben.
- **RHEL/Fedora**: `system-auth` ist ein Symlink nach `/etc/authselect/`. `authselect
  select ... --force` oder `authselect apply-changes` überschreibt manuelle Änderungen.
Arbeite *mit* dem Werkzeug: Profile/Features aktivieren, nie erzeugte Dateien patchen.

### `enforce_for_root`
Ohne das kann root jedes Passwort setzen (pwquality warnt nur). CIS will root einschließen.

### chpasswd (Bonus)
`chpasswd` und `usermod -p` laufen für Qualitätsprüfungen nicht durch den PAM-*Password*-
Stack. Qualitätsregeln schützen interaktive Passwortänderungen, nicht administrative
Massenwerkzeuge. Das ist ok - man muss es nur wissen.

### Container
Die Lab-Images haben echte PAM-Stacks, die Konfiguration ist also identisch zu einer VM.
Was du hier nicht testen kannst, ist die Konsolenanmeldung.

## Musterlösung

Anzeigen mit `lab solution 3.03`, anwenden mit `lab solve 3.03`.
