# 1.03 - SSH: forbid root login and empty passwords

## Hint 1

`ansible.builtin.copy` with `content:` and `validate: /usr/sbin/sshd -t -f %s`. `%s` is the temporary file Ansible validates before moving it into place.

## Hint 2

Add `notify: Reload sshd` to the copy task and a `handlers:` section with an `ansible.builtin.service` task named exactly `Reload sshd`. The service name can be an expression: `"{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"`.

## Hint 3

```yaml
- name: Harden sshd authentication
  hosts: "..."                   # every target
  become: "..."                  # writing to /etc/ssh needs root
  tasks:
    - name: Deploy sshd hardening drop-in
      ansible.builtin.copy:
        dest: "..."              # the drop-in file; a low number wins
        content: |
          PermitRootLogin ...
          PermitEmptyPasswords ...
        owner: "..."
        group: "..."
        mode: "..."              # quoted, private to root
        validate: "..."          # sshd -t -f %s
      notify: "..."              # the handler's name
  handlers:
    - name: "..."                # exactly the name used in notify
      ansible.builtin.service:
        name: "..."              # ssh on Debian, sshd elsewhere
        state: "..."             # reload, do not restart
```

Reference: `lab solution 1.03`.
