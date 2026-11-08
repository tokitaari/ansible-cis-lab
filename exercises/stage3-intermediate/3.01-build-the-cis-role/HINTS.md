# 3.01 - Refactor everything into a role

## Hint 1

Start with the skeleton that `lab start 3.01` created in `/lab/work/roles/cis` - its comments say which exercise goes into which section file. Copy your working tasks there, then move every literal value into `defaults/main.yml`. Templates go to `templates/` - `src:` then needs no path.

## Hint 2

Loading platform vars: `ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', candidates) }}"` where `candidates` has `files: ["{{ ansible_facts.os_family }}.yml", default.yml]` and `paths: ["{{ role_path }}/vars"]`. Tag that task `always`, otherwise `--tags ssh` skips it.

## Hint 3

The role's `tasks/main.yml`:

```yaml
- name: Load OS family specific variables
  ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', cis_vars_candidates) }}"
  vars:
    cis_vars_candidates:
      files: ["...", "..."]     # <os_family>.yml first, then the fallback
      paths: ["..."]            # the vars/ directory of this role
  tags: ["..."]                 # must run under every --tags selection

- name: Section 1 - initial setup
  ansible.builtin.import_tasks: "..."
  tags: ["..."]
# ... one import each for sections 2, 3, 5 and 7, same pattern
```

`import_tasks` is static: the tag of the import reaches every task inside. In the section files give
each task its topic tag - helper tasks such as "directory exists" too, otherwise `--tags sysctl`
skips them. Registered variables need the prefix as well (`register: cis_cron_stat`).

The full reference role: `lab solution 3.01`.
