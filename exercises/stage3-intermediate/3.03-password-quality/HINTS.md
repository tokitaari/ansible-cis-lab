# 3.03 - Password quality with pam_pwquality

## Hint 1

Template the drop-in from a dict: `{% for k, v in cis_pwquality.items() %}{{ k }} = {{ v }}\n{% endfor %}` plus a literal `enforce_for_root` line (it is a flag without value).

## Hint 2

For the PAM verification: `slurp` the stack file, then a conditional `command: pam-auth-update --enable pwquality` when `'pam_pwquality' not in content`. On Red Hat, `command: authselect current` with `changed_when: false` - report what profile is active.

## Hint 3

The playbook's tasks as a skeleton - fill in every `"..."`. The dicts (package and PAM file per family, the CIS values) belong in `vars:` before `tasks:`; in your role they go to `defaults/` or `vars/`.

```yaml
- name: Look for an apt package index
  ansible.builtin.find:
    paths: "..."
    patterns: "..."                   # the index files, *_Packages*
  register: cis_apt_lists
  check_mode: false
  when: "..."                         # Debian family only

- name: Refresh the apt package index (missing, or older than a day)
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: "..."           # 0 while no index file exists, else one day
  changed_when: false
  check_mode: false
  when: "..."

- name: Install pwquality
  ansible.builtin.package:
    name: "..."                       # dict lookup per os_family
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
    src: "..."                        # loop over the dict, then a bare enforce_for_root line
    dest: "..."                       # 50-cis.conf
    owner: root
    group: root
    mode: "0644"

- name: Read the PAM password stack
  ansible.builtin.slurp:
    src: "..."                        # dict lookup per os_family
  register: cis_pam_stack

- name: Debian - enable the pwquality PAM profile if missing
  ansible.builtin.command: pam-auth-update --enable pwquality
  when:
    - "..."                           # Debian family
    - "..."                           # pam_pwquality not in the decoded content
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
    that: "..."                       # pam_pwquality in the decoded content
    fail_msg: "..."                   # name the profile, point to authselect
    quiet: true
  when: "..."
```

Reference: `lab solution 3.03`.
