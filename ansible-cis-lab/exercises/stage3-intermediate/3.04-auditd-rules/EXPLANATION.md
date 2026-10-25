# 3.04 - auditd: rules and log retention (Level 2): Explanation

### Data-driven rule files
One dict, one template, one loop. Adding a topic = adding a key. Removing a topic
needs a cleanup task (`find` + `file: state=absent` for `50-cis-*.rules` not in the
dict) - a nice extension.

### What the rules capture
| Key | Question it answers in an incident |
|---|---|
| `scope`, `sudo_log_file` | who changed sudo rights / tampered with the sudo log? |
| `user_emulation` | who ran commands as *another* user? |
| `time-change` | did someone move the clock to confuse log correlation? |
| `identity` | who created/modified accounts, PAM or name resolution? |
| `logins` | failed/successful login records touched? |
`-k` sets the key you later search for: `ausearch -k identity`.

### `-e 2`
Makes the rule set immutable until reboot - an attacker with root cannot simply
`auditctl -D`. It must be the *last* rule loaded, hence the `99-` prefix.

### auditd.conf choices
- `keep_logs` - rotate without deleting (disk planning becomes your job!).
- `space_left_action = email` → early warning; `admin_space_left_action = single` →
  stop the system rather than run unaudited. That is a business decision; L2 means
  "you accept that trade-off".

### The container lesson
Kernel features fall into two groups: namespaced (network, mounts, PIDs, some sysctls)
and global (audit, modules, most `kernel.*`). Containers isolate the first group only.
Hardening code needs a switch for environments where it must not touch the second
group - that is what `lab_in_container` models.

## Reference solution

Show it with `lab solution 3.04`, apply it with `lab solve 3.04`.
