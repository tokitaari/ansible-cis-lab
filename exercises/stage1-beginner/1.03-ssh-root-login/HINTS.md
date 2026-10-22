# 1.03 - SSH: forbid root login and empty passwords

## Hint 1

`ansible.builtin.copy` with `content:` and `validate: /usr/sbin/sshd -t -f %s`. `%s` is the temporary file Ansible validates before moving it into place.

## Hint 2

Add `notify: Reload sshd` to the copy task and a `handlers:` section with an `ansible.builtin.service` task named exactly `Reload sshd`. The service name can be an expression: `"{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"`.

## Hint 3

```yaml
tasks:
  - name: Deploy sshd hardening drop-in
    ansible.builtin.copy:
      dest: /etc/ssh/sshd_config.d/00-cis-hardening.conf
      content: |
        PermitRootLogin no
        PermitEmptyPasswords no
      owner: root
      group: root
      mode: "0600"
      validate: /usr/sbin/sshd -t -f %s
    notify: Reload sshd
handlers:
  - name: Reload sshd
    ansible.builtin.service:
      name: "{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"
      state: reloaded
```
