# 4.02 - Profile (Level 1/2) und dokumentierte Ausnahmen

## Hinweis 1

Zuerst die Vorabprüfung: ein `assert`-Task mit Schleife über `cis_exceptions` und `that:`-Prüfungen für `item.id in known_ids`, `item.reason | default('') | length > 0`, `(item.expires | string | to_datetime('%Y-%m-%d')) > now()`. Beachte `| string`: YAML macht aus `2027-01-31` ein Datumsobjekt.

## Hinweis 2

Berechne `cis_exception_ids: "{{ cis_exceptions | map(attribute='id') | list }}"`. Umschließe jede Kontrolle mit einem `block:` mit `when: cis_level | int >= N and 'id' not in cis_exception_ids` - Blöcke geben `when` an jeden Task darin weiter. Task-Namen im Block beginnen mit der ID.

## Hinweis 3

Referenz: `lab solution 4.02` (Rolle `cis_profile`). Was der Check tut: `cat /lab/exercises/stage4-advanced/4.02-*/check.sh`.
