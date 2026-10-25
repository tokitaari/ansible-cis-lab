# 4.06 - Account lockout with pam_faillock (authselect)

## Hint 1

Read first: `ansible.builtin.command: authselect current` with `changed_when: false`, `check_mode: false`, `register: cis_authselect`.

## Hint 2

`ansible.builtin.command: authselect enable-feature with-faillock` with `when: "'with-faillock' not in cis_authselect.stdout"` and `changed_when: true`. Config: `lineinfile` with `regexp: '^\s*#?\s*deny\s*='` and `line: 'deny = 5'` (the default file contains commented examples).

## Hint 3

Reference: `lab solution 4.06`.
