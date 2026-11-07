# 0.04 - First hardening playbook: SSH warning banner

## Hint 1

The module is `ansible.builtin.copy`. It can write a file from an inline string with `content:`.

## Hint 2

Set `owner`, `group` and `mode`. Write the mode as a *quoted* string: `mode: "0644"`.

## Hint 3

The play as a skeleton - fill in every `"..."`.

```yaml
- name: Set a neutral SSH warning banner
  hosts: "..."                      # all targets
  become: "..."                     # /etc is root's
  tasks:
    - name: Write /etc/issue.net without OS information
      ansible.builtin.copy:
        dest: "..."
        content: "..."              # a warning with 'authorized', no escapes, no distribution name
        owner: "..."
        group: "..."
        mode: "..."                 # quoted, four digits
```

Reference: `lab solution 0.04`.
