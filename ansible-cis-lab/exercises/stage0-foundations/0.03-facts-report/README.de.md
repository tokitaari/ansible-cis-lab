# 0.03 - Facts: ein Bericht über acht Distributionen

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 0 - Grundlagen | ★★☆☆☆ | ~30 Min. | - (-) | `targets` |

**Konzepte:** `facts`, `hostvars`, `template`, `delegation to localhost`

## Ziel

Sammle die Facts, die Multi-Distro-Automatisierung steuern, und schreibe sie als CSV auf den Control Node.

## Hintergrund

Bevor du etwas härtest, musst du wissen, *was* du härtest. Facts wie `os_family`,
`pkg_mgr` und `service_mgr` entscheiden, welche Paketnamen, Pfade und Dienstbefehle
gelten. Genau diese Facts nutzt du in jeder späteren Aufgabe.

## Anforderungen

- [ ] Sammle Facts von allen Targets (vorher 0.02 erledigen, damit Alpine Python hat).
- [ ] Erzeuge `/lab/work/0.03/facts.csv` auf dem Control Node mit genau diesem Kopf:
  `host,distribution,version,os_family,pkg_mgr,service_mgr,python`
- [ ] Eine Zeile pro Target (8 Datenzeilen), Werte aus den Facts.
- [ ] Nutze `ansible.builtin.template` und `hostvars` - kein Shell-`echo >>`.

## Vorgehen

```bash
lab start 0.03            # legt /lab/work/0.03/ an
cd /lab/work/0.03
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 0.03            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 0.03 1` (sanft) ... `lab hint 0.03 3` (fast die Lösung).  
Bestanden? Lies `lab explain 0.03` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Mach den Bericht robust: ein nicht erreichbarer Host soll `unreachable` zeigen statt das Template abstürzen zu lassen.
- Sortiere die Zeilen nach `os_family`, dann nach Host.
