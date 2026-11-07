# 5.03 - Review: deine Rolle vs. eine Community-CIS-Rolle: Erklärung

### Was der Check prüft
`lab check 5.03` führt nur `check.sh` aus. Es sucht `/lab/work/5.03/review.md`, für jede Frage 1
bis 6 eine Zeile, die die Antwort beginnt (`1.`, `1)`, `1:`, `## 1.`, `Q1:` oder `Frage 1:`; ein
bloßes `## 1` oder `**1.**` zählt nicht), und mindestens 300 Wörter. Es liest den Inhalt nicht,
führt die Rolle nicht aus und prüft keine einzige Tatsache. `lab solve 5.03` gibt nur aus, dass
es keine Musterlösung gibt, und `solution/NOTES.md` sagt dasselbe: der eigentliche Check ist das
Gespräch mit jemandem aus dem Team.

### So funktioniert es

#### Worauf du bei jeder fremden Härtungsrolle achtest
- **Granularität der Schalter**: eine Variable pro Kontrolle ist essenziell - du *wirst*
  Ausnahmen brauchen.
- **Störende Kontrollen**: gute Rollen kennzeichnen sie (oft ein Schalter im Stil von
  `disruption_high`) und lassen sie standardmäßig aus. Firewall, PAM, Mount-Optionen,
  SELinux/AppArmor im Enforcing-Modus, GRUB-Passwörter sind typisch.
- **Audit-Fähigkeit**: ein separates Audit-Werkzeug liefert eine unabhängige Zweitmeinung - dein
  Check-Modus-Ansatz nutzt denselben Code für beides, einfacher, aber nicht unabhängig.
- **Benchmark-Versionsbezug**: sagt die Rolle, welche CIS-Benchmark-Version sie umsetzt? Bilden
  Release Notes Änderungen auf Kontroll-IDs ab?
- **Testmatrix**: welche OS-Versionen und Szenarien testet die CI?

#### Eine Rolle lesen, ohne sie auszuführen
Lies in dieser Reihenfolge. Die Defaults zeigen, welche Schalter es gibt und wie sie heißen;
`tasks/` zeigt die Struktur; eine Suche nach `command`, `shell` und `raw` findet die Tasks, die
von Idempotenz und Check-Modus nichts wissen; `meta/` zeigt Abhängigkeiten, die weitere Rollen
installieren; Handler zeigen Dienst-Neustarts. Danach lass Ansible sagen, was die Rolle tun
würde: `ansible-playbook site.yml --list-tasks --list-tags`, `--syntax-check` und `--check
--diff` gegen einen frisch zurückgesetzten Host (L14 erklärt die Grenzen des Check-Modus).

#### Bauen vs. übernehmen - ein typisches Fazit
Eine gepflegte Rolle zu übernehmen spart enormen Aufwand bei der Abdeckung; dein Beitrag
verlagert sich auf *Konfiguration* (welche Kontrollen, welche Ausnahmen), *Tests* (ein Lab wie
dieses) und *Betrieb* (Rollout, Berichte). Selbst bauen lohnt sich für kleine Umfänge,
ungewöhnliche Plattformen (wie hier Alpine) oder wenn du jede Zeile kontrollieren musst. Viele
Teams machen beides: übernehmen, in eine eigene Rolle für organisationsspezifische Einstellungen
und Berichte einbetten und Korrekturen upstream beisteuern.

#### Nie ungeprüft ausführen
Eine Härtungsrolle ist root-Code, der auf jedem Server Authentifizierung und Netzwerk anfasst.
Prüfe sie, wie du einen Kernel-Patch für Produktion prüfen würdest - dein Lab ist der Ort, das
gefahrlos zu tun.

### Gemessenes Beispiel: zwei ansible-lockdown-Rollen
Am 2026-11-07 im Code gelesen, bei den Tags `RHEL10-CIS` 1.1.2 (Commit
`71d291ea07be450aee602e858b7288452fb27b56`, 2026-10-16) und `UBUNTU24-CIS` 1.8.0 (Commit
`3a2f05b9a8040eb869fd14fdca882aae4f68733b`, 2026-10-22). Rollen entwickeln sich weiter: sieh
noch einmal nach, bevor du dich auf ein Detail verlässt. Das sind Fakten, keine Antworten auf
deine Fragen.
- **Schalter:** `RHEL10-CIS` hat 328 Variablen `rhel10cis_rule_*`, eine pro Regel, alle `true`,
  und sieben Abschnittsschalter `rhel10cis_section1` bis `7`; der Kommentar in den Defaults sagt,
  ein Regelschalter wirkt nur, solange sein Abschnitt an ist. Variablen wie
  `rhel10cis_avahi_server` oder `rhel10cis_nfs_server` sagen, ob *du* einen Dienst nutzt; die
  Entfernungs-Tasks greifen bei `not rhel10cis_avahi_server`, und mit dem Standard `true` für NFS
  tut die NFS-Kontrolle nichts.
