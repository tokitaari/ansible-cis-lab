# 1.01 - Unsichere Client-Pakete entfernen

## Hinweis 1

`ansible-doc ansible.builtin.package` - schau dir `name` und `state` an.

## Hinweis 2

`state: absent` ist idempotent: ein nicht installiertes Paket zu entfernen ergibt einfach `ok`.

## Hinweis 3

```yaml
- name: Remove telnet client
  ansible.builtin.package:
    name: telnet
    state: absent
```
