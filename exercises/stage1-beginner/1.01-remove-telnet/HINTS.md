# 1.01 - Remove insecure client packages

## Hint 1

`ansible-doc ansible.builtin.package` - look at `name` and `state`.

## Hint 2

`state: absent` is idempotent: removing a package that is not installed is simply `ok`.

## Hint 3

The play as a skeleton - fill in every `"..."`.

```yaml
- name: Remove insecure client packages
  hosts: "..."                   # every target
  become: "..."                  # removing packages needs root
  tasks:
    - name: Remove telnet client
      ansible.builtin.package:
        name: "..."              # the package name
        state: "..."             # not installed
```

Reference: `lab solution 1.01`.
