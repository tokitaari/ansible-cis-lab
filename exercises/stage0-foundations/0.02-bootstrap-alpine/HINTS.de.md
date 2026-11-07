# 0.02 - Python auf Alpine per raw nachrüsten

## Hinweis 1

`gather_facts: false` auf Play-Ebene. `raw` nimmt den Befehl als Freitext: `ansible.builtin.raw: <befehl>`.

## Hinweis 2

Mach den Befehl in der Shell idempotent: `test -e /usr/bin/python3 || apk add --no-cache python3`. Gib beim Installieren eine Markierung aus.

## Hinweis 3

Das Play als Gerüst - fülle jedes `"..."` aus. Die Markierung darf erst ausgegeben werden, wenn die Installation gelungen ist.

```yaml
- name: Bootstrap Python on Alpine
  hosts: alpine_family
  gather_facts: "..."               # Facts brauchen Python
  become: "..."                     # apk braucht Root
  tasks:
    - name: Install python3 if missing
      ansible.builtin.raw: "..."    # Guard || { Installation && echo MARKIERUNG; }
      register: bootstrap
      changed_when: "..."           # nur wahr, wenn die Markierung in der Ausgabe steht
    - name: Verify that modules can run now
      ansible.builtin.ping:
```

Referenz: `lab solution 0.02`.
