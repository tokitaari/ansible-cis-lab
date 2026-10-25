# 4.01 - Audit-only compliance report: Explanation

### Shape of the solution
1. **Collect** - `package_facts`, `service_facts`, `stat`, `slurp`, `command` (sshd -T,
   sysctl). All read-only; `command` gets `changed_when: false` and `check_mode: false`.
2. **Evaluate** - one `set_fact` builds `cis_results`, a list of dicts. Each status is a
   Jinja expression. Nothing can fail here.
3. **Aggregate** - a play on `localhost` reads `hostvars[h].cis_results` for every target,
   computes scores and writes JSON + Markdown.

### Why not `assert` + `ignore_errors`?
`assert` stops the host at the first failure (or, with `ignore_errors`, shows red
noise and still gives you no structured data). Expressions give you *data*.

### `check_mode: false` on readers
Under `--check` a `command` task is skipped (it cannot predict its effect). A pure
reader is safe to run, so you override it. This makes your audit play itself usable
inside `--check` pipelines.

### n/a vs pass
A control that does not apply (busybox `cron.allow`) is neither pass nor fail.
Counting n/a as pass inflates scores; counting it as fail punishes platforms. Keep it
separate and exclude it from the score.

### The timestamp question (bonus)
A timestamp makes the *report file* change every run. That is fine - the report lives
on the control node and is an output, not managed state. The idempotency rule is about
the systems you manage.

### Next step
The capstone (5.01) folds this idea into the role itself: every control runs in
*audit* mode via check mode and is recorded automatically.

## Reference solution

Show it with `lab solution 4.01`, apply it with `lab solve 4.01`.
