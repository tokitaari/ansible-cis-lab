# 3.02 - Passwortalterung und inaktive Konten

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 3 - Mittelstufe | ★★★☆☆ | ~45 Min. | 5.4.1 Shadow password suite parameters (L1) | `targets` |

**Konzepte:** `lineinfile`, `regexp`, `slurp + regex_findall`, `vendor config split`, `command idempotency`

## Ziel

Setze Passwortalterungs-Defaults in `login.defs`, ein starkes Hash-Verfahren und automatisches Sperren inaktiver Konten - ohne Systeme kaputt zu machen, die schon etwas Stärkeres nutzen.

## Hintergrund

CIS 5.4.1 (hier verwendete Werte):

| Einstellung | Wert | Datei |
|---|---|---|
| `PASS_MAX_DAYS` | `365` (≤ 365) | `/etc/login.defs` |
| `PASS_MIN_DAYS` | `1` (≥ 1) | `/etc/login.defs` |
| `PASS_WARN_AGE` | `7` (≥ 7) | `/etc/login.defs` |
| `ENCRYPT_METHOD` | `SHA512` **oder** `YESCRYPT` | `/etc/login.defs` |
| Inaktiv-Sperre | `45` Tage (≤ 45) | `useradd -D -f 45` → `/etc/default/useradd` |

Zwei Fallen:
1. **Nicht abschwächen.** Debian 13, Fedora und Arch nutzen bereits `YESCRYPT`. Das mit
   `SHA512` zu überschreiben wäre *schwächer*. Nur ändern, wenn das aktuelle Verfahren
   keins von beiden ist.
2. **Vendor-Konfiguration getrennt.** Manche Distributionen (besonders openSUSE)
   verlagern Defaults nach `/usr/etc/` und lesen Überschreibungen aus
   `/etc/login.defs.d/*.defs`. Existiert `/etc/login.defs` nicht, würde Anlegen alle
   Vendor-Defaults *ersetzen*. Dann ein Drop-in nutzen. Finde heraus, welcher Host wie tickt.

## Anforderungen

- [ ] Playbook `/lab/work/3.02/playbook.yml` für `targets` (die Tasks zusätzlich als `section5_password_policy.yml` mit Tag `password` in deine Rolle aufnehmen).
- [ ] Wo `/etc/login.defs` existiert: die drei `PASS_*`-Werte per `lineinfile` setzen (ein Task, Schleife).
- [ ] Wo nicht: dieselben Werte nach `/etc/login.defs.d/50-cis.defs` schreiben.
- [ ] `ENCRYPT_METHOD` wird nur dann `SHA512`, wenn es aktuell weder `SHA512` noch `YESCRYPT` ist.
- [ ] Inaktiv-Sperre 45 Tage per `useradd -D -f 45` - der Task meldet nur `changed`, wenn er wirklich etwas geändert hat.
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 3.02            # legt /lab/work/3.02/ an
cd /lab/work/3.02
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 3.02            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 3.02 1` (sanft) ... `lab hint 3.02 3` (fast die Lösung).  
Bestanden? Lies `lab explain 3.02` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Die neuen Defaults gelten nur für *neue* Konten. Schreib einen Task, der `PASS_MAX_DAYS` auf bestehende Benutzer mit Passwort-Hash anwendet (`chage --maxdays`). Tipp: `/etc/shadow` parsen; gesperrte (`!`/`*`) Einträge überspringen.
- Ist `lineinfile` das richtige Werkzeug für 3 Schlüssel? Vergleiche mit einem Template-Drop-in auf allen Systemen.
