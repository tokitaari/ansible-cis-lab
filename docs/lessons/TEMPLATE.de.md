# LNN - Titel der Lektion

*[English](TEMPLATE.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| x.yy, x.yy | n.n, n.n | ~20 Min. | L00 |

<!--
Vorlage für die Selbstlern-Lektionen in docs/lessons/. Nach LNN-slug.md und LNN-slug.de.md
kopieren (NN = zwei Ziffern, slug = Kleinbuchstaben-Wörter mit '-'), dann jeden kursiven
Platzhalter ersetzen. tools/static-check.sh lessons prüft die Struktur:

- Zeile 1 ist '# LNN - <Titel>' mit NN aus dem Dateinamen, dann die Sprachumschaltung,
  dann die Kopftabelle oben (gleiche Werte in EN und DE, nur die Zeiteinheit unterscheidet sich)
- Übungen: Übungs-IDs, sortiert, kommagetrennt, oder '-'; genau diese IDs stehen auch in der
  Tabelle des Abschnitts Übungen
- CIS-Abschnitte: IDs aus cis/controls.yml, sortiert, kommagetrennt, oder '-'
- Lesezeit: '~N Min.' (EN '~N min'), Ziel 15-30 Minuten
- Baut auf: frühere, vorhandene Lektionen (L00, L03), sortiert, oder '-'
- genau die acht '##'-Abschnitte dieser Vorlage, in dieser Reihenfolge, mit diesen Titeln;
  darin nach Bedarf '###' und tiefer
- Selbstkontrolle: nummerierte Fragen, jeweils gefolgt von genau einem eingeklappten details-Block mit
  der Summary 'Antwort' (EN 'Answer')

Schreibregeln:
- Eine Lektion erklärt Konzepte VOR den Übungen. Nie die Referenzlösung einer Übung oder
  eine Lösung ihrer Anforderungen zeigen - dafür ist EXPLANATION.md da.
- Beispiele sind klein und generisch (ein Task, eine Hostgruppe) und anders als die Lösung.
- CIS: nur eigene Formulierungen, nie Benchmark-Text. Empfehlungen über die Abschnitts-IDs
  aus cis/controls.yml benennen; exakte Nummern unterscheiden sich je Benchmark und Version.
- Plattformwerte wie in den Facts: os_family Debian, RedHat, Suse, Alpine, Archlinux.
- Getaggte Code-Blöcke (yaml, bash) enthalten in EN und DE denselben Code, inklusive
  Task-'name:'-Werten (bleiben englisch); nur '#'-Kommentare werden übersetzt.
- Jeder relative Link muss auflösen (static-check links); Übungen auf ihre README.de.md verlinken.
- Das details-Tag nur in der Selbstkontrolle schreiben: eine Ansicht mit ausgeblendeten Antworten
  schneidet vom ersten öffnenden bis zum nächsten schließenden Tag, auch in diesem Kommentar.
-->

*Ein oder zwei Sätze: welches Problem diese Lektion löst und warum es für die Härtung zählt.*

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] *Verb + Konzept, z. B. erklären, warum ...*
- [ ] *Verb + Konzept, z. B. zwischen ... und ... wählen*
- [ ] *Verb + Konzept, z. B. vorhersagen, was `--check` für ... meldet*

## Theorie

### Konzept 1

*Zuerst das Problem, dann der Ansible-Mechanismus, der es löst, dann ein Minimalbeispiel.*

```yaml
- name: Minimal example of the mechanism
  hosts: targets
  tasks:
    - name: Show the idea
      ansible.builtin.debug:
        msg: "replace with a small, generic example - not the exercise solution"
```

*Was das Beispiel zeigt und was es bewusst weglässt.*

### Konzept 2

*Gleiches Muster. So viele Konzepte wie die Lektion braucht, typisch zwei bis fünf.*

## CIS-Hintergrund

*Wogegen die Empfehlungen schützen, warum manche nur Level 2 sind, typische Abwägungen
im Betrieb. Auf die IDs aus [dem Kontrollkatalog](../../cis/controls.yml) verweisen.*

## Plattformunterschiede

| os_family | *Aspekt 1* | *Aspekt 2* |
|---|---|---|
| Debian | | |
| RedHat | | |
| Suse | | |
| Alpine | | |
| Archlinux | | |

### In den Lab-Containern

*Was die Container nicht zeigen können und wie die Übungen damit umgehen -
siehe [Container-Grenzen](../CONTAINER_LIMITS.de.md). "Nichts Besonderes", wenn das zutrifft.*

## Stolperfallen

| Symptom | Ursache | Abhilfe |
|---|---|---|
| *was man sieht* | *warum es passiert* | *was stattdessen zu tun ist* |

## Übungen

| Übung | Was diese Lektion dafür vorbereitet |
|---|---|
| [x.yy](../../exercises/INDEX.de.md) | *Konzepte aus dieser Lektion, die die Übung braucht* |

Eine Übung startest du mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. *Frage, die Verständnis prüft, nicht das Auswendigwissen eines Befehls.*

   <details><summary>Antwort</summary>

   *Antwort in zwei bis fünf Sätzen.*

   </details>

2. *Frage zu einer Stolperfalle oder einem Plattformunterschied.*

   <details><summary>Antwort</summary>

   *Antwort.*

   </details>

## Weiterführendes

- [Ansible-Dokumentation](https://docs.ansible.com/) - *die passende Modul- oder Guide-Seite*
- *Manpage oder Upstream-Doku des konfigurierten Werkzeugs*
