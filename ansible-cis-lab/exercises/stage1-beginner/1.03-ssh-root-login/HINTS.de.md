# 1.03 - SSH: Root-Login und leere Passwörter verbieten

## Hinweis 1

`ansible.builtin.copy` mit `content:` und `validate: /usr/sbin/sshd -t -f %s`. `%s` ist die temporäre Datei, die Ansible prüft, bevor es sie an ihren Platz verschiebt.

## Hinweis 2

Ergänze `notify: Reload sshd` am copy-Task und einen Abschnitt `handlers:` mit einem `ansible.builtin.service`-Task, der exakt `Reload sshd` heißt. Der Dienstname darf ein Ausdruck sein: `"{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"`.

## Hinweis 3

```yaml
tasks:
  - name: Deploy sshd hardening drop-in
    ansible.builtin.copy:
      dest: /etc/ssh/sshd_config.d/00-cis-hardening.conf
      content: |
        PermitRootLogin no
        PermitEmptyPasswords no
      owner: root
      group: root
      mode: "0600"
      validate: /usr/sbin/sshd -t -f %s
    notify: Reload sshd
handlers:
  - name: Reload sshd
    ansible.builtin.service:
      name: "{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"
      state: reloaded
```
