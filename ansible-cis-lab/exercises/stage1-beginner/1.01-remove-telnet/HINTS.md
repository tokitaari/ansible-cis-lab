# 1.01 - Remove insecure client packages

## Hint 1

`ansible-doc ansible.builtin.package` - look at `name` and `state`.

## Hint 2

`state: absent` is idempotent: removing a package that is not installed is simply `ok`.

## Hint 3

```yaml
- name: Remove telnet client
  ansible.builtin.package:
    name: telnet
    state: absent
```
