# 4.02 - Profiles (Level 1/2) and documented exceptions: Explanation

### What the check verifies
`lab check 4.02` runs your playbook five times in `--check` mode on `debian` (`-l debian`) with
the JSON callback and reads two things: the exit code of each run and, per task, whether it was
skipped. A control "ran" when not all tasks whose name starts with its id were skipped; the
role prefix (`cis_profile : `) is dropped and the match ignores case. `meta.yml` says
`idempotency: false`, so there is no second run. The check asserts:
- levels 1 and 2 and the run with a valid exception succeed; an expired exception and an
  empty reason each make the run fail;
- level 1: both `l1-*` controls run and no `l2-*` task runs;
- level 2: both `l2-*` controls run;
- with an exception for `l2-modules`: its tasks are skipped, `l2-audit-identity` still runs.

It does not test: the files and packages themselves (check mode changes nothing), the output
that names the excepted controls, an unknown id and a missing `expires` (the check never passes
them), that validation runs *before* the first control, a `cis_level` other than 1 and 2, and
which error stopped a run (any non-zero exit code passes). Mutating the reference solution
confirmed three of these: the check stayed green with the printing task removed, with the
validation moved behind both level 2 controls, and without the assertions for an unknown id and
a missing `expires`. Those parts of the contract are yours to get right. The check and
`lab solve` run on `debian` only, so there is no per-family section here.

### How it works

#### Level as a value, `when` on a block
```yaml
- name: L2-modules | Level 2 kernel modules
  when:
    - cis_level | int >= 2
    - "'l2-modules' not in cis_exception_ids"
  block:
    - name: L2-modules | Disable squashfs and udf
      ansible.builtin.copy: ...
```
`when` on a block is inherited by each task, so a skipped control shows up as skipped tasks in
the output and in the JSON callback, which is exactly what the check reads.

Compare the level with `| int`. A value from `-e cis_level=2` is a string; without `| int`
the run stops with `'>=' not supported between instances of '_AnsibleTaggedStr' and 'int'`. The
check passes its variables as JSON, where `2` is a number, so it cannot warn you.

Keep one block per control with the condition on the block. A looped task whose `when` depends
on `item` and skips only some items is not marked skipped: the `skip_reason` sits inside
`results`, and the check would count the control as run. A task whose condition is false for
every item, or does not use `item`, is skipped as a whole.

#### Validate input before touching anything
Hardening roles receive input from many people (inventory, CI variables, `-e`). A misspelled id
matches no control: the exception the author meant does not exist, the control keeps running
and nobody is told. Fail fast, with a message that names the record. The date turns a forgotten
exception into a failed pipeline instead of a permanent hole. Details of the reference solution:
- `item.id | default('')` and `item.expires is defined` let a record with a missing field fail
  the assertion; an unknown id, a missing `expires` and a blank reason each stop the run with
  the same message (measured).
- `| string | trim | length` for the reason: `length > 0` alone accepts `" "`, and the run
  printed an empty reason and went on (measured).
- The validation is the first task after the level check, so nothing has changed when it fails.

#### Dates and the meaning of `expires`
`expires: 2027-01-31` is a date object for YAML, `"2027-01-31"` a string. `to_datetime` wants
text and fails on the date object with `strptime() argument 1 must be str, not
_AnsibleTaggedDate`, so `| string | to_datetime('%Y-%m-%d')` normalises both (measured with an
unquoted date in a `-e @file`). Another format fails too: `'31.01.2027'` gives `time data
'31.01.2027' does not match format '%Y-%m-%d'`.

The result is midnight at the start of the day, and `now()` is the local time of the control
node. With `> now()`, `expires` is therefore the **first day on which the exception no longer
applies**; the last day it is accepted is the day before. Measured: yesterday and today are
rejected, tomorrow passes. The check tests only 2001 and 2099, so it cannot tell two rules
apart: write yours down for the people who file exceptions.

#### Contract testing
The check never looks at your files. It runs the playbook with
`ANSIBLE_STDOUT_CALLBACK=ansible.posix.json` and evaluates which tasks were skipped. That is how
you test infrastructure code from the outside, and why task names are an interface: renaming
`L2-modules | ...` breaks the test the way it would break any consumer. `--check` makes the
five runs repeatable and harmless.

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `'>=' not supported between instances of '_AnsibleTaggedStr' and 'int'` | `-e cis_level=2` arrives as a string | `\| int` in every comparison; the check passes numbers and does not catch it |
| `strptime() argument 1 must be str, not _AnsibleTaggedDate` | an unquoted date in YAML is a date object | `\| string` before `to_datetime`, or quote the date |
| A valid-looking exception is rejected on its own date | `to_datetime` is midnight, `expires` is the first invalid day | use the day after the last day it should apply |
| An exception with a blank reason is accepted | `length > 0` counts the blank | `\| trim` before `\| length` |
| An `l2-*` task counts as run at level 1 | one looped task serves several controls and its `when` depends on `item` | one block per control, `when` on the block |
| The check is green, but invalid input is rejected only after controls ran | the check reads the exit code, not the order | validation first in the play |

### Real-world notes
- Keep exceptions in Git next to the inventory (`group_vars/<env>/cis_exceptions.yml`),
  changed only through reviewed merge requests, with the ticket number in `reason`. 5.01 applies
  this mechanism to all controls, and its report counts the excepted controls and lists them
  with their reasons, so auditors see the full picture.
- An exception that expires fails the pipeline on that very day. A warning some weeks ahead
  (see the bonus) gives its owner time to renew or fix it.

### Further reading
- Lesson [L11 - Profiles, exceptions and data-driven roles](../../../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.md): the concepts before this exercise, with demos and self-check questions.
- Exercise [5.01 - Capstone: CIS role with audit and enforce mode](../../stage5-capstone/5.01-capstone-cis-role/README.md): the same mechanism for all controls, with a report.

## Reference solution

Show it with `lab solution 4.02`, apply it with `lab solve 4.02`.
