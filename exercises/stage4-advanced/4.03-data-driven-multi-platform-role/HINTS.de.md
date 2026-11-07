# 4.03 - Datengetriebene Rolle für alle Plattformen (inkl. Alpine)

## Hinweis 1

Verschiebe jeden Plattformunterschied aus Stufe 3 in die vars-Dateien: Audit-Paketname, PAM-Werkzeug (`pam-auth-update`/`authselect`/`manual`/`none`), pwquality-Paket und PAM-Stack-Pfad, plus ein Boolean `cis_pwquality_supported`. Alpine: `cis_pam_tool: none`.

## Hinweis 2

Ersetze z. B. `when: ansible_facts.os_family == 'Debian'` durch `when: cis_pam_tool == 'pam-auth-update'`. Die first_found-Liste: `files: ["{{ ansible_facts.distribution }}-{{ ansible_facts.distribution_major_version }}.yml", "{{ ansible_facts.distribution }}.yml", "{{ ansible_facts.os_family }}.yml", default.yml]`. Sie lädt nur eine Datei, also muss jede Datei jedes Flag definieren. Bei arch ist die Hauptversion ein Datum und die `distribution` von openSUSE enthält ein Leerzeichen; beide fallen einfach auf die Familiendatei durch.

## Hinweis 3

Die `tasks/main.yml` der Rolle als Gerüst - setze jedes `"..."` ein:

```yaml
- name: Load platform specific variables
  ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', cis_vars_candidates) }}"
  vars:
    cis_vars_candidates:
      files:
        - "..."                       # <distribution>-<major>.yml, Hinweis 2
        - "..."
        - "..."
        - "..."                       # der konservative Fallback
      paths:
        - "{{ role_path }}/vars"
  tags: [always]

# Abschnitte 1, 2, 3, Zugriffskontrolle und 7: wie in 3.01

- name: Section 5 - password policy
  ansible.builtin.import_tasks: "..."   # die Datei aus 3.02
  tags: [section5, password]

- name: Section 5 - PAM password quality
  ansible.builtin.import_tasks: "..."   # die Datei aus 3.03
  tags: [section5, pam]

- name: Section 5 - accounts and environment
  ansible.builtin.import_tasks: "..."   # die Datei aus 3.05
  tags: [section5, accounts]

- name: Section 6 - logging and auditing (Level 2)
  ansible.builtin.import_tasks: "..."   # die Datei aus 3.04
  when: "..."                           # Level 2 oder höher, als Zahl
  tags: [section6, auditd]
```

Die vars-Dateien enthalten die Flags und Werte aus Hinweis 1. Die Musterlösung frischt außerdem auf der Debian-Familie den apt-Index vor der ersten Paketinstallation auf (ein Flag in `vars/`, siehe den Kommentar in ihrer `tasks/main.yml`). Der Check durchsucht deine Task-Dateien, lintet die Rolle und führt fünfzehn frühere Checks aus (sechzehn mit `-e cis_level=2`) - lies `check.sh`, wenn etwas unklar ist. Referenz: `lab solution 4.03`.
