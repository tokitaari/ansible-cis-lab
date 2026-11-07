# 1.05 - sudo: use a PTY and log to a file

## Hint 1

Same pattern as 1.03: `copy` + `content` + `validate`. No handler needed - sudo reads its config on every invocation.

## Hint 2

`validate: /usr/sbin/visudo -cf %s`. sudoers files should be `0440`.

## Hint 3

```yaml
- name: Harden sudo
  hosts: "..."                   # every target
  become: "..."                  # writing to /etc/sudoers.d needs root
  tasks:
    - name: Deploy sudo defaults
      ansible.builtin.copy:
        dest: "..."              # a file name without a dot
        content: |
          Defaults ...
          Defaults logfile="..."
        owner: "..."
        group: "..."
        mode: "..."              # quoted; sudoers files are read-only
        validate: "..."          # visudo -cf %s
```

Reference: `lab solution 1.05`.
