# 5.02 - Rollout strategy: preflight, canary, batches

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 5 - Capstone | ★★★★★ | ~90 min | (operations) (-) | `targets` |

**Concepts:** `any_errors_fatal`, `serial`, `max_fail_percentage`, `explicit confirmation`, `post-checks`

## Goal

Wrap your capstone role in a rollout playbook that would be safe on 2,000 servers: global preflight, a canary group, growing batches that stop on the first failure, and verification after each batch.

## Background

A correct role can still cause an outage when it hits every host at once (think: a
firewall rule that is wrong only on one OS version). Rollout strategy limits the
blast radius:

| Phase | Ansible feature |
|---|---|
| preflight on *all* hosts, abort everything on any failure | `any_errors_fatal: true` |
| explicit operator confirmation | required extra var, `assert` |
| canary first | separate play on a small group |
| growing batches | `serial: [1, "30%", "100%"]` |
| stop at the first failure | `max_fail_percentage: 0` |
| prove health after each batch | post-tasks in the same play (`wait_for_connection`, checks) |

## Requirements

- [ ] Playbook `/lab/work/5.02/rollout.yml`.
- [ ] Play 1 (all targets, `any_errors_fatal: true`): reachable, Python present, `sshd -t` OK, `visudo -c` OK, at least 200 MB free on `/`, and `cis_rollout_confirm` is `true` (passed with `-e`).
- [ ] Play 2: canary hosts `debian` and `rocky` (configurable `cis_canary`) get the role in enforce mode, then a post-check.
- [ ] Play 3: all remaining targets, `serial: [1, "30%", "100%"]`, `max_fail_percentage: 0`, role + post-check per batch.
- [ ] Post-check: a **new** SSH connection works (`meta: reset_connection` + `wait_for_connection`) and `sshd -T` still says `permitrootlogin no`.
- [ ] Without `-e cis_rollout_confirm=true` the playbook must fail in play 1 - also with `--check`.

## How to work

```bash
lab start 5.02            # creates /lab/work/5.02/
cd /lab/work/5.02
# write rollout.yml, then run it:
ansible-playbook rollout.yml
lab check 5.02            # verifies the state
```

Stuck? `lab hint 5.02 1` (gentle) ... `lab hint 5.02 3` (almost the answer).  
Passed? Read `lab explain 5.02` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Add a maintenance-window guard: abort if the current hour (`now().hour`) is outside a configured window.
- Notify a chat channel per batch (`community.general.slack`/`mattermost`/`teams`?). Which data belongs into the message?
- How would this look in AWX/AAP (workflow template with approval node)?
