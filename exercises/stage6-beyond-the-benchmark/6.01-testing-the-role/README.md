# 6.01 - Testing a role: Molecule scenario with testinfra

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 6 - Beyond the benchmark | ★★★★☆ | ~90 min | - (-) | `targets` |

**Concepts:** `Molecule scenario`, `default driver`, `test sequence`, `testinfra`, `expected values from the requirements`

## Goal

Write a Molecule scenario with testinfra tests for the small role `cis_mini`, run it against the eight lab targets, and make `molecule test` pass - by fixing the role wherever the scenario finds a fault, not by making the tests weaker.

## Background

A colleague wrote `cis_mini` - three controls you know from stages 1 and 2 - and says it is
finished. Before it goes into the real role it gets tests: Molecule runs the role, runs it a second
time to see that nothing changes, then testinfra reads the state of each host and compares it with
what the role must achieve. `lab start 6.01` copies the role to `/lab/work/roles/cis_mini`.

These are the requirements of the role - write your tests from this table:

| | Files | Owner | Group and mode |
|---|---|---|---|
| R1 | `/etc/passwd`, `/etc/group` | root | root, 0644 |
| R2 | `/etc/shadow`, and `/etc/gshadow` where it exists | root | Debian, Suse, Alpine: shadow, 0640 · RedHat: root, 0000 · Archlinux: root, 0600 |
| R3 | `/etc/issue`, `/etc/issue.net` | root | root, 0644; the content is exactly the text of `cis_mini_banner` followed by one newline |

Molecule's usual drivers create test machines and throw them away. The lab already has eight, so
the scenario uses the `default` driver and points at them. Molecule then runs Ansible with a
configuration of its own - lesson L18 explains what that takes away and how to bring it back.
Read it first.

## Requirements

- [ ] A scenario `default` in `/lab/work/6.01/molecule/default/` converges the role `cis_mini` from `/lab/work/roles` on the eight hosts of the lab inventory (group `targets`).
- [ ] Its test sequence runs `converge`, `idempotence` and `verify`, in this order. The verifier is testinfra, with the tests in `molecule/default/tests/test_*.py`.
- [ ] The tests cover R1, R2 and R3 on every target. Their expected values come from the table above, not from the role's files.
- [ ] `molecule test` passes in `/lab/work/6.01`. Where the role does not meet a requirement, fix the role in `/lab/work/roles/cis_mini` - the tests stay strict.
- [ ] A test fails on a target that breaks one requirement, and none fails on the others: `lab check 6.01` breaks one requirement on each of six targets on purpose, runs `molecule verify` and converges them back.

## How to work

```bash
lab start 6.01            # creates /lab/work/6.01/ and copies the role to /lab/work/roles/cis_mini
cd /lab/work/6.01
# write molecule/default/molecule.yml, converge.yml and tests/test_*.py, then:
molecule converge         # only the role run
molecule verify           # only the tests, against the state the targets have now
molecule test             # the whole sequence
lab check 6.01            # molecule test, the requirements, then six broken targets (~3 min)
```

Stuck? `lab hint 6.01 1` (gentle) ... `lab hint 6.01 3` (almost the answer).  
Passed? Read `lab explain 6.01` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Write the same checks a second time with Molecule's Ansible verifier (`verifier: name: ansible` and a `verify.yml` with `ansible.builtin.assert`) in a second scenario, and run it with `molecule test -s <name>`. Compare the failure messages with testinfra's.
- Add a scenario `cis` that converges your 5.01 role from `/lab/work/roles/cis` in enforce mode, and test three of its controls with testinfra. How long does the idempotence step take there, compared with `cis_mini`?
- The tag `molecule-idempotence-notest` keeps a task out of the idempotence step. Find a task in your 5.01 role where that would be right - and one where it would only hide a bug.
- Break a requirement in a `side_effect` playbook instead of by hand, and give a second scenario the sequence `converge`, `side_effect`, `verify`. What must `molecule test -s <name>` report then?
