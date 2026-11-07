# 1.02 - Rechte auf /etc/passwd und /etc/group

## Hinweis 1

`ansible.builtin.file` mit `path`, `owner`, `group`, `mode`. Kein `state: touch` setzen.

## Hinweis 2

Ohne `state` nutzt `file` bei existierenden Dateien `state: file` - es ändert nur Attribute.

## Hinweis 3

```yaml
- name: Fix account file permissions
  hosts: "..."                   # every target
  become: "..."                  # changing owner needs root
  tasks:
    - name: /etc/passwd permissions
      ansible.builtin.file:
        path: "..."              # the file
        owner: "..."
        group: "..."
        mode: "..."              # quoted, four digits
    # same task again for /etc/group (or one task with a loop)
```

Referenz: `lab solution 1.02`.
