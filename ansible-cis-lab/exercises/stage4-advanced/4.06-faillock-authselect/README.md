# 4.06 - Account lockout with pam_faillock (authselect)

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★☆ | ~45 min | 5.3.2 / 5.3.3.1 pam_faillock (L1) | `redhat_family` |

**Concepts:** `authselect features`, `idempotent CLI wrappers`, `faillock.conf`, `lock-out risk analysis`

## Goal

Lock accounts after 5 failed logins for 15 minutes on the Red Hat family - using `authselect`, not by editing PAM files.

## Background

`pam_faillock` counts failed authentications and locks the account. On EL/Fedora PAM
belongs to `authselect`; the feature is called `with-faillock`. Settings live in
`/etc/security/faillock.conf` (CIS: `deny` ≤ 5, `unlock_time` ≥ 900 or 0).

Lock-out analysis before you start: Ansible authenticates with an SSH **key**. Does
faillock affect key logins? (Think about which PAM phases sshd runs for public-key
authentication.) The answer decides whether this exercise can lock *you* out.

## Requirements

- [ ] `authselect current` shows the feature `with-faillock`. Enable it only if missing (no unconditional command).
- [ ] `/etc/security/faillock.conf`: `deny = 5`, `unlock_time = 900`.
- [ ] `/etc/pam.d/system-auth` and `/etc/pam.d/password-auth` contain `pam_faillock`.
- [ ] Hosts: `redhat_family`. Second run: `changed=0`.

## How to work

```bash
lab start 4.06            # creates /lab/work/4.06/
cd /lab/work/4.06
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 4.06            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.06 1` (gentle) ... `lab hint 4.06 3` (almost the answer).  
Passed? Read `lab explain 4.06` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Debian/Ubuntu: write a `pam-auth-update` profile (`/usr/share/pam-configs/faillock`) and enable it. Look at the format of an existing profile first.
- `faillock --user guest` / `faillock --user guest --reset`: try a few wrong `su guest` attempts (create a password for a test user first).
- Should root be locked (`even_deny_root`)? What does CIS say, and what is the operational risk?
