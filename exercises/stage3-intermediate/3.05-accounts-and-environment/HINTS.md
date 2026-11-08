# 3.05 - Account audit: UID 0, empty passwords, umask, TMOUT

## Hint 1

`(passwd.content | b64decode).splitlines() | map('split', ':')` gives a list of lists. `selectattr('2', 'equalto', '0')` filters by the third field (UID); `map(attribute='0')` returns the names. Remove `root` with `reject('equalto', 'root')`.

## Hint 2

Empty password: shadow field 2 (index `1`) is `''` → `selectattr('1', 'equalto', '')`. Lock with `ansible.builtin.user: name=... password_lock=true`. Remove with `state: absent`, `force: true`, `remove: false`.

## Hint 3

```yaml
- name: CIS 5.4 - accounts and environment
  hosts: "..."
  become: "..."
  tasks:
    - name: Read account databases
      ansible.builtin.slurp:
        src: "{{ item }}"
      loop: ["...", "..."]       # passwd, shadow
      register: cis_account_files

    - name: Find dangerous accounts
      ansible.builtin.set_fact:
        cis_uid0_extra: "..."     # UID 0 names without root (hint 1)
        cis_empty_password: "..." # names with an empty shadow field (hint 2)

    - name: Report findings
      ansible.builtin.debug:
        msg: "..."

    - name: Remove additional UID 0 accounts
      ansible.builtin.user:
        name: "{{ item }}"
        state: absent
        force: "..."
        remove: "..."             # never delete the home: it can be /root
      loop: "{{ cis_uid0_extra }}"

    - name: Lock accounts with an empty password
      ansible.builtin.user: "..." # password_lock
      loop: "{{ cis_empty_password }}"

    - name: Default umask for login shells
      ansible.builtin.copy: "..." # /etc/profile.d/50-cis-umask.sh, 0644 root:root

    - name: Shell timeout for interactive shells
      ansible.builtin.copy: "..." # 50-cis-tmout.sh: TMOUT, readonly TMOUT, export TMOUT
```

Write `umask 027`, not `0027` - the check accepts only the first. The second run finds empty lists, so the loops do nothing - idempotency for free. Reference: `lab solution 3.05`.
