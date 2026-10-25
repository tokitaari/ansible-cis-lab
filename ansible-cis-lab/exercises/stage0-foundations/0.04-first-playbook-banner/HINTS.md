# 0.04 - First hardening playbook: SSH warning banner

## Hint 1

The module is `ansible.builtin.copy`. It can write a file from an inline string with `content:`.

## Hint 2

Set `owner`, `group` and `mode`. Write the mode as a *quoted* string: `mode: "0644"`.

## Hint 3

```yaml
- name: Set SSH warning banner
  ansible.builtin.copy:
    dest: /etc/issue.net
    content: |
      Authorized access only. Activity on this system is monitored and logged.
    owner: root
    group: root
    mode: "0644"
```
