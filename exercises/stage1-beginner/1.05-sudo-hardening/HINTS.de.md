# 1.05 - sudo: PTY erzwingen und in Datei protokollieren

## Hinweis 1

Gleiches Muster wie 1.03: `copy` + `content` + `validate`. Kein Handler nötig - sudo liest seine Konfiguration bei jedem Aufruf.

## Hinweis 2

`validate: /usr/sbin/visudo -cf %s`. sudoers-Dateien sollten `0440` haben.

## Hinweis 3

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

Referenz: `lab solution 1.05`.
