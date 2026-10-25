# 3.02 - Passwortalterung und inaktive Konten: Erklärung

### Kerntechniken
**Erst lesen, dann handeln bei Befehlen**
```yaml
- name: Read useradd defaults
  ansible.builtin.command: useradd -D
  register: cis_useradd_defaults
  changed_when: false
  check_mode: false          # läuft auch bei --check, es liest nur
- name: Lock accounts after 45 days of inactivity
  ansible.builtin.command: useradd -D -f 45
  when: "'INACTIVE=45' not in cis_useradd_defaults.stdout_lines"
  changed_when: true
```
Ein command-Modul kann nicht wissen, ob es etwas geändert hat. Du machst es
idempotent, indem du vorher prüfst und ehrlich meldest.

**Fakten aus Dateien**
`slurp` liefert base64; `b64decode` + `regex_findall` extrahiert Werte. `last` bildet
ab, wie login.defs funktioniert (spätere Zeilen überschreiben frühere).

### Warum "nicht abschwächen" zählt
yescrypt ist speicherhart und auf GPUs viel teurer zu knacken als SHA-512-crypt. Eine
Härtungsrolle, die ein System still abschwächt, verfehlt ihren Zweck - und ein
CIS-Scanner würde es nicht einmal bemerken, weil beide Werte akzeptiert sind.

### Die /usr/etc-Geschichte
Atomare/unveränderliche Designs (openSUSE, Fedoras `/usr/etc`-Arbeit) halten
Vendor-Defaults in `/usr` und nur Admin-Überschreibungen in `/etc`. Härtungscode, der
"die Datei anlegt, falls sie fehlt", kann alle Vendor-Defaults auf einmal löschen.
Prüfe immer, wie eine Komponente ihre Konfiguration liest, bevor du sie schreibst.

### Bestehende Benutzer (Bonus)
`login.defs` wird von `useradd` gelesen - bestehende Konten behalten ihre Werte. CIS
prüft beides: den Default und jeden Benutzer mit Passwort. `chage --maxdays 365
<user>` oder `ansible.builtin.user` mit `password_expire_max: 365` korrigiert sie.

## Musterlösung

Anzeigen mit `lab solution 3.02`, anwenden mit `lab solve 3.02`.
