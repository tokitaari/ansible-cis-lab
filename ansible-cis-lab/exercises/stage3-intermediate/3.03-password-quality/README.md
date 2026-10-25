# 3.03 - Password quality with pam_pwquality

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 3 - Intermediate | ★★★☆☆ | ~45 min | 5.3.3 PAM arguments (pwquality) (L1) | `debian_family:redhat_family` |

**Concepts:** `per-family packages`, `drop-in configs`, `PAM stacks`, `authselect / pam-auth-update`

## Goal

Enforce strong passwords through `pam_pwquality` on the Debian and Red Hat families - and understand how each family wires PAM.

## Background

CIS values: `minlen = 14`, `minclass = 4` (or equivalent credits), `maxrepeat = 3`,
`maxsequence = 3`, `dictcheck = 1`, `enforce_for_root`.

The config is easy - `/etc/security/pwquality.conf.d/*.conf` drop-ins are read by
libpwquality on all current systems. The interesting part is *PAM*: the module must
actually be in the password stack, and every family manages PAM differently:

| Family | Package | Who edits PAM |
|---|---|---|
| Debian | `libpam-pwquality` | `pam-auth-update` (profiles in `/usr/share/pam-configs`) |
| RedHat | `libpwquality` | `authselect` (never edit `/etc/pam.d/system-auth` by hand) |
| Suse / Arch / Alpine | various / none | `pam-config` / manual / Alpine has no PAM by default |

Scope of this exercise: `debian_family:redhat_family`. The others are a bonus.

## Requirements

- [ ] Install the right package per family (dict lookup).
- [ ] Write `/etc/security/pwquality.conf.d/50-cis.conf` (`root:root`, `0644`) with the CIS values, generated from a dict variable.
- [ ] Debian family: `pam_pwquality` appears in `/etc/pam.d/common-password` (installing the package normally enables it - verify, and enable the profile with `pam-auth-update --enable pwquality` only if missing).
- [ ] Red Hat family: `pam_pwquality` appears in `/etc/pam.d/system-auth`; check `authselect current` and do not edit PAM files directly.
- [ ] Second run: `changed=0`. Add the tasks to your role (tag `pam`).

## How to work

```bash
lab start 3.03            # creates /lab/work/3.03/
cd /lab/work/3.03
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 3.03            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 3.03 1` (gentle) ... `lab hint 3.03 3` (almost the answer).  
Passed? Read `lab explain 3.03` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- openSUSE: `pam-config --add --pwquality`. Arch: which PAM file would you change, and why is that riskier?
- Alpine: no PAM - which mechanism enforces password quality there? (Is it a CIS gap you would document as an exception?)
- Test it: `sudo -u ansible passwd` is pointless (no password). Create a test user and try `echo 'test:abc' | chpasswd` - does pwquality apply to `chpasswd`? Why not?
