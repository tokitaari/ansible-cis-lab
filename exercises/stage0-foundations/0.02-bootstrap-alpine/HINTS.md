# 0.02 - Bootstrap Python on Alpine with raw

## Hint 1

`gather_facts: false` at play level. `raw` takes the command as free-form text: `ansible.builtin.raw: <command>`.

## Hint 2

Make the command idempotent in shell: `test -e /usr/bin/python3 || apk add --no-cache python3`. Print a marker when you install.

## Hint 3

`ansible.builtin.raw: test -e /usr/bin/python3 || { apk add --no-cache python3 && echo INSTALLED; }` + `register: bootstrap` + `changed_when: "'INSTALLED' in bootstrap.stdout"`.
