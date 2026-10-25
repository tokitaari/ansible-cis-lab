# 1.04 - FTP-Server stoppen und deaktivieren

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 1 - Einsteiger | ★★☆☆☆ | ~25 Min. | 2.1 Server services (L1) | `targets` |

**Konzepte:** `service`, `package_facts`, `when`, `systemd vs OpenRC`

## Ziel

`vsftpd` ist auf den meisten Targets installiert und aktiviert. Sorge dafür, dass er weder läuft noch beim Booten startet.

## Hintergrund

Jeder lauschende Dienst ist Angriffsfläche. CIS: nicht benötigte Dienste werden
entfernt oder mindestens gestoppt und deaktiviert/maskiert. `ansible.builtin.service`
abstrahiert systemd *und* OpenRC - ein Task für alle acht Hosts. Aber: auf einem Host
ohne `vsftpd` schlägt das service-Modul fehl ("Could not find the requested service").
Das ist deine erste echte Bedingung.

## Anforderungen

- [ ] Auf jedem Host mit dem Paket `vsftpd`: Dienst gestoppt und nicht aktiviert.
- [ ] Hosts ohne `vsftpd` werden übersprungen, nicht als Fehler gewertet.
- [ ] Nutze `ansible.builtin.package_facts` + `when`.
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 1.04            # legt /lab/work/1.04/ an
cd /lab/work/1.04
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 1.04            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 1.04 1` (sanft) ... `lab hint 1.04 3` (fast die Lösung).  
Bestanden? Lies `lab explain 1.04` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- CIS bevorzugt das *Entfernen* des Pakets. Ergänze einen zweiten Task, der `vsftpd` entfernt. Warum ist die Reihenfolge der beiden Tasks hier egal - oder ist sie es nicht?
- Nur systemd-Hosts: `masked: true` (braucht `ansible.builtin.systemd_service`). Was ist der Unterschied zu `enabled: false`?
