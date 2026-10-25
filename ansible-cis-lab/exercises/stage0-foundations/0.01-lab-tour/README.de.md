# 0.01 - Rundgang: Inventar und Erreichbarkeit

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 0 - Grundlagen | ★☆☆☆☆ | ~15 Min. | - (-) | `targets` |

**Konzepte:** `inventory`, `groups`, `ad-hoc`, `ping`

## Ziel

Lerne die Umgebung kennen: welche Hosts es gibt, wie sie gruppiert sind und ob Ansible sie verwalten kann.

## Hintergrund

Ansible braucht auf einem verwalteten Knoten zwei Dinge: SSH-Zugang und einen
Python-Interpreter. Das Inventar (`/lab/ansible/inventory/hosts.yml`) gruppiert die
acht Targets nach OS-Familie - genau die Dimension, die Multi-Distro-Härtung spannend
macht. Jedes Härtungsprojekt beginnt mit dieser Frage: *Was verwalte ich, und erreiche ich es?*

## Anforderungen

- [ ] Zeige das Inventar als Baum an (`ansible-inventory --graph`).
- [ ] Zeige alle Variablen, die Ansible für den Host `debian` kennt (`ansible-inventory --host debian`).
- [ ] Führe das Modul `ansible.builtin.ping` per Ad-hoc-Kommando gegen alle Targets aus.
- [ ] Genau ein Host schlägt fehl. Finde heraus welcher und *warum* (Fehlermeldung lesen!). Noch nicht beheben - das ist 0.02.
- [ ] Halte deine Erkenntnisse in `/lab/work/0.01/notes.md` fest (wird nicht geprüft).

## Vorgehen

```bash
lab start 0.01
ansible-inventory --graph
ansible all -m ansible.builtin.ping      # oder: ansible targets -m ...
lab check 0.01
```
Festgefahren? `lab hint 0.01 1`. Bestanden? `lab explain 0.01`.


## Bonus (optional)

- Führe `ansible targets -m ansible.builtin.setup -a 'filter=ansible_distribution*'` aus und vergleiche die Hosts.
- Welches Ad-hoc-Modul funktioniert auf *jedem* Host, auch dem fehlerhaften? (Tipp: es braucht kein Python.)
