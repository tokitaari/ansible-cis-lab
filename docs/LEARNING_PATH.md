# Learning path

*[Deutsch](LEARNING_PATH.de.md)*

The lab is built so that **beginners and experienced admins use the same exercises** without
being bored or overwhelmed:

| Mechanism | For beginners | For experienced users |
|---|---|---|
| Lessons (`lab lesson`) | read before the exercises | skim, use the self-check to find gaps |
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

## Lessons

Each lesson explains the concepts behind a group of exercises - theory, CIS background,
platform differences, pitfalls and a self-check. Read it before you start the exercises:
`lab lesson <n>` or `lab lesson <exercise id>`; `lab lesson <n> answers` shows the self-check
answers. L01 belongs to no single exercise: read it after L00. The [glossary](GLOSSARY.md)
(`lab docs glossary`) explains the terms in a few lines each and links to the lesson sections.

| Lesson | Prepares | Reading time |
|---|---|---|
| [L00 - Lab architecture and Ansible basics](lessons/L00-lab-and-ansible-basics.md) | 0.01, 0.02, 0.03, 0.04 | ~25 min |
| [L01 - CIS Benchmarks: structure, levels and the lab catalogue](lessons/L01-cis-benchmarks.md) | - | ~25 min |
| [L02 - Safe changes: check mode, validate, handlers and conditionals](lessons/L02-safe-changes.md) | 1.01, 1.02, 1.03, 1.04, 1.05 | ~25 min |
| [L03 - Base hardening: packages, services, file permissions, SSH and sudo](lessons/L03-base-hardening.md) | 1.01, 1.02, 1.03, 1.04, 1.05, 2.01 | ~25 min |
| [L04 - Platform differences as data: dictionaries, loops, Jinja2 and templates](lessons/L04-platform-differences-as-data.md) | 2.01, 2.02, 2.06 | ~25 min |
| [L05 - Kernel hardening: modules and sysctl](lessons/L05-kernel-modules-and-sysctl.md) | 2.03, 2.04 | ~25 min |
| [L06 - Job schedulers: who runs what, and who may schedule it](lessons/L06-job-schedulers.md) | 2.05 | ~25 min |
| [L07 - Roles, tags and project structure: one baseline, many switches](lessons/L07-roles-tags-project-structure.md) | 3.01 | ~35 min |
| [L08 - Accounts and PAM: who may log in, how, and with what password](lessons/L08-accounts-and-pam.md) | 3.02, 3.03, 3.05, 4.06 | ~30 min |
| [L09 - Auditing and integrity: auditd, AIDE and long-running tasks](lessons/L09-auditing-and-integrity.md) | 3.04, 4.08 | ~35 min |
| [L10 - Compliance reporting: audit mode, enforce mode and custom facts](lessons/L10-compliance-reporting.md) | 4.01, 4.05, 5.01 | ~30 min |
| [L11 - Profiles, exceptions and data-driven roles: one role, many audiences](lessons/L11-profiles-exceptions-and-data-driven-roles.md) | 4.02, 4.03 | ~35 min |
| [L12 - Secrets with Ansible Vault: keeping a password out of Git and out of the log](lessons/L12-secrets-with-ansible-vault.md) | 4.04 | ~30 min |
| [L13 - Host firewall with nftables: changing the rules you reach the host through](lessons/L13-host-firewall-nftables.md) | 4.07 | ~30 min |
| [L14 - Production rollout: failure handling, preflight, batches and community roles](lessons/L14-production-rollout.md) | 5.02, 5.03 | ~35 min |

## Recommended order and dependencies

- **0.02 first** (or `lab solve 0.02`): Alpine needs Python for every later module.
- Stage 2 exercises are independent of each other.
- **3.01** collects 0.04-2.06 into a role; **4.03** extends it with stage 3; **5.01** turns it into the capstone.
- 4.01, 4.02, 4.04-4.08 are independent "toolbox" exercises - pick by interest.
- **Starter files** exist for the playbook exercises of stages 0-2, plus the empty role skeleton of 3.01. From stage 3 on you
  extend your own role and playbooks, so `lab start` mostly just creates the work directory.
- `lab start` warns when an exercise builds on one you have not passed yet (`requires` in its `meta.yml`).
- Before 3.01, 4.03 and 5.01: `./lab.sh reset all` so that the regression checks prove your role works on fresh hosts.

## Working style that pays off

1. Before you start, read the exercise's lesson (`lab lesson <id>`).
2. Read the README **and** look at the current state first (`ansible ... -m command -a ...`).
3. Run with `--check --diff` before applying.
4. `lab check` → read the messages → only then use hints.
5. After passing, always read `lab explain` - most of the transferable knowledge is there.
6. Keep your solutions in `./work` under Git; compare with `lab solution` only afterwards.
