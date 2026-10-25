# 1.03 - SSH: forbid root login and empty passwords

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 1 - Beginner | ★★☆☆☆ | ~35 min | 5.1 SSH server (L1) | `targets` |

**Concepts:** `copy`, `validate`, `handlers`, `notify`, `sshd drop-ins`

## Goal

Make sshd refuse root logins and empty passwords - safely, without locking yourself out.

## Background

A previous admin left `/etc/ssh/sshd_config.d/10-lab-legacy.conf` with
`PermitRootLogin yes` and `PermitEmptyPasswords yes`. Combine that with an account
that has an empty password (there is one on two hosts...) and anyone can log in.

Important sshd rule: **the first value found wins**. `sshd_config` includes
`sshd_config.d/*.conf` at its top, files are read in lexical order. Check the *effective* configuration with `sshd -T` (as root), not the file.

A broken sshd config + restart = you are locked out. Two Ansible features prevent
that: `validate` (test the file before it is put in place) and handlers (restart
only when something changed).

## Requirements

- [ ] Create `/etc/ssh/sshd_config.d/00-cis-hardening.conf` with `PermitRootLogin no` and `PermitEmptyPasswords no`.
- [ ] File owner `root:root`, mode `0600`.
- [ ] Validate the file with `sshd -t` before it is installed.
- [ ] Reload sshd via a **handler**, only when the file changed. Service name: `ssh` on the Debian family, `sshd` everywhere else.
- [ ] `sshd -T` reports `permitrootlogin no` and `permitemptypasswords no` on all hosts.
- [ ] Do **not** delete the legacy file - make yours win.

## How to work

```bash
lab start 1.03            # creates /lab/work/1.03/
cd /lab/work/1.03
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 1.03            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 1.03 1` (gentle) ... `lab hint 1.03 3` (almost the answer).  
Passed? Read `lab explain 1.03` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Why `00-` and not `99-`? Rename your file to `99-cis-hardening.conf` on one host and look at `sshd -T`.
- Why `reloaded` instead of `restarted`? What happens to existing sessions in each case?
