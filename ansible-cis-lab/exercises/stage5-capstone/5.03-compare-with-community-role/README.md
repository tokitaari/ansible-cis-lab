# 5.03 - Review: your role vs. a community CIS role

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 5 - Capstone | ★★★★☆ | ~90 min | all (L1/L2) | `(reading)` |

**Concepts:** `code review`, `benchmark coverage`, `build vs. buy`

## Goal

Read a mature open-source CIS role critically and decide - with arguments - what you would adopt, what you would build yourself, and what you would never run unreviewed.

## Background

The *ansible-lockdown* project (GitHub organisation `ansible-lockdown`) maintains CIS
and STIG roles per distribution, e.g. for RHEL, Ubuntu, Debian. They implement several
hundred controls, toggles per control, and an audit component. Now that you have built
a smaller version yourself, you can read them with an expert's eye.

Pick the role that matches one of the lab platforms. Clone it on the control node
(`git clone` works there) into `/lab/work/5.03/`. You may run it in `--check` mode
against a freshly reset host - never in enforce mode without reading what it does.

## Requirements

- [ ] Write `/lab/work/5.03/review.md` answering the questions below (at least a short paragraph each).
- [ ] 1. How does the role switch individual controls on/off? Compare with your registry/exception design.
- [ ] 2. How does it handle Level 1 vs Level 2, and server vs workstation?
- [ ] 3. Which controls are disabled by default, and why might the maintainers have chosen that?
- [ ] 4. Find two controls that could lock you out or break an application. How are they guarded?
- [ ] 5. How does it audit (check mode? separate tool?) and report?
- [ ] 6. Your decision for a 500-server environment: adopt, fork, or build - and what would your acceptance tests be?

## How to work

```bash
lab start 5.03            # creates /lab/work/5.03/
cd /lab/work/5.03
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 5.03            # verifies the state
```

Stuck? `lab hint 5.03 1` (gentle) ... `lab hint 5.03 3` (almost the answer).  
Passed? Read `lab explain 5.03` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Run it in `--check --diff` against one freshly reset host and count the would-be changes. Compare with your own audit report from 5.01.
- Look at the project's CI: which platforms and scenarios are tested on every change?
