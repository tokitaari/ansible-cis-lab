# 1.04 - Stop and disable the FTP server: Explanation

### Solution
```yaml
- name: Disable the FTP server
  hosts: targets
  become: true
  tasks:
    - name: Collect package facts
      ansible.builtin.package_facts:
    - name: Stop and disable vsftpd
      ansible.builtin.service:
        name: vsftpd
        state: stopped
        enabled: false
      when: "'vsftpd' in ansible_facts.packages"
```

### One module, two init systems
`service` detects `service_mgr` (fact) and talks to systemd (`systemctl`) or OpenRC
(`rc-service`/`rc-update`). For systemd-only features (`masked`, `daemon_reload`)
use `ansible.builtin.systemd_service`.

### Why `package_facts` and not `ignore_errors: true`
`ignore_errors` hides *every* error - including the one you care about (typo in
the service name, permission problem). A precise condition documents intent.

### disable vs mask vs remove
- `enabled: false` - not started at boot, but anything can still start it.
- `masked: true` - linked to `/dev/null`, cannot be started at all (systemd).
- removing the package - the binary is gone. This is what CIS recommends; stop/mask
  is the fallback when a dependency needs the package.

### Order (bonus)
If you remove the package first, the service unit is gone too, and the stop task
would fail - unless your `when` still sees the *old* package facts (gathered before
removal). Facts are a snapshot; refresh them with another `package_facts` call
when the order matters.

## Reference solution

Show it with `lab solution 1.04`, apply it with `lab solve 1.04`.
