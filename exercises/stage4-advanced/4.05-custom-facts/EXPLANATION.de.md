# 4.05 - Custom Facts: Hosts beschreiben ihre eigene Härtung: Erklärung

### Statische vs. ausführbare Facts
| | statisches `.fact` | ausführbares `.fact` |
|---|---|---|
| Inhalt | JSON/INI, von Ansible geschrieben | Skriptausgabe |
| beantwortet | "was haben wir angewendet?" | "was gilt gerade?" |
| Kosten | keine | läuft bei *jedem* Faktensammeln |

### Keine Zeitstempel
`"last_run": "{{ now() }}"` ändert die Datei bei jedem Lauf → nie `changed=0`, und deine
Drift-Berichte werden zu Rauschen. Wenn du eine Laufhistorie brauchst, schick sie in ein
Log oder den Bericht auf dem Control Node, nicht in verwalteten Zustand.

### Facts laufen als root
Das Sammeln der Facts läuft mit den Rechten des Plays (hier `become: true`). Deshalb kann
der ausführbare Fact `sshd -T` aufrufen. Es heißt aber auch: ein beschreibbares `facts.d`
= Codeausführung als root beim nächsten Ansible-Lauf. `0755 root:root` beibehalten.

### Nutzung
`ansible targets -m ansible.builtin.setup -a filter=ansible_local` zeigt die Daten. In
AWX/AAP werden diese Facts pro Host gespeichert (Fact-Caching) und können Smart
Inventories steuern, etwa "alle Hosts mit `ansible_local.cis.version` < 1.0.0".

## Musterlösung

Anzeigen mit `lab solution 4.05`, anwenden mit `lab solve 4.05`.
