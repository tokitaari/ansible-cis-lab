# 3.05 - Account audit: UID 0, empty passwords, umask, TMOUT

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 3 - Intermediate | ★★★☆☆ | ~50 min | 5.4.2 / 5.4.3 User accounts and environment (L1) | `targets` |

**Concepts:** `parsing files into facts`, `selectattr on lists`, `user module`, `profile.d`

## Goal

Find and fix dangerous accounts (a second UID 0 account, accounts with empty passwords) and set a safe default shell environment.

## Background

This exercise starts with *discovery*. Two hosts have an extra account with UID 0
(`toor`), two hosts have an account without a password (`guest`). You are not told
which - your playbook must find them.

CIS 5.4.2: root must be the only UID 0 account; no account may have an empty password
field. CIS 5.4.3: default `umask` 027 (new files not readable by "others"), shell
timeout `TMOUT` ≤ 900 seconds, `readonly` so users cannot unset it.

Removing a UID-0 account has a trap: `userdel toor` refuses ("user is currently used
by process 1") because *root's* processes have UID 0 too.

## Requirements

- [ ] Read `/etc/passwd` and `/etc/shadow` with `slurp` and compute two lists: UID-0 accounts other than root, and accounts whose password field is empty.
- [ ] Remove the extra UID-0 accounts (`ansible.builtin.user`, think about `force`), lock the empty-password accounts (`password_lock: true`).
- [ ] Print what was found (`debug`) - the audit trail matters.
- [ ] `/etc/profile.d/50-cis-umask.sh` sets `umask 027`; `/etc/profile.d/50-cis-tmout.sh` sets `TMOUT=900`, `readonly TMOUT`, `export TMOUT`. Both `0644 root:root`.
- [ ] Second run: `changed=0`. Add to your role as `section5_accounts.yml` (tag `accounts`).

## How to work

```bash
lab start 3.05            # creates /lab/work/3.05/
cd /lab/work/3.05
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 3.05            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 3.05 1` (gentle) ... `lab hint 3.05 3` (almost the answer).  
Passed? Read `lab explain 3.05` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Why does `force: true` work, and why would `remove: true` be dangerous for a UID-0 account whose home is `/root`?
- CIS also wants root's `PATH` without `.` or empty entries, and every home directory `0750` or stricter. Add one of them.
