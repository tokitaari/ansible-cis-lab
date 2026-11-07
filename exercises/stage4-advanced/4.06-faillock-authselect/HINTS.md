# 4.06 - Account lockout with pam_faillock (authselect)

## Hint 1

Read first: `ansible.builtin.command: authselect current` with `changed_when: false`, `check_mode: false`, `register: cis_authselect`.

## Hint 2

`ansible.builtin.command: authselect enable-feature with-faillock` with `when: "'with-faillock' not in cis_authselect.stdout"` and `changed_when: true`. Config: `lineinfile` with `regexp: '^\s*#?\s*deny\s*='` and `line: 'deny = 5'` (the default file contains commented examples).

## Hint 3

The playbook's tasks as a skeleton - fill in every `"..."`. The two thresholds belong in a dict in `vars:` before `tasks:`.

```yaml
- name: Read the active authselect configuration
  ansible.builtin.command: authselect current
  register: cis_authselect
  changed_when: "..."                 # reading changes nothing
  check_mode: "..."                   # must also run under --check

- name: Enable the with-faillock feature if missing
  ansible.builtin.command: authselect enable-feature with-faillock
  when: "..."                         # the feature is not in the output yet
  changed_when: "..."                 # it only runs when it changes something

- name: Configure faillock thresholds
  ansible.builtin.lineinfile:
    path: /etc/security/faillock.conf
    regexp: "..."                     # the key, also when it is still commented out
    line: "..."                       # key = value
  loop: "..."                         # deny and unlock_time as key/value pairs
```

Reference: `lab solution 4.06`.
