# 2.02 - SSH-Server-Härtung mit Jinja2-Template

## Hinweis 1

Template-Syntax: `MaxAuthTries {{ sshd_max_auth_tries }}`, `Ciphers {{ sshd_ciphers | join(',') }}`. Kommentarzeile: `{{ ansible_managed | comment }}`.

## Hinweis 2

Die Gesamtprüfung ist ein `command: /usr/sbin/sshd -t`-Task mit `changed_when: false`. Setze ihn *nach* den template-Task, überlege aber, *wann* Handler laufen - soll die Prüfung vor oder nach dem Reload kommen? (`ansible.builtin.meta: flush_handlers`)

## Hinweis 3

```yaml
- name: CIS 5.1 - SSH server hardening
  hosts: "..."
  become: "..."
  vars:
    sshd_max_auth_tries: "..."   # eine Variable pro Wert der README-Tabelle
    sshd_ciphers: ["..."]        # Listen, im Template verbunden
  tasks:
    - name: Deploy sshd hardening drop-in
      ansible.builtin.template:
        src: "..."               # die .j2-Datei in templates/
        dest: "..."
        owner: root
        group: root
        mode: "..."
        validate: "..."          # sshd prüft das Fragment allein (%s)
      notify: "..."
    - name: Validate the complete sshd configuration
      ansible.builtin.command: "..."   # sshd -t, ohne -f
      changed_when: "..."
  handlers:
    - name: Reload sshd
      ansible.builtin.service:
        name: "..."              # ssh auf Debian, sonst sshd
        state: "..."
```

Das Template setzt jeden Schlüssel, den der Check prüft - auch `PermitRootLogin`, `PermitEmptyPasswords` und `X11Forwarding`, sonst liefert das Legacy-Drop-in sie. Die Gesamtprüfung läuft vor dem Handler, der am Ende des Plays neu lädt.

Referenz: `lab solution 2.02`.
