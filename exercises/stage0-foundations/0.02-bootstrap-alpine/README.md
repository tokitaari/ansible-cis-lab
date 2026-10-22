# 0.02 - Bootstrap Python on Alpine with raw

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 0 - Foundations | ★☆☆☆☆ | ~20 min | - (-) | `alpine_family` |

**Concepts:** `raw`, `gather_facts: false`, `changed_when`, `become`

## Goal

Make the Alpine host manageable by installing Python with the only module that works without it.

## Background

`ansible.builtin.raw` executes a command over SSH without any Python on the
target. It is the standard way to bootstrap minimal systems. Because `raw` cannot
report whether it changed something, *you* have to tell Ansible via `changed_when`,
otherwise every run shows "changed" and the playbook is not idempotent.

## Requirements

- [ ] Write `playbook.yml` with one play for `alpine_family`.
- [ ] Disable fact gathering (facts need Python!).
- [ ] Install `python3` with `apk` using `ansible.builtin.raw` - only if it is missing.
- [ ] The task must report `changed` only when it actually installed something.
- [ ] Prove it works: a second task runs `ansible.builtin.ping`.

## How to work

```bash
lab start 0.02            # creates /lab/work/0.02/
cd /lab/work/0.02
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 0.02            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 0.02 1` (gentle) ... `lab hint 0.02 3` (almost the answer).  
Passed? Read `lab explain 0.02` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Why is `become: true` needed, and how does `raw` handle it?
- Security view: every package is attack surface. Which alternative would avoid Python on the host altogether? (Think about what Ansible could do with `raw` alone.)
