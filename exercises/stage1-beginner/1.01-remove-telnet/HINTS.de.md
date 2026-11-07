# 1.01 - Unsichere Client-Pakete entfernen

## Hinweis 1

`ansible-doc ansible.builtin.package` - schau dir `name` und `state` an.

## Hinweis 2

`state: absent` ist idempotent: ein nicht installiertes Paket zu entfernen ergibt einfach `ok`.

## Hinweis 3

Das Play als Gerüst - setze überall dort etwas ein, wo `"..."` steht.

```yaml
- name: Remove insecure client packages
  hosts: "..."                   # alle Targets
  become: "..."                  # Pakete entfernen braucht root
  tasks:
    - name: Remove telnet client
      ansible.builtin.package:
        name: "..."              # der Paketname
        state: "..."             # nicht installiert
```

Referenz: `lab solution 1.01`.
