# 1.02 - Permissions on /etc/passwd and /etc/group

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 1 - Beginner | ★☆☆☆☆ | ~20 min | 7.1 System file permissions (L1) | `targets` |

**Concepts:** `file`, `mode`, `owner`, `octal pitfalls`

## Goal

Fix the group-writable `/etc/passwd` and `/etc/group` on every target.

## Background

Someone set both files to `0664`. A group-writable `/etc/passwd` lets members of
that group create a UID-0 account - game over. CIS requires `0644` (or stricter),
owner `root`, group `root`. Check the current state first:
`ansible targets -m ansible.builtin.stat -a path=/etc/passwd | grep '"mode"'`

## Requirements

- [ ] `/etc/passwd` and `/etc/group`: mode `0644`, owner `root`, group `root`.
- [ ] Use `ansible.builtin.file` (one task per file is fine - loops come in stage 2).
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 1.02            # creates /lab/work/1.02/
cd /lab/work/1.02
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 1.02            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 1.02 1` (gentle) ... `lab hint 1.02 3` (almost the answer).  
Passed? Read `lab explain 1.02` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- What happens if you write `mode: 644` (no quotes, no leading zero)? Try it on one host (`-l debian`), look at the result with `stat`, then fix it. Reset with `./lab.sh reset debian` if needed.
- CIS also covers the backup files `/etc/passwd-` and `/etc/group-`. Include them - but they do not exist everywhere. How do you handle that?
