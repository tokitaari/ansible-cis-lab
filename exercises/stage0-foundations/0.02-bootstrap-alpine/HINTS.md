# 0.02 - Bootstrap Python on Alpine with raw

## Hint 1

`gather_facts: false` at play level. `raw` takes the command as free-form text: `ansible.builtin.raw: <command>`.

## Hint 2

Make the command idempotent in shell: `test -e /usr/bin/python3 || apk add --no-cache python3`. Print a marker when you install.

## Hint 3

The play as a skeleton - fill in every `"..."`. The marker must be printed only after the install succeeded.

```yaml
- name: Bootstrap Python on Alpine
  hosts: alpine_family
  gather_facts: "..."               # facts need Python
  become: "..."                     # apk needs root
  tasks:
    - name: Install python3 if missing
      ansible.builtin.raw: "..."    # guard || { install && echo MARKER; }
      register: bootstrap
      changed_when: "..."           # true only if the marker is in the output
    - name: Verify that modules can run now
      ansible.builtin.ping:
```

Reference: `lab solution 0.02`.