- **Störung:** `rhel10cis_disruption_high: false` steht in 45 Task-Bedingungen, zum Beispiel bei
  den firewalld-Zonen (4.1.x) und den authselect-/PAM-Tasks (5.3.x).
- **Level und Profile:** jeder Task trägt Tags wie `level1-server` oder `level2-workstation`,
  und die README sagt, dass die Profile über Tags gesteuert werden; die Defaults haben
  `rhel10cis_level_1` und `_2`, die der Kommentar mit dem Audit verbindet.
- **Check-Modus:** die README beider Rollen sagt, die Rolle laufe im Check-Modus ohne Fehler
  durch, der Check-Modus sei aber nicht unterstützt.
- **Audit:** `run_audit` und `setup_audit` sind in beiden Rollen standardmäßig `false`
  (`audit_only` in `RHEL10-CIS`); die Prüfungen kommen aus einem separaten Audit-Repository und
  laufen mit einem kleinen Binary - `goss` in `UBUNTU24-CIS`, `syver` (ein signierter goss-Fork,
  der denselben Inhalt liest) in `RHEL10-CIS`.

### Unterschiede je Familie
Welche Lab-Plattform hat eine passende Rolle? Am 2026-11-07 nach Repository-Namen in der
Organisation `ansible-lockdown` geprüft (nicht erschöpfend: eine Rolle kann unter anderem Namen
existieren oder nicht öffentlich sein).

| os_family | Hosts | Community-Rolle gefunden | Hinweise |
|---|---|---|---|
| Debian | debian, ubuntu | `DEBIAN13-CIS` 1.1.0, `UBUNTU26-CIS` 0.9.0 | das Lab nutzt Debian 13 und Ubuntu 26.04; `UBUNTU24-CIS` 1.8.0 ist die ältere Ausgabe |
| RedHat | rocky, alma, fedora | `RHEL10-CIS` 1.1.2 | `meta/main.yml` nennt rocky und alma; für fedora keine Rolle gefunden |
| Suse | opensuse | keine gefunden | kein öffentliches Repository namens `SLES15-CIS`, `SLES16-CIS`, `SLE16-CIS` oder `OPENSUSE-CIS` |
| Archlinux | arch | keine gefunden | - |
| Alpine | alpine | keine gefunden | der Fall für eine eigene Rolle |

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Lösung |
|---|---|---|
| `lab check 5.03` vermisst Frage 3, obwohl du sie beantwortet hast | die Zeile beginnt nicht mit einer Zahl und `.`, `)` oder `:` (`## 3`, `**3.**`) | beginne die Zeile mit `3.` oder `## 3.` |
| `lab check 5.03` meldet "only N words" | die Review hat weniger als 300 Wörter | ergänze die Begründung, keinen Füllstoff |
| die Rolle "läuft" in `--check` und ändert im Enforce-Modus viel | der Check-Modus ist nicht unterstützt oder überspringt `command`-Tasks | lies die Tasks, verlass dich nicht allein auf den Trockenlauf |
| ein Regelschalter wirkt nicht | sein Abschnittsschalter ist aus | beide setzen |
| eine Kontrolle tut standardmäßig nichts | die Variable nennt einen Dienst, den du nutzt (`..._nfs_server: true`) | lies, was der Standard bedeutet, bevor du "reparierst" |

### Praxis-Hinweise
- Pinne die Rolle auf einen Tag oder Commit und lies den Diff jedes Updates; Benchmarks und
  Rollen ziehen auf neue Versionen um.
- Ein Fork braucht eine Merge-Routine; eine übernommene Rolle braucht einen Platz für deine
  Ausnahmen (eine Wrapper-Rolle oder Inventar-Variablen).
- Deine Abnahmetests sind die Lab-Idee im Großen: ein Wegwerf-Host pro Plattform,
  Check-Modus plus unabhängiges Audit, dann ein Canary.

### Weiterführend
- Lektion [L14 - Production rollout](../../../docs/lessons/L14-production-rollout.de.md): woher Community-Rollen kommen, Pinning, eine Rolle lesen ohne sie auszuführen, übernehmen, forken oder bauen.
- Lektion [L01 - CIS Benchmarks](../../../docs/lessons/L01-cis-benchmarks.de.md): Level, Profile und warum sich Empfehlungsnummern verschieben.
- Lektion [L11 - Profiles, exceptions and data-driven roles](../../../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.de.md): das Ausnahme-Design, mit dem du vergleichst.

## Musterlösung

Anzeigen mit `lab solution 5.03`, anwenden mit `lab solve 5.03`.
