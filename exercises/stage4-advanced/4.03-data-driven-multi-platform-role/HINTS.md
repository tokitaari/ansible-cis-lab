# 4.03 - Data-driven role for all platforms (incl. Alpine)

## Hint 1

Move every platform difference you used in stage 3 into the vars files: audit package name, PAM tool (`pam-auth-update`/`authselect`/`manual`/`none`), pwquality package and PAM stack path, plus a boolean `cis_pwquality_supported`. Alpine: `cis_pam_tool: none`.

## Hint 2

Replace e.g. `when: ansible_facts.os_family == 'Debian'` by `when: cis_pam_tool == 'pam-auth-update'`. The first_found list: `files: ["{{ ansible_facts.distribution }}-{{ ansible_facts.distribution_major_version }}.yml", "{{ ansible_facts.distribution }}.yml", "{{ ansible_facts.os_family }}.yml", default.yml]`. It loads one file only, so every file has to define every flag. On arch the major version is a date and openSUSE's `distribution` contains a space; both simply fall through to the family file.

## Hint 3

The role's `tasks/main.yml` as a skeleton - fill in every `"..."`:

```yaml
- name: Load platform specific variables
  ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', cis_vars_candidates) }}"
  vars:
    cis_vars_candidates:
      files:
        - "..."                       # <distribution>-<major>.yml, hint 2
        - "..."
        - "..."
        - "..."                       # the conservative fallback
      paths:
        - "{{ role_path }}/vars"
  tags: [always]

# sections 1, 2, 3, access control and 7: as in 3.01

- name: Section 5 - password policy
  ansible.builtin.import_tasks: "..."   # the file of 3.02
  tags: [section5, password]

- name: Section 5 - PAM password quality
  ansible.builtin.import_tasks: "..."   # the file of 3.03
  tags: [section5, pam]

- name: Section 5 - accounts and environment
  ansible.builtin.import_tasks: "..."   # the file of 3.05
  tags: [section5, accounts]

- name: Section 6 - logging and auditing (Level 2)
  ansible.builtin.import_tasks: "..."   # the file of 3.04
  when: "..."                           # level 2 or higher, as a number
  tags: [section6, auditd]
```

The vars files hold the flags and values of hint 1. The reference solution also refreshes the apt index on the Debian family before the first package install (a flag in `vars/`, see the comment in its `tasks/main.yml`). The check greps your task files, lints the role and runs fifteen earlier checks (sixteen with `-e cis_level=2`) - read `check.sh` if something is unclear. Reference: `lab solution 4.03`.
