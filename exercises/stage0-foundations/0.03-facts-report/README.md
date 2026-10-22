# 0.03 - Facts: one report across eight distributions

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 0 - Foundations | ★★☆☆☆ | ~30 min | - (-) | `targets` |

**Concepts:** `facts`, `hostvars`, `template`, `delegation to localhost`

## Goal

Collect the facts that drive multi-distro automation and write them into a CSV on the control node.

## Background

Before hardening anything you need to know *what* you are hardening. Facts such as
`os_family`, `pkg_mgr` and `service_mgr` decide which package names, paths and
service commands apply. You will use exactly these facts in every later exercise.

## Requirements

- [ ] Gather facts from all targets (do 0.02 first so Alpine has Python).
- [ ] Create `/lab/work/0.03/facts.csv` on the control node with this exact header:
  `host,distribution,version,os_family,pkg_mgr,service_mgr,python`
- [ ] One line per target (8 data lines), values taken from facts.
- [ ] Use `ansible.builtin.template` and `hostvars` - no shell `echo >>`.

## How to work

```bash
lab start 0.03            # creates /lab/work/0.03/
cd /lab/work/0.03
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 0.03            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 0.03 1` (gentle) ... `lab hint 0.03 3` (almost the answer).  
Passed? Read `lab explain 0.03` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Make the report robust: an unreachable host should show `unreachable` instead of crashing the template.
- Sort the lines by `os_family`, then by host.
