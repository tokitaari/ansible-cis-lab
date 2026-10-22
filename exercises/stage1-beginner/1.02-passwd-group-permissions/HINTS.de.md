# 1.02 - Rechte auf /etc/passwd und /etc/group

## Hinweis 1

`ansible.builtin.file` mit `path`, `owner`, `group`, `mode`. Kein `state: touch` setzen.

## Hinweis 2

Ohne `state` nutzt `file` bei existierenden Dateien `state: file` - es ändert nur Attribute.

## Hinweis 3

```yaml
- name: /etc/passwd permissions
  ansible.builtin.file:
    path: /etc/passwd
    owner: root
    group: root
    mode: "0644"
```
(und dasselbe für `/etc/group`)
