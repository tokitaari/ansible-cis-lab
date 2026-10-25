# 2.02 - SSH-Server-Härtung mit Jinja2-Template

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 2 - Bausteine | ★★★☆☆ | ~45 Min. | 5.1 SSH server (L1) | `targets` |

**Konzepte:** `template`, `variables`, `join filter`, `ansible_managed`, `full-config validation`

## Ziel

Ersetze das handgeschriebene Drop-in aus 1.03 durch ein Template, das den ganzen CIS-SSH-Abschnitt aus Variablen umsetzt.

## Hintergrund

CIS 5.1 hat rund zwanzig SSH-Empfehlungen. Hart codiert funktioniert das einmal; ein
Template mit Variablen erlaubt es unterschiedlichen Umgebungen (oder Ausnahmen),
denselben Code zu nutzen. Die Zielwerte in diesem Lab:

| Einstellung | Wert | Warum |
|---|---|---|
| `LogLevel` | `VERBOSE` | protokolliert Schlüssel-Fingerabdrücke beim Login |
| `MaxAuthTries` | `4` | begrenzt Brute Force pro Verbindung |
| `MaxSessions` / `MaxStartups` | `10` / `10:30:60` | begrenzt Ressourcenerschöpfung |
| `LoginGraceTime` | `60` | nicht authentifizierte Verbindungen fliegen raus |
| `ClientAliveInterval` / `CountMax` | `15` / `3` | tote Sitzungen enden nach ~45 s ohne Antwort |
| `DisableForwarding` | `yes` | kein TCP-/Agent-/X11-Forwarding |
| `IgnoreRhosts` / `HostbasedAuthentication` | `yes` / `no` | keine Vertrauensbeziehungen |
| `PermitUserEnvironment` | `no` | Benutzer können kein `LD_PRELOAD` usw. einschleusen |
| `Banner` | `/etc/issue.net` | das Banner aus 0.04 |
| `AllowGroups` | `ansible` | explizite Positivliste |
| `Ciphers`/`MACs`/`KexAlgorithms` | nur moderne | kein CBC, kein SHA-1, kein MD5 |

## Anforderungen

- [ ] Template `templates/sshd_cis.conf.j2`, gerendert nach `/etc/ssh/sshd_config.d/00-cis-hardening.conf` (`root:root`, `0600`).
- [ ] Alle Werte stammen aus Variablen (siehe Tabelle); Listen werden im Template verbunden.
- [ ] Die erste Zeile ist der `ansible_managed`-Kommentar.
- [ ] Das gerenderte Fragment mit `sshd -t -f %s` validieren und sshd per Handler neu laden.
- [ ] **Nach** dem Ausrollen die *gesamte* Konfiguration mit `sshd -t` (ohne `-f`) prüfen und das Play bei Fehlern abbrechen.
- [ ] `sshd -T` zeigt alle Werte auf allen Hosts; Ansible kommt weiterhin drauf (Vorsicht mit `AllowGroups`!).

## Vorgehen

```bash
lab start 2.02            # legt /lab/work/2.02/ an
cd /lab/work/2.02
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 2.02            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 2.02 1` (sanft) ... `lab hint 2.02 3` (fast die Lösung).  
Bestanden? Lies `lab explain 2.02` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Vor dem Ausführen: Welche dieser Einstellungen könnten *dich* aussperren? Warum ist der Lab-Benutzer sicher?
- Mit `--diff` ansehen, wie sich das Template von der 1.03-Datei unterscheidet.
- Red-Hat-Systeme haben zusätzlich *crypto-policies*. Warum gewinnen deine `Ciphers` trotzdem? (Tipp: `cat /etc/ssh/sshd_config.d/50-redhat.conf`)
