# 1.02 - Permissions on /etc/passwd and /etc/group

## Hint 1

`ansible.builtin.file` with `path`, `owner`, `group`, `mode`. Do not set `state: touch`.

## Hint 2

Without `state`, `file` uses `state: file` for existing files - it changes attributes only.

## Hint 3

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

Reference: `lab solution 1.02`.
