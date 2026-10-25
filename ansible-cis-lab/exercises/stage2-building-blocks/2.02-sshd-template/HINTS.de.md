# 2.02 - SSH-Server-Härtung mit Jinja2-Template

## Hinweis 1

Template-Syntax: `MaxAuthTries {{ sshd_max_auth_tries }}`, `Ciphers {{ sshd_ciphers | join(',') }}`. Kommentarzeile: `{{ ansible_managed | comment }}`.

## Hinweis 2

Die Gesamtprüfung ist ein `command: /usr/sbin/sshd -t`-Task mit `changed_when: false`. Setze ihn *nach* den template-Task, überlege aber, *wann* Handler laufen - soll die Prüfung vor oder nach dem Reload kommen? (`ansible.builtin.meta: flush_handlers`)

## Hinweis 3

Funktionierende Reihenfolge: template (Fragment validieren, notify) → `command: sshd -t` (Gesamtkonfiguration) → Handler lädt am Ende neu. Scheitert die Gesamtprüfung, stoppt das Play *vor* dem Reload, und der laufende sshd behält die alte Konfiguration.
