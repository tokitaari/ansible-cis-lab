# 2.02 - SSH server hardening with a Jinja2 template

## Hint 1

Template syntax: `MaxAuthTries {{ sshd_max_auth_tries }}`, `Ciphers {{ sshd_ciphers | join(',') }}`. Comment line: `{{ ansible_managed | comment }}`.

## Hint 2

The full-config check is a `command: /usr/sbin/sshd -t` task with `changed_when: false`. Put it *after* the template task but think about *when* handlers run - should the check run before or after the reload? (`ansible.builtin.meta: flush_handlers`)

## Hint 3

```yaml
- name: CIS 5.1 - SSH server hardening
  hosts: "..."
  become: "..."
  vars:
    sshd_max_auth_tries: "..."   # one variable per value of the README table
    sshd_ciphers: ["..."]        # lists, joined in the template
  tasks:
    - name: Deploy sshd hardening drop-in
      ansible.builtin.template:
        src: "..."               # the .j2 file in templates/
        dest: "..."
        owner: root
        group: root
        mode: "..."
        validate: "..."          # sshd tests the fragment alone (%s)
      notify: "..."
    - name: Validate the complete sshd configuration
      ansible.builtin.command: "..."   # sshd -t, without -f
      changed_when: "..."
  handlers:
    - name: Reload sshd
      ansible.builtin.service:
        name: "..."              # ssh on Debian, sshd elsewhere
        state: "..."
```

The template sets every key the check asserts - also `PermitRootLogin`, `PermitEmptyPasswords` and `X11Forwarding`, or the legacy drop-in supplies them. The full check runs before the handler, which reloads at the end of the play.

Reference: `lab solution 2.02`.
