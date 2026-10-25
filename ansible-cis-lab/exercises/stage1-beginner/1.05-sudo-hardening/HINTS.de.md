# 1.05 - sudo: PTY erzwingen und in Datei protokollieren

## Hinweis 1

Gleiches Muster wie 1.03: `copy` + `content` + `validate`. Kein Handler nötig - sudo liest seine Konfiguration bei jedem Aufruf.

## Hinweis 2

`validate: /usr/sbin/visudo -cf %s`. sudoers-Dateien sollten `0440` haben.

## Hinweis 3

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
