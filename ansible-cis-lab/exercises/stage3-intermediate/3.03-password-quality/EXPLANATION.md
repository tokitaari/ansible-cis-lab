# 3.03 - Password quality with pam_pwquality: Explanation

### Why drop-ins
`pwquality.conf` belongs to the package. `pwquality.conf.d/50-cis.conf` is yours -
package updates never conflict with it, and removing the control means removing one file.

### PAM ownership
Hand-editing `/etc/pam.d/*` is the most common way to break logins *and* the most
common reason hardening is silently reverted:
- **Debian/Ubuntu**: `pam-auth-update` regenerates `common-*` from profiles. A manual
  edit is overwritten on the next package that calls it.
- **RHEL/Fedora**: `system-auth` is a symlink into `/etc/authselect/`. `authselect
  select ... --force` or `authselect apply-changes` overwrites manual edits.
Work *with* the tool: enable profiles/features, never patch generated files.

### `enforce_for_root`
Without it, root can set any password (pwquality only warns). CIS wants root covered too.

### chpasswd (bonus)
`chpasswd` and `usermod -p` do not go through the PAM *password* stack for quality
checks (chpasswd uses PAM only for some modes). Quality rules protect interactive
password changes, not administrative bulk tools. That is fine - but know it.

### Containers
The lab images run real PAM stacks, so the configuration is identical to a VM. What
you cannot test here is console login.

## Reference solution

Show it with `lab solution 3.03`, apply it with `lab solve 3.03`.
