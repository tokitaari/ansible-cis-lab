# 1.05 - sudo: use a PTY and log to a file: Explanation

### Solution
```yaml
- name: Harden sudo
  hosts: targets
  become: true
  tasks:
    - name: Deploy sudo defaults
      ansible.builtin.copy:
        dest: /etc/sudoers.d/50-cis
        content: |
          Defaults use_pty
          Defaults logfile="/var/log/sudo.log"
        owner: root
        group: root
        mode: "0440"
        validate: /usr/sbin/visudo -cf %s
```

### Why drop-in files
`/etc/sudoers` belongs to the distribution package. `/etc/sudoers.d/` is read via
`@includedir` - your file can be added and removed cleanly. Files in that directory
containing a `.` or ending in `~` are **ignored** - `50-cis.conf` would silently do
nothing!

### validate saves you
Without validation a single typo disables sudo on all hosts in seconds. Recovery
would need console access (or here: `./lab.sh reset`). In production this pattern is
non-negotiable.

### Notes
- sudo 1.9.14+ enables `use_pty` by default; setting it explicitly documents intent
  and covers older versions.
- `logfile` is in addition to syslog/journal, not instead.
- Ansible's own sudo calls now appear in `/var/log/sudo.log` - take a look.

## Reference solution

Show it with `lab solution 1.05`, apply it with `lab solve 1.05`.
