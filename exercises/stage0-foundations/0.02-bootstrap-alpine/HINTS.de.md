# 0.02 - Python auf Alpine per raw nachrüsten

## Hinweis 1

`gather_facts: false` auf Play-Ebene. `raw` nimmt den Befehl als Freitext: `ansible.builtin.raw: <befehl>`.

## Hinweis 2

Mach den Befehl in der Shell idempotent: `test -e /usr/bin/python3 || apk add --no-cache python3`. Gib beim Installieren eine Markierung aus.

## Hinweis 3

`ansible.builtin.raw: test -e /usr/bin/python3 || { apk add --no-cache python3 && echo INSTALLED; }` + `register: bootstrap` + `changed_when: "'INSTALLED' in bootstrap.stdout"`.
