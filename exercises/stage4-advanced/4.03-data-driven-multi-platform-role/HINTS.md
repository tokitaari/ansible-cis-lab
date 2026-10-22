# 4.03 - Data-driven role for all platforms (incl. Alpine)

## Hint 1

Move every platform difference you used in stage 3 into the vars files: audit package name, PAM tool (`pam-auth-update`/`authselect`/`manual`/`none`), pwquality package and PAM stack path, plus a boolean `cis_pwquality_supported`. Alpine: `cis_pam_tool: none`.

## Hint 2

Replace e.g. `when: ansible_facts.os_family == 'Debian'` by `when: cis_pam_tool == 'pam-auth-update'`. The first_found list: `files: ["{{ ansible_facts.distribution }}-{{ ansible_facts.distribution_major_version }}.yml", "{{ ansible_facts.distribution }}.yml", "{{ ansible_facts.os_family }}.yml", default.yml]`.

## Hint 3

Reference: `lab solution 4.03`. The check greps your task files, lints the role and runs ten earlier checks - read `check.sh` if something is unclear.
