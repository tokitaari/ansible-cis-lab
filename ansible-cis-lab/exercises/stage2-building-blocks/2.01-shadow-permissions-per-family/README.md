# 2.01 - /etc/shadow: correct permissions per OS family

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 2 - Building blocks | ★★☆☆☆ | ~35 min | 7.1 System file permissions (L1) | `targets` |

**Concepts:** `vars`, `dict lookup by fact`, `stat + register`, `loop over results`

## Goal

Fix the world-readable `/etc/shadow` (and `/etc/gshadow` where it exists) - using each distribution's own convention.

## Background

Somebody set `/etc/shadow` to `0644`: every user can read all password hashes and
crack them offline. The fix looks trivial, but distributions disagree on the
*correct* value:

| Family | Owner:Group | Mode |
|---|---|---|
| Debian, Suse, Alpine | `root:shadow` | `0640` |
| RedHat | `root:root` | `0000` |
| Archlinux | `root:root` | `0600` |

The `shadow` group exists so that helpers like `unix_chkpwd` can verify passwords
without root. Setting group `root` on Debian breaks screen lockers. CIS accepts
"owner root, group root **or shadow**, mode 0640 or more restrictive" - so the
right answer is: keep each family's convention.

## Requirements

- [ ] Define a variable (dict) that maps `ansible_facts.os_family` to group and mode.
- [ ] Apply it to `/etc/shadow` and to `/etc/gshadow` **if it exists** (it does not everywhere).
- [ ] Use `ansible.builtin.stat` + `register` + a loop over the results.
- [ ] No `when: ansible_facts.os_family == ...` chains - one data structure, one task.
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 2.01            # creates /lab/work/2.01/
cd /lab/work/2.01
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 2.01            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 2.01 1` (gentle) ... `lab hint 2.01 3` (almost the answer).  
Passed? Read `lab explain 2.01` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Add the backup files `/etc/shadow-` and `/etc/gshadow-` to the list. How much code did that cost?
- Move the dict into `/lab/work/2.01/group_vars/...`? Careful - group_vars next to a *playbook* only work for groups. Which group names would you need?
