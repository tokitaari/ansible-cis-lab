# 1.05 - sudo: use a PTY and log to a file

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 1 - Beginner | ★★☆☆☆ | ~25 min | 5.2 Configure privilege escalation (L1) | `targets` |

**Concepts:** `sudoers.d`, `validate: visudo`, `lockout prevention`

## Goal

Configure sudo so that commands run in a pseudo-terminal and every sudo use is logged to `/var/log/sudo.log`.

## Background

`use_pty` stops a background process started via sudo from injecting keystrokes
into your terminal after the command finished. A dedicated sudo log makes privilege
use auditable (stage 3 adds an audit rule on that file).

**Danger:** a syntax error in sudoers breaks sudo - and Ansible uses sudo to become
root. You would lock yourself out of every host at once. `visudo -cf` validates a
file before it is installed. (If it happens anyway: `./lab.sh reset <host>`.)

## Requirements

- [ ] Create `/etc/sudoers.d/50-cis` with `Defaults use_pty` and `Defaults logfile="/var/log/sudo.log"`.
- [ ] Owner `root:root`, mode `0440`.
- [ ] Validate with `visudo -cf %s` before installation.
- [ ] `visudo -c` on the host reports no errors, and Ansible can still become root.

## How to work

```bash
lab start 1.05            # creates /lab/work/1.05/
cd /lab/work/1.05
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 1.05            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 1.05 1` (gentle) ... `lab hint 1.05 3` (almost the answer).  
Passed? Read `lab explain 1.05` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Break it on purpose: add a typo, run with `-l debian`. What does Ansible report, and is the host still manageable?
- Add `Defaults timestamp_timeout=15`. What does it control?
