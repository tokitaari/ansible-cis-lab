# 4.02 - Profile (Level 1/2) und dokumentierte Ausnahmen

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★☆ | ~75 Min. | framework (L1/L2) | `debian` |

**Konzepte:** `variable-driven scoping`, `input validation`, `to_datetime / now()`, `contract testing`

## Ziel

Baue den Kontrollmechanismus, den jede echte Härtungsrolle braucht: einen Profilschalter (Level 1/2) und eine Ausnahmeliste mit Begründung und Ablaufdatum, die vor jedem Lauf validiert wird.

## Hintergrund

Keine Organisation setzt 100 % eines Benchmarks um. Was ein reifes Setup von Chaos
unterscheidet, ist *wie* Abweichungen behandelt werden: aufgeschrieben, begründet, mit
Verantwortlichem und mit Ablaufdatum. Das setzt du für vier Kontrollen um. Der Check
testet deine Umsetzung als Blackbox, daher braucht es einen kleinen **Vertrag**:

| Vertragspunkt | Wert |
|---|---|
| Playbook | `/lab/work/4.02/site.yml` (Struktur beliebig, Rolle empfohlen) |
| Variablen | `cis_level` (1 oder 2, Default 1), `cis_exceptions` (Liste von `{id, reason, expires}`, Default `[]`) |
| Kontroll-IDs | `l1-telnet`, `l1-ssh-maxauthtries`, `l2-modules`, `l2-audit-identity` |
| Task-Namen | jeder Task einer Kontrolle **beginnt mit ihrer ID** (Groß-/Kleinschreibung egal; ansible-lint will großgeschriebene Namen), z. B. `L1-telnet \| Remove telnet` |
| Validierung | ungültige Eingaben (unbekannte ID, leere Begründung, fehlendes oder vergangenes `expires`) lassen den Lauf scheitern, bevor eine Kontrolle läuft |

Inhalt der Kontrollen (klein halten, es geht um den Mechanismus): telnet entfernen ·
Drop-in `MaxAuthTries 4` (`/etc/ssh/sshd_config.d/01-cis-maxauthtries.conf`) · `squashfs`
und `udf` deaktivieren · Audit-Regeldatei für Identitätsdateien.

## Anforderungen

- [ ] Level-2-Kontrollen laufen nur bei `cis_level >= 2`.
- [ ] Eine Kontrolle, deren ID in `cis_exceptions` steht, wird übersprungen - und der Lauf gibt aus, welche Kontrollen mit welcher Begründung und welchem Ablaufdatum ausgenommen sind.
- [ ] Validierung wie im Vertrag beschrieben (nutze `to_datetime('%Y-%m-%d')` und `now()`).
- [ ] `lab check 4.02` startet dein Playbook fünfmal im `--check`-Modus gegen `debian` mit unterschiedlichen Eingaben und prüft, welche Tasks liefen - es ändert nichts.

## Vorgehen

```bash
lab start 4.02            # legt /lab/work/4.02/ an
cd /lab/work/4.02
# site.yml schreiben, dann ausführen:
ansible-playbook site.yml
lab check 4.02            # prüft den Zustand
```

Festgefahren? `lab hint 4.02 1` (sanft) ... `lab hint 4.02 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.02` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Mach `approved_by` zum Pflichtfeld. Wo würdest du Ausnahmen in einer echten Umgebung ablegen (host_vars? eigenes YAML in Git? CMDB?) - und wer darf diese Datei ändern?
- Ablaufende Ausnahmen sollen 30 Tage vorher warnen. Setze eine Warnung um (kein Fehler).
