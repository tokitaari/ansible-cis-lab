# 5.01 - Capstone: CIS role with audit and enforce mode: Explanation

### Check mode as the audit engine
Every idempotent module already knows whether the desired state is met - that is what
`changed` means. In check mode it answers the question without acting. So the
remediation code *is* the audit code. The only work is to:
- keep read-only tasks running (`check_mode: false`),
- interpret skipped `command` tasks ("would have run") as findings,
- stop side effects that bypass check mode (handlers, `meta`, background jobs).

### Why a registry
A list of controls with metadata (id, level, title, requirements) gives you:
profiles (`level`), exceptions (`id`), platform applicability (`requires`), selective
runs (`cis_controls_only`), and a report that knows the *titles* of what was checked.
Adding a control = one file + one registry line.

### Dynamic includes and their cost
`include_tasks` in a loop is evaluated per host at run time, so `--list-tasks` and tags
are less useful than with static imports. That is the price for per-control check mode
and recording. Document how to run a subset (`-e '{"cis_controls_only": ["5.1"]}'`).

### The acceptance sequence
audit → enforce → audit is exactly how you would introduce the role in production:
measure, fix in a change window, prove the result. The second enforce run with
`changed=0` proves idempotency - your evidence that the role will not cause drift noise
when it runs daily.

### What production adds
CI (lint + Molecule across platforms), versioned releases, the report pushed to a
dashboard/SIEM, exceptions reviewed regularly, and a rollout strategy - next exercise.

## Reference solution

Show it with `lab solution 5.01`, apply it with `lab solve 5.01`.
