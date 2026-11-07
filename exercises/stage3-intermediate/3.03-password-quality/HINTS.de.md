# 3.03 - Passwortqualität mit pam_pwquality

## Hinweis 1

Das Drop-in aus einem Dict templaten: `{% for k, v in cis_pwquality.items() %}{{ k }} = {{ v }}\n{% endfor %}` plus eine feste Zeile `enforce_for_root` (ein Flag ohne Wert).

## Hinweis 2

Für die PAM-Prüfung: Stack-Datei per `slurp` lesen, dann bedingt `command: pam-auth-update --enable pwquality`, wenn `'pam_pwquality' not in content`. Auf Red Hat `command: authselect current` mit `changed_when: false` - melde, welches Profil aktiv ist.

## Hinweis 3

Die Tasks des Playbooks als Gerüst - füll jedes `"..."` aus. Die Dicts (Paket und PAM-Datei je Familie, die CIS-Werte) gehören in `vars:` vor `tasks:`; in deiner Rolle nach `defaults/` oder `vars/`.

```yaml
- name: Look for an apt package index
  ansible.builtin.find:
    paths: "..."
    patterns: "..."                   # die Indexdateien, *_Packages*
  register: cis_apt_lists
  check_mode: false
  when: "..."                         # nur die Debian-Familie

- name: Refresh the apt package index (missing, or older than a day)
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: "..."           # 0, solange keine Indexdatei existiert, sonst ein Tag
  changed_when: false
  check_mode: false
  when: "..."

- name: Install pwquality
  ansible.builtin.package:
    name: "..."                       # Dict-Lookup je os_family
    state: present

- name: Ensure the drop-in directory exists
  ansible.builtin.file:
    path: "..."
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Deploy the CIS pwquality drop-in
  ansible.builtin.template:
    src: "..."                        # Schleife über das Dict, dann eine nackte Zeile enforce_for_root
    dest: "..."                       # 50-cis.conf
    owner: root
    group: root
    mode: "0644"

- name: Read the PAM password stack
  ansible.builtin.slurp:
    src: "..."                        # Dict-Lookup je os_family
  register: cis_pam_stack

- name: Debian - enable the pwquality PAM profile if missing
  ansible.builtin.command: pam-auth-update --enable pwquality
  when:
    - "..."                           # Debian-Familie
    - "..."                           # pam_pwquality nicht im dekodierten Inhalt
  changed_when: true

- name: Red Hat - show the active authselect profile
  ansible.builtin.command: authselect current
  register: cis_authselect
  changed_when: false
  check_mode: false
  failed_when: false
  when: "..."

- name: Red Hat - pam_pwquality must be part of the authselect profile
  ansible.builtin.assert:
    that: "..."                       # pam_pwquality im dekodierten Inhalt
    fail_msg: "..."                   # Profil nennen, auf authselect verweisen
    quiet: true
  when: "..."
```

Referenz: `lab solution 3.03`.
