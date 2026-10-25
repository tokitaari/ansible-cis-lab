# 0.04 - First hardening playbook: SSH warning banner: Explanation

### Solution
```yaml
- name: Set a neutral SSH warning banner
  hosts: targets
  become: true
  tasks:
    - name: Write /etc/issue.net
      ansible.builtin.copy:
        dest: /etc/issue.net
        content: |
          Authorized access only. Activity on this system is monitored and logged.
        owner: root
        group: root
        mode: "0644"
```

### Idempotency - the core idea of Ansible
`copy` compares checksum, owner, group and mode with the desired state and only
acts on differences. Second run → `ok`, not `changed`. Every task you write from now
on must behave like this. `lab check` verifies it with a `--check` run.

### Pitfall: unquoted modes
`mode: 644` is YAML integer 644 = octal 1204 → a sticky, weird permission.
`mode: 0644` works in YAML 1.1 but is fragile. Always quote: `mode: "0644"`.

### Note: the banner is not shown yet
sshd only displays `/etc/issue.net` when `Banner /etc/issue.net` is configured.
That is part of the sshd hardening in 2.02.

### Real world
Banner text is often a legal requirement (works council, legal department).
Keep it in a variable so it can be changed centrally - you will do that in 2.06.

## Reference solution

Show it with `lab solution 0.04`, apply it with `lab solve 0.04`.
