# 2.02 - SSH server hardening with a Jinja2 template

## Hint 1

Template syntax: `MaxAuthTries {{ sshd_max_auth_tries }}`, `Ciphers {{ sshd_ciphers | join(',') }}`. Comment line: `{{ ansible_managed | comment }}`.

## Hint 2

The full-config check is a `command: /usr/sbin/sshd -t` task with `changed_when: false`. Put it *after* the template task but think about *when* handlers run - should the check run before or after the reload? (`ansible.builtin.meta: flush_handlers`)

## Hint 3

Order that works: template (validate fragment, notify) → `command: sshd -t` (whole config) → handler reloads at the end. If the full check fails, the play stops *before* the reload, so the running sshd keeps the old config.
