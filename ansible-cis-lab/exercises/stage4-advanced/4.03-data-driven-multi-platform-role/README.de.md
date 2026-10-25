# 4.03 - Datengetriebene Rolle für alle Plattformen (inkl. Alpine)

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★☆ | ~120 Min. | Sections 1-7 (L1 (+L2 auditd)) | `targets` |

**Konzepte:** `first_found variable hierarchy`, `feature flags instead of os_family checks`, `Alpine/OpenRC`, `regression testing`

## Ziel

Integriere Stufe 3 (Passwortrichtlinie, PAM, Konten, auditd) so in deine Rolle `cis`, dass sie auf allen acht Plattformen läuft - mit **null** `os_family ==`-Bedingungen in den Task-Dateien.

## Hintergrund

Jedes `when: ansible_facts.os_family == 'Debian'` in einer Task-Datei ist eine kleine
Schuld: die nächste Plattform heißt, Logik zu bearbeiten. Ausgereifte Rollen drücken
Plattformunterschiede als **Daten und Feature-Flags** aus:

```yaml
# vars/Alpine.yml
cis_pam_tool: none           # statt: when: os_family != 'Alpine'
cis_pwquality_supported: false
cis_cron_allow_supported: false
```
Tasks stellen dann *Fähigkeitsfragen*: `when: cis_pwquality_supported`.

Ein vierstufiger Lookup erlaubt Überschreibungen pro Distribution und Version ohne
Kopieren: `Rocky-10.yml` → `Rocky.yml` → `RedHat.yml` → `default.yml`.

## Anforderungen

- [ ] Erweitere `/lab/work/roles/cis` um `section5_password_policy.yml` (3.02), `section5_pam.yml` (3.03), `section5_accounts.yml` (3.05), `section6_logging.yml` (3.04, nur bei `cis_level >= 2`).
- [ ] Plattform-vars werden per `first_found` über `<distribution>-<major>.yml`, `<distribution>.yml`, `<os_family>.yml`, `default.yml` geladen.
- [ ] Keine Task-Datei unter `tasks/` enthält `os_family ==`, `os_family !=`, `distribution ==` oder ähnliche Fact-Vergleiche - nutze Flags/Werte aus `vars/`.
- [ ] `/lab/work/4.03/site.yml` bootstrapt Python auf Alpine (vorgeschaltetes Play) und wendet die Rolle auf alle Targets an.
- [ ] Nach **einem** Lauf auf frisch zurückgesetzten Hosts (`./lab.sh reset all`) bestehen die Checks von 0.04-2.06 sowie 3.02, 3.03, 3.05; mit `-e cis_level=2` auch 3.04. Zweiter Lauf: `changed=0`.
- [ ] `ansible-lint --offline` besteht auf der Rolle.

## Vorgehen

```bash
lab start 4.03            # legt /lab/work/4.03/ an
cd /lab/work/4.03
# site.yml schreiben, dann ausführen:
ansible-playbook site.yml
lab check 4.03            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.03 1` (sanft) ... `lab hint 4.03 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.03` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Lege `vars/Ubuntu.yml` an, das nur einen Wert überschreibt (z. B. `cis_cron_allow_supported` testweise abschaltet), und beweise mit `debug`, dass Debian weiter `Debian.yml` nutzt. Danach wieder löschen.
- Füge auf dem Papier eine neunte Plattform hinzu: was bräuchte ein `vars/Gentoo.yml`? Welche Tasks würden trotzdem brechen?
