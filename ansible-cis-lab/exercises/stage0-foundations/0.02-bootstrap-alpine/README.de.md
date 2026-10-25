# 0.02 - Python auf Alpine per raw nachrüsten

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 0 - Grundlagen | ★☆☆☆☆ | ~20 Min. | - (-) | `alpine_family` |

**Konzepte:** `raw`, `gather_facts: false`, `changed_when`, `become`

## Ziel

Mache den Alpine-Host verwaltbar, indem du Python mit dem einzigen Modul installierst, das ohne Python auskommt.

## Hintergrund

`ansible.builtin.raw` führt einen Befehl per SSH aus, ganz ohne Python auf dem Ziel.
Das ist der Standardweg, minimale Systeme zu bootstrappen. Da `raw` nicht melden kann,
ob es etwas geändert hat, musst *du* das Ansible per `changed_when` sagen - sonst zeigt
jeder Lauf "changed" und das Playbook ist nicht idempotent.

## Anforderungen

- [ ] Schreibe `playbook.yml` mit einem Play für `alpine_family`.
- [ ] Schalte das Sammeln von Facts ab (Facts brauchen Python!).
- [ ] Installiere `python3` mit `apk` über `ansible.builtin.raw` - nur wenn es fehlt.
- [ ] Der Task darf nur dann `changed` melden, wenn er wirklich etwas installiert hat.
- [ ] Beweise, dass es funktioniert: ein zweiter Task führt `ansible.builtin.ping` aus.

## Vorgehen

```bash
lab start 0.02            # legt /lab/work/0.02/ an
cd /lab/work/0.02
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 0.02            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 0.02 1` (sanft) ... `lab hint 0.02 3` (fast die Lösung).  
Bestanden? Lies `lab explain 0.02` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Warum ist `become: true` nötig, und wie geht `raw` damit um?
- Sicherheitssicht: Jedes Paket ist Angriffsfläche. Welche Alternative käme ganz ohne Python auf dem Host aus? (Überlege, was Ansible nur mit `raw` könnte.)
