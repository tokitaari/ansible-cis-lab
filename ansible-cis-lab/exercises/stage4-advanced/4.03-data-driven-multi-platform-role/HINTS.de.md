# 4.03 - Datengetriebene Rolle für alle Plattformen (inkl. Alpine)

## Hinweis 1

Verschiebe jeden Plattformunterschied aus Stufe 3 in die vars-Dateien: Audit-Paketname, PAM-Werkzeug (`pam-auth-update`/`authselect`/`manual`/`none`), pwquality-Paket und PAM-Stack-Pfad, plus ein Boolean `cis_pwquality_supported`. Alpine: `cis_pam_tool: none`.

## Hinweis 2

Ersetze z. B. `when: ansible_facts.os_family == 'Debian'` durch `when: cis_pam_tool == 'pam-auth-update'`. Die first_found-Liste: `files: ["{{ ansible_facts.distribution }}-{{ ansible_facts.distribution_major_version }}.yml", "{{ ansible_facts.distribution }}.yml", "{{ ansible_facts.os_family }}.yml", default.yml]`.

## Hinweis 3

Referenz: `lab solution 4.03`. Der Check durchsucht deine Task-Dateien, lintet die Rolle und führt zehn frühere Checks aus - lies `check.sh`, wenn etwas unklar ist.
