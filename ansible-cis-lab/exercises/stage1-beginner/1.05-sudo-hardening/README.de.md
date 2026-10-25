# 1.05 - sudo: PTY erzwingen und in Datei protokollieren

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 1 - Einsteiger | ★★☆☆☆ | ~25 Min. | 5.2 Configure privilege escalation (L1) | `targets` |

**Konzepte:** `sudoers.d`, `validate: visudo`, `lockout prevention`

## Ziel

Konfiguriere sudo so, dass Befehle in einem Pseudo-Terminal laufen und jede sudo-Nutzung in `/var/log/sudo.log` protokolliert wird.

## Hintergrund

`use_pty` verhindert, dass ein per sudo gestarteter Hintergrundprozess nach Ende des
Befehls Tastendrücke in dein Terminal einschleust. Ein eigenes sudo-Log macht die
Nutzung von Privilegien nachvollziehbar (Stufe 3 ergänzt eine Audit-Regel darauf).

**Gefahr:** Ein Syntaxfehler in sudoers macht sudo kaputt - und Ansible nutzt sudo, um
root zu werden. Du würdest dich auf allen Hosts gleichzeitig aussperren. `visudo -cf`
prüft eine Datei, bevor sie installiert wird. (Falls es doch passiert: `./lab.sh reset <host>`.)

## Anforderungen

- [ ] Lege `/etc/sudoers.d/50-cis` mit `Defaults use_pty` und `Defaults logfile="/var/log/sudo.log"` an.
- [ ] Eigentümer `root:root`, Modus `0440`.
- [ ] Vor der Installation mit `visudo -cf %s` validieren.
- [ ] `visudo -c` meldet auf dem Host keine Fehler, und Ansible kann weiterhin root werden.

## Vorgehen

```bash
lab start 1.05            # legt /lab/work/1.05/ an
cd /lab/work/1.05
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 1.05            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 1.05 1` (sanft) ... `lab hint 1.05 3` (fast die Lösung).  
Bestanden? Lies `lab explain 1.05` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Mach es absichtlich kaputt: Tippfehler einbauen, mit `-l debian` ausführen. Was meldet Ansible, und ist der Host noch verwaltbar?
- Ergänze `Defaults timestamp_timeout=15`. Was steuert das?
