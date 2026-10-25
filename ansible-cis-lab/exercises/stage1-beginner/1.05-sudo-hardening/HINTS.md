# 1.05 - sudo: use a PTY and log to a file

## Hint 1

Same pattern as 1.03: `copy` + `content` + `validate`. No handler needed - sudo reads its config on every invocation.

## Hint 2

`validate: /usr/sbin/visudo -cf %s`. sudoers files should be `0440`.

## Hint 3

```yaml
- name: Harden sudo defaults
  ansible.builtin.copy:
    dest: /etc/sudoers.d/50-cis
    content: |
      Defaults use_pty
      Defaults logfile="/var/log/sudo.log"
    owner: root
    group: root
    mode: "0440"
    validate: /usr/sbin/visudo -cf %s
```
