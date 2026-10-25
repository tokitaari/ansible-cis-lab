# 3.01 - Refactor everything into a role

## Hint 1

Start with the skeleton (`ansible-galaxy role init`), copy your working tasks into the section files, then move every literal value into `defaults/main.yml`. Templates go to `templates/` - `src:` then needs no path.

## Hint 2

Loading platform vars: `ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', candidates) }}"` where `candidates` has `files: ["{{ ansible_facts.os_family }}.yml", default.yml]` and `paths: ["{{ role_path }}/vars"]`. Tag that task `always`, otherwise `--tags ssh` skips it.

## Hint 3

`import_tasks` is static: tags on the import are inherited by every task inside. Registered variables in roles need the prefix too (`register: cis_cron_stat`). The full reference role: `lab solution 3.01`.
