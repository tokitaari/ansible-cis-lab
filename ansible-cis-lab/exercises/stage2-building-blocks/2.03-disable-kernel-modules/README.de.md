# 2.03 - Unnötige Kernelmodule deaktivieren

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 2 - Bausteine | ★★☆☆☆ | ~30 Min. | 1.1.1 Kernel modules / 3.2 Network kernel modules (L1/L2) | `targets` |

**Konzepte:** `loop`, `copy per item`, `modprobe.d`, `container limits`

## Ziel

Verhindere, dass selten genutzte Dateisystem- und Protokollmodule geladen werden - jedes Modul mit eigener `modprobe.d`-Datei.

## Hintergrund

Jedes ladbare Modul ist Kernelcode, den ein Angreifer auslösen kann (z. B. durch einen
präparierten USB-Stick oder einen exotischen Socket). CIS deaktiviert Module, die
Server selten brauchen. Zwei Zeilen pro Modul:

```
install <modul> /bin/false   # Laden scheitert
blacklist <modul>            # kein automatisches Laden per Alias
```

**Container-Hinweis:** Alle Container teilen sich den Kernel des HOSTS. Im Lab schreibst
du nur die Konfiguration - du darfst **kein** `modprobe -r` ausführen (das würde Module
aus deinem Host entladen). Lies `docs/CONTAINER_LIMITS.md`.

## Anforderungen

- [ ] Variable `cis_disabled_modules_l1`: `cramfs`, `freevxfs`, `hfs`, `hfsplus`, `jffs2`, `usb-storage`.
- [ ] Eine Datei pro Modul: `/etc/modprobe.d/cis-<modul>.conf`, Inhalt genau die zwei Zeilen oben, `root:root`, `0644`.
- [ ] Nutze einen einzigen Task mit `loop`.
- [ ] Kein `modprobe -r`, kein `rmmod`.

## Vorgehen

```bash
lab start 2.03            # legt /lab/work/2.03/ an
cd /lab/work/2.03
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 2.03            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 2.03 1` (sanft) ... `lab hint 2.03 3` (fast die Lösung).  
Bestanden? Lies `lab explain 2.03` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Ergänze eine Liste `cis_disabled_modules_l2` (`squashfs`, `udf`, `dccp`, `tipc`, `rds`, `sctp`) und eine Variable `cis_level` (Standard 1). Level-2-Module werden nur bei `cis_level >= 2` behandelt. Tipp: `cis_disabled_modules_l1 + (cis_disabled_modules_l2 if cis_level | int >= 2 else [])`.
- Auf einer echten VM würdest du geladene Module auch entladen. Schreib diesen Task, schütze ihn aber mit `when: not lab_in_container` (Variable ist im Inventar bereits definiert).
- Warum kann das Deaktivieren von `squashfs` Ubuntu-Systeme kaputt machen? (Denk an Snaps.)
