# 2.02 - SSH server hardening with a Jinja2 template: Explanation

### Solution (excerpt)
```yaml
tasks:
  - name: Deploy sshd hardening drop-in
    ansible.builtin.template:
      src: sshd_cis.conf.j2
      dest: /etc/ssh/sshd_config.d/00-cis-hardening.conf
      owner: root
      group: root
      mode: "0600"
      validate: /usr/sbin/sshd -t -f %s
    notify: Reload sshd
  - name: Validate the complete sshd configuration
    ansible.builtin.command: /usr/sbin/sshd -t
    changed_when: false
handlers:
  - name: Reload sshd
    ansible.builtin.service:
      name: "{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"
      state: reloaded
```
Full files: `lab solution 2.02`.

### Two validation layers
1. `validate:` checks the fragment in isolation, *before* it replaces the file.
2. `sshd -t` checks what sshd would actually load (main file + all drop-ins).
If (2) fails, the play aborts and the handler never runs → the running daemon keeps
its old, working configuration. You then fix and re-run. That ordering is the whole
trick: handlers run at the end of the play.

### Lock-out analysis (bonus)
- `AllowGroups ansible` - only members of group `ansible` may log in. The lab user is
  in that group. In production this list must contain your admin group *and* your
  automation account - a classic outage.
- `PermitRootLogin no` - fine, Ansible logs in as `ansible` and uses sudo.
- `KexAlgorithms` - the control node's OpenSSH must share at least one algorithm.
  Very old clients (e.g. legacy jump hosts) may fail.
- `ClientAliveInterval 15` with `CountMax 3` - Ansible's `ControlPersist` connections
  survive because the client answers keepalives.

### crypto-policies (bonus)
On EL/Fedora `50-redhat.conf` includes the system crypto policy. Your `00-` file is
read first, so your algorithm lists win. Alternative on those systems: a custom
crypto-policy module (`update-crypto-policies --set DEFAULT:CIS`) - cleaner, but
Red Hat specific.

### Why `ansible_managed`
It tells the next admin "don't edit by hand, your change will be overwritten".

## Reference solution

Show it with `lab solution 2.02`, apply it with `lab solve 2.02`.
