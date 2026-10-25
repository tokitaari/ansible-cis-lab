# 1.02 - Permissions on /etc/passwd and /etc/group

## Hint 1

`ansible.builtin.file` with `path`, `owner`, `group`, `mode`. Do not set `state: touch`.

## Hint 2

Without `state`, `file` uses `state: file` for existing files - it changes attributes only.

## Hint 3

```yaml
- name: /etc/passwd permissions
  ansible.builtin.file:
    path: /etc/passwd
    owner: root
    group: root
    mode: "0644"
```
(and the same for `/etc/group`)
