# 5.01 - Capstone: CIS role with audit and enforce mode

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 5 - Capstone | ★★★★★ | ~240 min | Sections 1-7 (L1 + L2 switch) | `targets` |

**Concepts:** `control registry`, `check_mode as audit engine`, `dynamic includes with apply`, `reporting`, `ansible-lint production`

## Goal

Turn your role into a production-grade CIS baseline: one code path that can **audit** (change nothing, report) or **enforce** (remediate, report), with profiles, documented exceptions and a compliance report for all eight platforms.

## Background

Real hardening roles are run in two ways: by auditors/schedulers in read-only mode,
and by change windows in enforce mode. Maintaining two code bases (audit + remediate)
doubles the bugs. The elegant approach: run every control in **check mode** for
audits - a task that *would* change something is a finding.

Architecture of the reference solution (you may choose another):
```
vars/main.yml        cis_controls registry: id, level, title, task file, requires
tasks/main.yml       load platform vars → preflight → loop over registry → report
tasks/control.yml    decide (active / excepted / out-of-profile / not-applicable)
                     → include controls/<file> with apply: check_mode
                     → record pass / fail / fixed
tasks/controls/*.yml one file per control, registers cis_r_<n>
tasks/report.yml     JSON + Markdown on the control node
```

## Requirements

- [ ] Role `/lab/work/roles/cis`, playbook `/lab/work/5.01/site.yml` (Alpine bootstrap play + role).
- [ ] `cis_mode: enforce|audit` (default `enforce`). In `audit` mode a run against freshly reset hosts reports failures and changes **nothing** on the targets (handlers included!).
- [ ] `cis_level` 1|2 and `cis_exceptions` (validated: known id, reason, future `expires`) - the 4.02 mechanism, now for all controls.
- [ ] Controls: everything from 0.04 to 3.05 (3.04 auditd as Level 2).
- [ ] Report `/lab/work/5.01/reports/compliance.json` (per host: mode, level, platform, counts, findings with id/title/status/reason) and `compliance.md`.
- [ ] Statuses: `pass`, `fail` (audit), `fixed` (enforce), `excepted`, `out-of-profile`, `not-applicable`.
- [ ] Acceptance: `./lab.sh reset all` → audit run (only `fail`s, no changes) → enforce run → audit run (no `fail` left). Second enforce run: `changed=0`.
- [ ] `ansible-lint --offline --profile production` passes on the role.

## How to work

```bash
lab start 5.01            # creates /lab/work/5.01/
cd /lab/work/5.01
# write site.yml, then run it:
ansible-playbook site.yml
lab check 5.01            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 5.01 1` (gentle) ... `lab hint 5.01 3` (almost the answer).  
Passed? Read `lab explain 5.01` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Add 4.06 (faillock), 4.07 (nftables) and 4.08 (AIDE) as controls - nftables needs special care in audit mode (the dead-man switch must not run).
- Make the report show the *diff* for failing controls (`--diff` output is in the registered results).
- Publish the role as a collection (`ansible-galaxy collection init lab.cis`) with a `README`, `meta/runtime.yml` and an example playbook.
