# 3.01 - Alles in eine Rolle überführen

## Hinweis 1

Beginne mit dem Gerüst (`ansible-galaxy role init`), kopiere deine funktionierenden Tasks in die Abschnittsdateien und verschiebe dann jeden festen Wert nach `defaults/main.yml`. Templates kommen nach `templates/` - `src:` braucht dann keinen Pfad.

## Hinweis 2

Plattform-vars laden: `ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', candidates) }}"` mit `candidates` = `files: ["{{ ansible_facts.os_family }}.yml", default.yml]` und `paths: ["{{ role_path }}/vars"]`. Diesen Task mit `always` taggen, sonst überspringt `--tags ssh` ihn.

## Hinweis 3

`import_tasks` ist statisch: Tags am Import werden an jeden Task darin vererbt. Registrierte Variablen in Rollen brauchen auch das Präfix (`register: cis_cron_stat`). Die komplette Referenzrolle: `lab solution 3.01`.
