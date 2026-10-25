# 1.01 - Remove insecure client packages: Explanation

### Solution
```yaml
- name: Remove insecure client packages
  hosts: targets
  become: true
  tasks:
    - name: Remove telnet client
      ansible.builtin.package:
        name: telnet
        state: absent
```

### Why `package` and not `apt`/`dnf`
`package` looks at the fact `ansible_facts.pkg_mgr` and calls the matching module.
For simple install/remove that is perfect. As soon as you need manager-specific
options (`autoremove`, `update_cache`, repos) you switch to the specific module.

### Names differ between distributions
Telnet is `telnet` on most systems, but part of `inetutils` on Arch (together with
`hostname`!) and of `busybox-extras` on Alpine. Blindly removing `inetutils` on
Arch would also remove `hostname`. This is why stage 2 introduces per-family
variables.

### Debian/Ubuntu: transitional packages
On current Debian/Ubuntu `telnet` can be an empty transitional package that pulls in
`inetutils-telnet`. Removing `telnet` leaves the binary in place. Always verify the
*effect* (binary gone), not only the package state - the CIS audit procedure does
the same.

### Check mode
`--check --diff` shows what *would* change without changing anything. Use it before
every hardening run in production.

## Reference solution

Show it with `lab solution 1.01`, apply it with `lab solve 1.01`.
