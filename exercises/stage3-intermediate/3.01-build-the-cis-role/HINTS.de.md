# 3.01 - Alles in eine Rolle überführen

## Hinweis 1

Beginne mit dem Gerüst, das `lab start 3.01` in `/lab/work/roles/cis` angelegt hat - seine Kommentare sagen, welche Übung in welche Abschnittsdatei gehört. Kopiere deine funktionierenden Tasks dorthin und verschiebe dann jeden festen Wert nach `defaults/main.yml`. Templates kommen nach `templates/` - `src:` braucht dann keinen Pfad.

## Hinweis 2

Plattform-vars laden: `ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', candidates) }}"` mit `candidates` = `files: ["{{ ansible_facts.os_family }}.yml", default.yml]` und `paths: ["{{ role_path }}/vars"]`. Diesen Task mit `always` taggen, sonst überspringt `--tags ssh` ihn.

## Hinweis 3

Die `tasks/main.yml` der Rolle:

```yaml
- name: Load OS family specific variables
  ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', cis_vars_candidates) }}"
  vars:
    cis_vars_candidates:
      files: ["...", "..."]     # zuerst <os_family>.yml, dann die Rückfalldatei
      paths: ["..."]            # das Verzeichnis vars/ dieser Rolle
  tags: ["..."]                 # muss bei jeder --tags-Auswahl laufen

- name: Section 1 - initial setup
  ansible.builtin.import_tasks: "..."
  tags: ["..."]
# ... je ein Import für die Abschnitte 2, 3, 5 und 7, gleiches Muster
```

`import_tasks` ist statisch: Das Tag am Import erreicht jeden Task darin. Gib in den
Abschnittsdateien jedem Task sein Themen-Tag - auch Hilfs-Tasks wie "Verzeichnis existiert", sonst
überspringt `--tags sysctl` sie. Registrierte Variablen brauchen ebenfalls das Präfix
(`register: cis_cron_stat`).

Die komplette Referenzrolle: `lab solution 3.01`.
