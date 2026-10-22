# 4.02 - Profiles (Level 1/2) and documented exceptions

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★☆ | ~75 min | framework (L1/L2) | `debian` |

**Concepts:** `variable-driven scoping`, `input validation`, `to_datetime / now()`, `contract testing`

## Goal

Build the control mechanism every real hardening role needs: a profile switch (Level 1/2) and a list of exceptions with reason and expiry date that is validated before anything runs.

## Background

No organisation applies 100 % of a benchmark. What separates a mature setup from a
mess is *how* deviations are handled: written down, justified, owned, and expiring.
You will implement that for four controls. The check tests your implementation as a
black box, so it needs a small **contract**:

| Contract item | Value |
|---|---|
| Playbook | `/lab/work/4.02/site.yml` (any structure, a role is recommended) |
| Variables | `cis_level` (1 or 2, default 1), `cis_exceptions` (list of `{id, reason, expires}`, default `[]`) |
| Control ids | `l1-telnet`, `l1-ssh-maxauthtries`, `l2-modules`, `l2-audit-identity` |
| Task names | every task of a control **starts with its id** (case-insensitive; ansible-lint wants capitalised names), e.g. `L1-telnet \| Remove telnet` |
| Validation | invalid input (unknown id, empty reason, missing or past `expires`) fails the run before any control runs |

Control content (keep it small, the mechanism matters): remove telnet · `MaxAuthTries 4`
drop-in (`/etc/ssh/sshd_config.d/01-cis-maxauthtries.conf`) · disable `squashfs` and `udf` ·
audit rule file for identity files.

## Requirements

- [ ] Level-2 controls run only with `cis_level >= 2`.
- [ ] A control whose id is in `cis_exceptions` is skipped - and the run prints which controls were excepted, with reason and expiry.
- [ ] Validation as described in the contract (use `to_datetime('%Y-%m-%d')` and `now()`).
- [ ] `lab check 4.02` runs your playbook five times in `--check` mode against `debian` with different inputs and inspects which tasks ran - it changes nothing.

## How to work

```bash
lab start 4.02            # creates /lab/work/4.02/
cd /lab/work/4.02
# write site.yml, then run it:
ansible-playbook site.yml
lab check 4.02            # verifies the state
```

Stuck? `lab hint 4.02 1` (gentle) ... `lab hint 4.02 3` (almost the answer).  
Passed? Read `lab explain 4.02` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Add `approved_by` as a mandatory field. Where would you store exceptions in a real environment (host_vars? a separate YAML in Git? a CMDB?) - and who may change that file?
- Expiring exceptions should warn 30 days ahead. Implement a warning (not a failure).
