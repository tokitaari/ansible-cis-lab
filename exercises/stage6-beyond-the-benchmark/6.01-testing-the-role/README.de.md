# 6.01 - Eine Rolle testen: Molecule-Szenario mit testinfra

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 6 - Über den Benchmark hinaus | ★★★★☆ | ~90 Min. | - (-) | `targets` |

**Konzepte:** `Molecule scenario`, `default driver`, `test sequence`, `testinfra`, `expected values from the requirements`

## Ziel

Schreibe ein Molecule-Szenario mit testinfra-Tests für die kleine Rolle `cis_mini`, führe es gegen die acht Lab-Targets aus und bring `molecule test` zum Bestehen - indem du die Rolle korrigierst, wo das Szenario einen Fehler findet, nicht indem du die Tests schwächer machst.

## Hintergrund

Jemand aus dem Team hat `cis_mini` geschrieben - drei Kontrollen, die du aus den Stufen 1 und 2
kennst - und meldet sie als fertig. Bevor sie in die echte Rolle wandert, bekommt sie Tests:
Molecule führt die Rolle aus, führt sie ein zweites Mal aus, um zu sehen, dass sich nichts ändert,
dann liest testinfra den Zustand jedes Hosts und vergleicht ihn mit dem, was die Rolle erreichen
muss. `lab start 6.01` kopiert die Rolle nach `/lab/work/roles/cis_mini`.

Das sind die Anforderungen an die Rolle - schreibe deine Tests nach dieser Tabelle:

| | Dateien | Eigentümer | Gruppe und Modus |
|---|---|---|---|
| R1 | `/etc/passwd`, `/etc/group` | root | root, 0644 |
| R2 | `/etc/shadow` und `/etc/gshadow`, wo es sie gibt | root | Debian, Suse, Alpine: shadow, 0640 · RedHat: root, 0000 · Archlinux: root, 0600 |
| R3 | `/etc/issue`, `/etc/issue.net` | root | root, 0644; der Inhalt ist genau der Text von `cis_mini_banner` und ein Zeilenumbruch |

Die üblichen Driver von Molecule legen Testmaschinen an und werfen sie wieder weg. Das Lab hat
schon acht, darum nimmt das Szenario den Driver `default` und zeigt auf sie. Molecule führt
Ansible dann mit einer eigenen Konfiguration aus - Lektion L18 erklärt, was dabei verloren geht
und wie du es zurückholst. Lies sie zuerst.

## Anforderungen

- [ ] Ein Szenario `default` in `/lab/work/6.01/molecule/default/` wendet die Rolle `cis_mini` aus `/lab/work/roles` auf die acht Hosts des Lab-Inventars an (Gruppe `targets`).
- [ ] Seine Testsequenz führt `converge`, `idempotence` und `verify` aus, in dieser Reihenfolge. Der Verifier ist testinfra, mit den Tests in `molecule/default/tests/test_*.py`.
- [ ] Die Tests decken R1, R2 und R3 auf jedem Target ab. Ihre Sollwerte stammen aus der Tabelle oben, nicht aus den Dateien der Rolle.
- [ ] `molecule test` besteht in `/lab/work/6.01`. Wo die Rolle eine Anforderung nicht erfüllt, korrigierst du die Rolle in `/lab/work/roles/cis_mini` - die Tests bleiben streng.
- [ ] Ein Test scheitert auf einem Target, das eine Anforderung verletzt, und keiner auf den anderen: `lab check 6.01` verletzt absichtlich auf sechs Targets je eine Anforderung, führt `molecule verify` aus und stellt sie danach wieder her.

## Vorgehen

```bash
lab start 6.01            # legt /lab/work/6.01/ an und kopiert die Rolle nach /lab/work/roles/cis_mini
cd /lab/work/6.01
# molecule/default/molecule.yml, converge.yml und tests/test_*.py schreiben, dann:
molecule converge         # nur der Lauf der Rolle
molecule verify           # nur die Tests, gegen den Zustand, den die Targets jetzt haben
molecule test             # die ganze Sequenz
lab check 6.01            # molecule test, die Anforderungen, dann sechs kaputte Targets (~3 Min.)
```

Festgefahren? `lab hint 6.01 1` (sanft) ... `lab hint 6.01 3` (fast die Lösung).  
Bestanden? Lies `lab explain 6.01` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Schreibe dieselben Prüfungen ein zweites Mal mit dem Ansible-Verifier von Molecule (`verifier: name: ansible` und eine `verify.yml` mit `ansible.builtin.assert`) in einem zweiten Szenario und führe es mit `molecule test -s <name>` aus. Vergleiche die Fehlermeldungen mit denen von testinfra.
- Lege ein Szenario `cis` an, das deine 5.01-Rolle aus `/lab/work/roles/cis` im Enforce-Modus anwendet, und teste drei ihrer Kontrollen mit testinfra. Wie lange dauert dort der Idempotenz-Schritt, verglichen mit `cis_mini`?
- Das Tag `molecule-idempotence-notest` hält einen Task aus dem Idempotenz-Schritt heraus. Finde einen Task in deiner 5.01-Rolle, bei dem das richtig wäre - und einen, bei dem es nur einen Fehler verstecken würde.
- Verletze eine Anforderung in einem `side_effect`-Playbook statt von Hand, und gib einem zweiten Szenario die Sequenz `converge`, `side_effect`, `verify`. Was muss `molecule test -s <name>` dann melden?
