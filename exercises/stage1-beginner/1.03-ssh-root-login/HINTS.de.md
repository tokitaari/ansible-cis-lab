# 1.03 - SSH: Root-Login und leere Passwörter verbieten

## Hinweis 1

`ansible.builtin.copy` mit `content:` und `validate: /usr/sbin/sshd -t -f %s`. `%s` ist die temporäre Datei, die Ansible prüft, bevor es sie an ihren Platz verschiebt.

## Hinweis 2

Ergänze `notify: Reload sshd` am copy-Task und einen Abschnitt `handlers:` mit einem `ansible.builtin.service`-Task, der exakt `Reload sshd` heißt. Der Dienstname darf ein Ausdruck sein: `"{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"`.

## Hinweis 3

```yaml
- name: Harden sshd authentication
  hosts: "..."                   # every target
  become: "..."                  # writing to /etc/ssh needs root
  tasks:
    - name: Deploy sshd hardening drop-in
      ansible.builtin.copy:
        dest: "..."              # the drop-in file; a low number wins
        content: |
          PermitRootLogin ...
          PermitEmptyPasswords ...
        owner: "..."
        group: "..."
        mode: "..."              # quoted, private to root
        validate: "..."          # sshd -t -f %s
      notify: "..."              # the handler's name
  handlers:
    - name: "..."                # exactly the name used in notify
      ansible.builtin.service:
        name: "..."              # ssh on Debian, sshd elsewhere
        state: "..."             # reload, do not restart
```

Referenz: `lab solution 1.03`.
