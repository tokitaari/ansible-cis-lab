# 3.02 - Password aging and inactive accounts

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 3 - Intermediate | ★★★☆☆ | ~45 min | 5.4.1 Shadow password suite parameters (L1) | `targets` |

**Concepts:** `lineinfile`, `regexp`, `slurp + regex_findall`, `vendor config split`, `command idempotency`

## Goal

Set password aging defaults in `login.defs`, a strong hashing method, and automatic locking of inactive accounts - without breaking systems that already use something stronger.

## Background

CIS 5.4.1 (values used here):

| Setting | Value | File |
|---|---|---|
| `PASS_MAX_DAYS` | `365` (≤ 365) | `/etc/login.defs` |
| `PASS_MIN_DAYS` | `1` (≥ 1) | `/etc/login.defs` |
| `PASS_WARN_AGE` | `7` (≥ 7) | `/etc/login.defs` |
| `ENCRYPT_METHOD` | `SHA512` **or** `YESCRYPT` | `/etc/login.defs` |
| inactive lock | `45` days (≤ 45) | `useradd -D -f 45` → `/etc/default/useradd` |

Two traps:
1. **Do not downgrade.** Debian 13, Fedora and Arch already default to `YESCRYPT`.
   Overwriting it with `SHA512` would be *weaker*. Only change it when the current
   method is neither.
2. **Vendor config split.** Some distributions (openSUSE in particular) are moving
   defaults to `/usr/etc/` and read overrides from `/etc/login.defs.d/*.defs`.
   If `/etc/login.defs` does not exist, creating it would *replace* all vendor
   defaults. Use a drop-in instead. Find out which hosts behave how.

## Requirements

- [ ] Playbook `/lab/work/3.02/playbook.yml` for `targets` (also add the tasks to your role as `section5_password_policy.yml` with tag `password`).
- [ ] Where `/etc/login.defs` exists: set the three `PASS_*` values with `lineinfile` (one task, loop).
- [ ] Where it does not exist: write the same values to `/etc/login.defs.d/50-cis.defs`.
- [ ] `ENCRYPT_METHOD` becomes `SHA512` only if it is currently neither `SHA512` nor `YESCRYPT`.
- [ ] Inactive lock 45 days via `useradd -D -f 45` - the task reports `changed` only when it really changed something.
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 3.02            # creates /lab/work/3.02/
cd /lab/work/3.02
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 3.02            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 3.02 1` (gentle) ... `lab hint 3.02 3` (almost the answer).  
Passed? Read `lab explain 3.02` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- The new defaults only apply to *new* accounts. Write a task that applies `PASS_MAX_DAYS` to existing users with a password hash (`chage --maxdays`). Hint: parse `/etc/shadow`; skip locked (`!`/`*`) entries.
- Is `lineinfile` the right tool for 3 keys? Compare with a templated drop-in on all systems.
