# Learning path

*[Deutsch](LEARNING_PATH.de.md)*

The lab is built so that **beginners and experienced admins use the same exercises** without
being bored or overwhelmed:

| Mechanism | For beginners | For experienced users |
|---|---|---|
| Placement test (`lab placement`) | start at 0.01 | skip to stage 2 or 3, `lab solve` the earlier ones |
| Three graded hints per exercise | hint 1 → 2 → 3 until it clicks | ignore them |
| Requirements as checklist | clear finish line | the minimum, not the goal |
| Bonus tasks | optional | where the real depth is |
| Explanations after passing | consolidate the concept | pitfalls, alternatives, production notes |
| Automatic checks incl. idempotency | immediate feedback | catches "works once" solutions |

## Stages

| Stage | You can afterwards ... | Time |
|---|---|---|
| **0 Foundations** | read an inventory, run ad-hoc commands, bootstrap a host without Python, use facts, write an idempotent playbook | ~1.5 h |
| **1 Beginner** | remove packages, fix permissions, change sshd and sudo *safely* (validate, handlers), use conditionals | ~2 h |
| **2 Building blocks** | express platform differences as data, loop, template, use collections, separate namespaced from global kernel settings | ~3.5 h |
| **3 Intermediate** | structure everything as a role with tags, wrap CLIs idempotently, work with PAM tooling, design audit rules | ~4.5 h |
| **4 Advanced** | write audit-only reports, implement profiles and exceptions, build data-driven multi-platform roles, handle secrets, roll out firewalls safely, run long jobs async | ~9.5 h |
| **5 Capstone** | deliver a production-grade CIS role with audit/enforce mode and a safe rollout, and review third-party roles critically | ~7 h |

## Recommended order and dependencies

- **0.02 first** (or `lab solve 0.02`): Alpine needs Python for every later module.
- Stage 2 exercises are independent of each other.
- **3.01** collects 0.04-2.06 into a role; **4.03** extends it with stage 3; **5.01** turns it into the capstone.
- 4.01, 4.02, 4.04-4.08 are independent "toolbox" exercises - pick by interest.
- Before 3.01, 4.03 and 5.01: `./lab.sh reset all` so that the regression checks prove your role works on fresh hosts.

## Working style that pays off

1. Read the README **and** look at the current state first (`ansible ... -m command -a ...`).
2. Run with `--check --diff` before applying.
3. `lab check` → read the messages → only then use hints.
4. After passing, always read `lab explain` - most of the transferable knowledge is there.
5. Keep your solutions in `./work` under Git; compare with `lab solution` only afterwards.
