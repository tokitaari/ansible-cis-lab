# L11 - Profiles, exceptions and data-driven roles: one role, many audiences

*[Deutsch](L11-profiles-exceptions-and-data-driven-roles.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 4.02, 4.03 | 5.3.3, 5.4.1, 5.4.2, 5.4.3, 6.3 | ~35 min | L04, L07, L10 |

A baseline role is read by three audiences. The operator wants Level 1 on most hosts and Level 2
on a few. The auditor wants to see every deliberate deviation, with a reason and an end date.
And the platform wants to be treated as what it is: a host without a PAM password-quality module
cannot get a PAM policy, and the role has to say so instead of failing or pretending. This
lesson is about the three switches behind that - the profile, the exception and the platform
data - and about testing them from the outside.

## Learning goals

After this lesson you can ...

- [ ] model a profile as one validated value and say what a `when` on a block does to the tasks inside it
- [ ] explain why a value from `-e` can be a string, and what that does to a numeric comparison
- [ ] describe an exception as a record with a reason and an end date, and say where it is kept and reviewed
- [ ] predict how a YAML date, `to_datetime` and `now()` behave, including on the day an exception ends
- [ ] validate input before the first change, and say what `argument_specs` can and cannot check
- [ ] express a platform difference as a capability flag with a fallback, and say who can override it
- [ ] choose between loading one data file and layering several
- [ ] test a role from the outside: read skipped tasks from the JSON callback and prove a refactor with `--check`

## Theory

### A profile is a value

Level 1 and Level 2 (L01) differ in how much the role does. Two copies of a role drift apart,
the same argument L10 made against a separate audit script. Tags (L07) choose tasks on the
command line, so the profile would live in a habit: whoever forgets `--tags` hardens at the
wrong level. The better answer is one value that the role reads. It is an interface, so it
belongs in `defaults/` (L07: if a user may want another value, it is a default); a fleet sets it
in the inventory (L04), a single run with `-e`. The role decides what a level means, the caller
only names it.

Three details decide whether that works.

**The type.** `-e name=value` always arrives as a string. In a test `-e lesson11_level=2` was a
`str` and `-e '{"lesson11_level": 2}'` an `int`; a number written in a YAML file such as
`defaults/main.yml` is an `int`. `when: lesson11_level >= 2` with the string stops the play with
`'>=' not supported between instances of '_AnsibleTaggedStr' and 'int'` (ansible-core 2.21.6).
Convert where you compare, with `| int`, and the command line works either way.

**The block.** A `when` on a block is copied to every task inside it, and each task evaluates it
for itself. Skipped tasks show as `skipping` and are counted as `skipped` in the recap. Because
every task evaluates the condition, a task inside the block that changes a variable of the
condition makes the tasks after it skip (tested with `set_fact`): keep the inputs of a condition
out of its own block.

**The value.** `>= 2` is true for 3 as well, and `l2 | int` is 0 (tested), so a typo silently
selects a stricter or a laxer profile. A level the role does not know has to stop the play
before anything changes. The demo below has two controls of its own, a notice (Level 1) and two strict files
(Level 2); `assert` (L02) guards the level.

```bash
mkdir -p /tmp/lesson11 && cd /tmp/lesson11
```

```yaml
- name: A profile switch
  hosts: targets
  gather_facts: false
  vars:
    lesson11_level: 1
  tasks:
    - name: Make sure the demo directory exists
      ansible.builtin.file:
        path: /tmp/lesson11
        state: directory
        mode: "0755"
      # set-up of the demo, not a control
      check_mode: false

    - name: Refuse levels the role does not know
      ansible.builtin.assert:
        that: lesson11_level | int in [1, 2]
        fail_msg: "lesson11_level must be 1 or 2, got {{ lesson11_level }}"
        quiet: true

    - name: Demo-notice | Level 1 baseline
      ansible.builtin.copy:
        dest: /tmp/lesson11/notice.txt
        content: "authorised use only\n"
        mode: "0644"

    - name: Demo-strict | Level 2 additions
      when: lesson11_level | int >= 2
      block:
        - name: Demo-strict | Strict settings file
          ansible.builtin.copy:
            dest: /tmp/lesson11/strict.conf
            content: "max_retries 3\n"
            mode: "0600"

        - name: Demo-strict | Strict marker file
          ansible.builtin.copy:
            dest: /tmp/lesson11/strict.marker
            content: "strict\n"
            mode: "0644"
```

Save it as `/tmp/lesson11/profile.yml` and run it:

```bash
ansible-playbook profile.yml                          # level 1: the notice
ansible-playbook profile.yml -e lesson11_level=2      # adds the two strict files
ansible-playbook profile.yml -e lesson11_level=2      # second run: changed=0
ansible-playbook profile.yml                          # level 1 again: changed=0
ansible-playbook profile.yml -e lesson11_level=3      # stops at the assert
```

The command-line `2` is a string and still works, because the condition converts it. The fourth
run shows something a profile does not do: it does not go back. Running at Level 1 after
Level 2 is `changed=0` and the strict files stay (tested). A profile only says what to apply, so
lowering it needs removal tasks or a fresh host, and the documentation of the role should say so.

### Exceptions are records, and input is validated before anything runs

No organisation applies a benchmark completely (L01). What separates a managed deviation from a
hole is how it is recorded. A deleted task or a `when: false` has no reason, no owner and no
end. As data an exception has all three: which control, why (a ticket number is a good reason),
until when, and in a real environment who approved it. Keep the list next to the inventory, in
version control, and change it only through review; the diff is the audit trail. It is a list
of records, not of ids, because an id alone cannot be reviewed.

Tasks need something simple to test. A filter chain (L04) turns the records into a list of ids,
and a `when` can then ask whether a control's id is in it. A run should also *say* which
controls were excepted, with reason and end date: an excepted control is neither in order nor a
deviation but a state of its own (L10 mentions it, 5.01 reports it).

#### Dates

An end date is only useful if the play understands it. The demo uses records with their own
field names and prints what Ansible makes of the dates.

```yaml
- name: Exception records and their dates
  hosts: targets
  gather_facts: false
  run_once: true
  vars:
    lesson11_waivers:
      - control: demo-notice
        why: legacy application needs the old notice
        until: 2027-01-31
      - control: demo-strict
        why: the same date, quoted
        until: "2027-01-31"
  tasks:
    - name: Say which controls are excepted
      ansible.builtin.debug:
        msg: "EXCEPTED {{ item.control }} until {{ item.until }}: {{ item.why }}"
      loop: "{{ lesson11_waivers }}"
      loop_control:
        label: "{{ item.control }}"

    - name: Show the type of each date
      ansible.builtin.debug:
        msg: "{{ item.control }}: {{ item.until | type_debug }}"
      loop: "{{ lesson11_waivers }}"
      loop_control:
        label: "{{ item.control }}"

    - name: A date as text becomes a datetime at midnight
      ansible.builtin.debug:
        msg: "{{ lesson11_waivers[0].until | string | to_datetime('%Y-%m-%d') }}"

    - name: Is today, taken as a date, already in the past
      ansible.builtin.debug:
        msg: "{{ (now().strftime('%Y-%m-%d') | to_datetime('%Y-%m-%d')) < now() }}"

    - name: The ids a condition can test
      ansible.builtin.debug:
        msg: "{{ lesson11_waivers | map(attribute='control') | list }}"
```

Save it as `waivers.yml` and run `ansible-playbook waivers.yml`. Four facts come out of it (all
measured on ansible-core 2.21.6):

- The unquoted `2027-01-31` is a **date** object, the quoted one a **string**. `to_datetime` wants
  text: on the date it fails with `strptime() argument 1 must be str, not _AnsibleTaggedDate`.
  Quote dates in the data, or convert to a string before parsing.
- The format is strict. `'31.01.2027'` with `'%Y-%m-%d'` fails with `time data '31.01.2027' does
  not match format '%Y-%m-%d'`: decide one format and write it down.
- The result is **midnight at the start** of the day: `2027-01-31T00:00:00`. Compared with
  `now()`, an end date of *today* is already in the past, and the last demo task prints `True`.
  Decide whether `until` is the first day that is no longer valid or the last that is, and
  compare accordingly.
- `now()` is a naive datetime in the local time of the **control node**; `now(utc=true)` is the
  UTC time, also naive, and both compared fine with the parsed date. The clock and the time zone
  of the target do not matter.

#### Validating before the first change

Exceptions come from many hands: inventory, CI variables, `-e`. Typos fail *open*. A misspelled
control id makes the exception a no-op, so the control runs although the team believed it was
waived - on a production host that can be an outage. An empty reason is an undocumented
exception, a missing end date an eternal one, and a level of `3` behaves like `2`. The rule is
to fail fast, before the first task that changes something, with a message that names the
offending record. Two tools do it.

`assert` in a preflight task runs in `--check` too (tested: level 3 stopped a `--check` run at
the assert). Put one condition per rule in `that:`, so a failure points at one rule, and loop
over the records with a `loop_control.label` so the message names the record.

`meta/argument_specs.yml` declares the interface of a role: types, allowed values, required
keys, and for a list of mappings the options of each element. Ansible validates the input
before the first task of the role, also under `--check`; the check appears as its own task,
tagged `always`, at the top of `--list-tasks`. The demo role `demo_gate` has two inputs:

```bash
mkdir -p /tmp/lesson11/roles/demo_gate/{meta,defaults,tasks} && cd /tmp/lesson11
cat > roles/demo_gate/defaults/main.yml <<'EOF'
---
demo_gate_level: 1
demo_gate_waivers: []
EOF
cat > roles/demo_gate/tasks/main.yml <<'EOF'
---
- name: Report what the role received
  ansible.builtin.debug:
    msg: "level {{ demo_gate_level }} ({{ demo_gate_level | type_debug }}), {{ demo_gate_waivers | length }} waivers"
EOF
cat > gate.yml <<'EOF'
- name: Use the demo role
  hosts: debian
  gather_facts: false
  roles:
    - role: demo_gate
EOF
```

```yaml
---
argument_specs:
  main:
    short_description: The two inputs of the demo role
    options:
      demo_gate_level:
        type: int
        choices: [1, 2]
        description: Profile level.
      demo_gate_waivers:
        type: list
        elements: dict
        description: Recorded deviations.
        options:
          control:
            type: str
            required: true
            choices: [demo-notice, demo-strict]
          why:
            type: str
            required: true
          until:
            type: str
            required: true
```

Save the spec as `roles/demo_gate/meta/argument_specs.yml` and try five inputs:

```bash
ansible-playbook gate.yml                                  # defaults
ansible-playbook gate.yml -e demo_gate_level=2             # passes - the role still sees a string
ansible-playbook gate.yml -e demo_gate_level=3             # stopped before the role's first task
ansible-playbook gate.yml -e '{"demo_gate_waivers": [{"control": "demo-notic", "why": "x", "until": "2027-01-01"}]}'
ansible-playbook gate.yml -e '{"demo_gate_waivers": [{"control": "demo-notice", "why": "", "until": "soon"}]}'
```

The third and the fourth stop with `argument_errors` that name the problem: `value of
demo_gate_level must be one of: 1, 2, got: 3` and `value of control must be one of: demo-notice,
demo-strict, got: demo-notic found in demo_gate_waivers`. A record without `why` is reported as a
missing required argument, and an option that is not in the spec is rejected with the list of the
supported ones. The fifth passes: an **empty** `why` and the date `soon` satisfy `type: str` and
`required: true`. A spec checks shape, not meaning - it cannot demand non-empty text, a date
format or a date in the future, and it cannot relate two fields. It also **validates but does not
convert**: the second run printed `str` for the level, and a YAML date in `-e @file` passes
`type: str` and stays a date. The conversions of the two previous parts stay in the tasks. So
the two tools complement each other: the spec for shape and allowed ids, `assert` for the rules
about content.

### Platform data and capability flags

L04 moved platform differences into data. The next question is what kind of data. "This control
does not apply on Alpine" can be written as a condition on the system (`when: os_family != ...`)
or as a value, loaded from a data file, that names a capability: `demo_acl_supported: false`.
The condition says what, not why. It repeats at every task that touches the feature, and a new
platform means opening every task file to edit logic. A capability flag says what the platform
can do; tasks ask the capability question; the platform file answers it once, with a comment
for the compensating control or the documented gap. Where the capability can be probed on the
host - a command that exists or not - probing beats a table of version numbers.

Which file is read is decided by `first_found` (L07): the first existing name from a list that
runs from the most specific to a generic file. Three properties matter, and a demo that is keyed
by a variable instead of a fact shows all of them. Create the data first:

```bash
mkdir -p /tmp/lesson11/vars && cd /tmp/lesson11
cat > vars/default.yml <<'EOF'
# conservative: an unknown flavour gets nothing it cannot be sure of
demo_acl_supported: false
demo_xattr_supported: false
EOF
cat > vars/blue.yml <<'EOF'
demo_acl_supported: true
EOF
cat > vars/blue-2.yml <<'EOF'
demo_xattr_supported: true
EOF
```

```yaml
- name: Platform data - one file or layers
  hosts: debian
  gather_facts: false
  vars:
    lesson11_flavour: blue
    lesson11_release: "2"
    demo_acl_supported: set by the play
  tasks:
    - name: Load the most specific data file only
      ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', lesson11_candidates) }}"
      vars:
        lesson11_candidates:
          files:
            - "{{ lesson11_flavour }}-{{ lesson11_release }}.yml"
            - "{{ lesson11_flavour }}.yml"
            - default.yml
          paths:
            - vars

    - name: Show the flags
      ansible.builtin.debug:
        msg: "acl={{ demo_acl_supported }} xattr={{ demo_xattr_supported | default('not set') }}"
```

```yaml
- name: Platform data - layers instead of one file
  hosts: debian
  gather_facts: false
  tasks:
    - name: Load the general file first, the specific one second
      ansible.builtin.include_vars: "{{ item }}"
      loop:
        - vars/blue.yml
        - vars/blue-2.yml

    - name: Show the flags
      ansible.builtin.debug:
        msg: "acl={{ demo_acl_supported }} xattr={{ demo_xattr_supported }}"
```

Save them as `data.yml` and `layers.yml` and run:

```bash
ansible-playbook data.yml                                # blue-2.yml only
ansible-playbook data.yml -e lesson11_release=1          # no blue-1.yml: blue.yml
ansible-playbook data.yml -e lesson11_flavour=zeta       # nothing matches: default.yml
ansible-playbook data.yml -e demo_acl_supported=forced   # the command line
ansible-playbook layers.yml                              # both files, in order
```

The messages are `acl=set by the play xattr=True`, `acl=True xattr=not set`, `acl=False
xattr=False`, `acl=forced xattr=True` and `acl=True xattr=True`. Read them as follows.

- **One file.** `first_found` returns one file. `blue-2.yml` does not define `demo_acl_supported`,
  so the flag comes from wherever else it is defined - here the play. With one-file lookup every
  file has to be complete, or the gap belongs to someone else. To layer, load several files in
  order, general first; the later file wins for the names it defines. A missing file in such a
  list is an error (`Could not find or access`), unlike the fallback of `first_found`.
- **A fallback.** With no `default.yml` an unknown flavour ends in `No file was found when using
  first_found` (L07). With one, the question is what it contains. A hardening role should fall
  back to values that enable nothing it cannot be sure of, and the report (L10) must show the
  skipped controls as not applicable. A silent skip is a hole, and a default that enables
  everything breaks the first host of a platform nobody tested.
- **Precedence.** A value loaded with `include_vars` beat the play variable (and, in the test,
  `group_vars`); only `-e` beat it. That is right for flags that are facts of the platform and
  wrong for anything a user should be able to set per host - those belong in `defaults/` (L07).

### Testing a role from the outside

Reading the code of a role tells what its author meant. Whether level 1 really skips the Level 2
tasks, and whether an excepted control is really skipped, is shown by running it. A run in
`--check` (L02) changes nothing, so it can be repeated with different inputs, and the JSON
callback turns the result into data: one document with, per task and host, `skipped`, a
`skip_reason` and the `false_condition` (measured). This reader prints the state of each task:

```python
import json, sys

text = sys.stdin.read()
data = json.loads(text[text.index("{"):])
for play in data["plays"]:
    for task in play["tasks"]:
        for host, result in task["hosts"].items():
            state = "skipped" if result.get("skipped") else "ran"
            print(f'{host}: {state:8} {task["task"]["name"]}')
```

Save it as `ran.py` and feed it the demo of the first concept, once per level:

```bash
ANSIBLE_STDOUT_CALLBACK=ansible.posix.json ansible-playbook profile.yml -l debian --check -e '{"lesson11_level": 1}' | python3 ran.py
ANSIBLE_STDOUT_CALLBACK=ansible.posix.json ansible-playbook profile.yml -l debian --check -e '{"lesson11_level": 2}' | python3 ran.py
```

```text
debian: ran      Make sure the demo directory exists
debian: ran      Refuse levels the role does not know
debian: ran      Demo-notice | Level 1 baseline
debian: skipped  Demo-strict | Strict settings file
debian: skipped  Demo-strict | Strict marker file
```

That is the output for level 1; at level 2 every line says `ran`. Three consequences follow.
Task **names are an interface**: the test finds a control by its name, so a convention that puts
the control's id at the start of every task name makes the selection mechanical, and renaming a
task is a breaking change. A task with a **loop** is one entry: when a rewrite of the demo
wrote its files in one looped task, the skipped items appeared only inside the task's `results`
(each with a `skip_reason`), and the task itself was not marked skipped - one task per control
keeps the result readable. And `--list-tasks` is no substitute: it lists every task including
the strict ones at level 1, because it does not evaluate `when` (tested). It shows structure, not
behaviour.

The same idea proves a refactor. Say you restructure a role and want the same behaviour. Enforce
with the old version, then run the new one with `--check --diff`: `changed=0` means that the
hosts already have what the new code asks for. In a test, a loop-based rewrite of the demo gave
`changed=0`, and a rewrite that changed one file mode gave `changed=1` with the two modes in the
diff. The proof covers only what the new code manages. If it dropped a control, nothing notices;
run it the other way as well, the old version in `--check` after the new one enforced, and the
dropped control shows up as a change (tested). A second run that is `changed=0` (L00) and the earlier
exercises' checks, which 4.03 runs as regression tests, are the same safety net.

## CIS background

Levels (L01) are the reason for the profile: Level 1 is the baseline that should not break a
service, Level 2 buys protection at a cost, such as more auditing than anyone reads (L09). In
[the control catalogue](../../cis/controls.yml) 6.3, the auditd section, is the Level 2 content
tied to both exercises; 5.3.3 (password quality), 5.4.1 (password ageing) and 5.4.2 and 5.4.3
(accounts, shell environment) are the Level 1 controls that 4.03 brings together on every
platform. How the level is chosen is not part of the benchmark; the role decides.

A recommendation can be unsuitable for a service, and a documented exception is how an
organisation shows that it decided deliberately - what an auditor asks to see. Three properties
make it defensible: a reason, a person who accepted the risk, and an end. The end has a cost: an
exception that expires can stop a pipeline on the day, which is the point, and a reason to warn
before it happens (the bonus of 4.02). In a report (L10) an excepted control is neither counted
as compliant nor a failure; it is listed with its reason and its date.

Platform gaps are exceptions decided by the platform, not by a person. 5.3.3 needs a
password-quality module, and the Alpine target has none (L08). The role records the gap in the
platform data with the compensating measure, and the report shows it as not applicable instead
of passing it silently.

## Platform differences

The platform data of a role is keyed by facts, and the facts differ in exactly the places where a
version-specific file name would be useful or useless. Measured on the lab's targets (the values
change when an image is rebuilt):

| os_family | Hosts | `distribution` | `distribution_major_version` | Most specific file name |
|---|---|---|---|---|
| Debian | debian, ubuntu | Debian, Ubuntu | 13, 26 | `Debian-13.yml`, `Ubuntu-26.yml` |
| RedHat | rocky, alma, fedora | Rocky, AlmaLinux, Fedora | 10, 10, 44 | `Rocky-10.yml`, `AlmaLinux-10.yml`, `Fedora-44.yml` |
| Suse | opensuse | `openSUSE Leap` (with a space) | 16 | `openSUSE Leap-16.yml` |
| Alpine | alpine | Alpine | 3 (the version is 3.24.3) | `Alpine-3.yml`, which matches every 3.x |
| Archlinux | arch | Archlinux | 20261101 (a date) | none that lasts |

Ubuntu is in the Debian family, so a family file serves both. The major version is a string (tested
with the fact on the session host): compare it with `| int`, as in the first concept. The name
with a space works in `first_found` (tested with a file of that name) but is awkward in a
repository; the family file `Suse.yml` covers it. Arch is rolling, so its "major version" is the
date of the image, and a version-specific file for it would never match again: use the
distribution or the family file there.

### In the lab containers

- The facts come from each image's own release files, so a rebuilt image can show other versions
  than the table. The playbooks, the demo role, the data files and `ran.py` stay on the control
  node, where you run `ansible-playbook`; `profile.yml` writes below `/tmp/lesson11` on the
  targets and needs 0.02 (Python on Alpine), the other plays use `debian` or only `debug`.
- Remove the demo files with `ansible targets -m ansible.builtin.file -a 'path=/tmp/lesson11
  state=absent'` and, on the control node, `rm -rf /tmp/lesson11`.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `'>=' not supported between instances of '..Str' and 'int'` | the value came from `-e name=value` and is a string | compare with `\| int`, or pass JSON |
| Level 3 acts as Level 2, `l2` as Level 1 | `>= 2` is true for 3, and `'l2' \| int` is 0 | `assert` the level before anything changes |
| After a run at a lower level the stricter files are still there | a profile selects what to apply, it does not undo | removal tasks, or a fresh host |
| The tasks after the first one in a block skip unexpectedly | the block's `when` is evaluated per task, and a task inside changed its input | keep the inputs of the condition out of the block |
| `strptime() argument 1 must be str, not ..Date` | an unquoted `2027-01-31` is a YAML date object | quote dates in the data, or convert to a string before `to_datetime` |
| `time data '..' does not match format` | the date is written in another format | one documented format, and a readable message when it is not met |
| An exception ends one day early | `to_datetime` gives midnight, so *today* is already past `now()` | decide what `until` means and compare accordingly |
| An exception does nothing | the id is misspelled and never matches | check ids against the list of known controls (`choices`, or `assert`) |
| The spec passes, but the task fails on a string or a date | `argument_specs` validates, it does not convert | convert in the task |
| A flag from the platform file cannot be changed in `group_vars` | `include_vars` beats play and inventory variables; only `-e` wins | overridable values belong in `defaults/` |
| `Archlinux-20261101.yml` never matches again | the major version of a rolling system is a date | use the distribution or the family file |
| The test says a looped task `ran` although items were skipped | the JSON callback has one entry per task, skipped items sit in `results` | one task per control, or read `results` |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [4.02](../../exercises/stage4-advanced/4.02-profiles-and-exceptions/README.md) | a profile as a validated value, `when` on blocks, exceptions as records with a reason and an end date, `to_datetime` and `now()`, validation before the first change, reading skipped tasks from the JSON callback |
| [4.03](../../exercises/stage4-advanced/4.03-data-driven-multi-platform-role/README.md) | capability flags instead of system conditions, one data file or layers, a conservative fallback, the precedence of loaded data, regression and refactor proof with `--check` |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. `-e level=2` is given and a task has `when: level >= 2`. It fails, although `-e '{"level": 2}'`
   works. Why, and what is the fix?

   <details><summary>Answer</summary>

   A value from `key=value` on the command line is a string, and Jinja does not compare a string
   with an integer; JSON gives a real integer. Compare with `level | int >= 2`, which works for
   both, and validate the value so that `l2` or `3` stops the play.

   </details>

2. A host was hardened at Level 2. You run the role again at Level 1. What happens to the
   Level 2 settings, and what does that mean for going back?

   <details><summary>Answer</summary>

   Nothing: the Level 1 run is `changed=0` and the strict files stay, because a profile only
   selects what to apply. Going back needs explicit removal tasks (or a fresh host), and the
   role's documentation should say that a lower level does not undo a higher one.

   </details>

3. A block has `when: flag | default(true)`, and its first task sets `flag: false` with
   `set_fact`. What do the remaining tasks of the block do?

   <details><summary>Answer</summary>

   They are skipped. The `when` of a block is copied to every task and evaluated for each of
   them, so the changed variable is seen by the tasks after the first one. Keep the inputs of a
   condition out of the block they guard.

   </details>

4. An exception has `until: 2026-11-06` as an unquoted date and is checked at 14:00 on that day
   with `to_datetime` and `now()`. Name two problems.

   <details><summary>Answer</summary>

   An unquoted date is a YAML date object, and `to_datetime` fails on it unless it is converted
   to a string first. If it is converted, the result is midnight at the start of the day, so the
   exception already counts as expired at 14:00. Decide whether `until` is the last valid or the
   first invalid day, and compare accordingly.

   </details>

5. Which of these can `argument_specs` catch: a level of 3, a misspelled control id, an empty
   `why`, a date in the past, a date written as `31.01.2027`? What covers the rest?

   <details><summary>Answer</summary>

   The level (with `choices`) and the misspelled id (with `choices` on the element's option); it
   also catches missing keys and unknown option names. It does not catch an empty text, a date in
   the past or a wrong date format, because it checks shape, not content, and it converts
   nothing. Those rules belong to `assert` tasks in a preflight, before the first change.

   </details>

6. A flag defined in a platform file loaded with `include_vars` cannot be changed in
   `group_vars`. Why, and what do you do if users must be able to?

   <details><summary>Answer</summary>

   Variables loaded with `include_vars` have a higher precedence than play and inventory
   variables; only `-e` is stronger. A value that users may want to set per host is an interface
   and belongs in `defaults/` of the role. The platform file is for facts of the platform.

   </details>

7. A platform no data file knows reaches `default.yml`. What should it contain, and what must the
   report show?

   <details><summary>Answer</summary>

   Conservative values: nothing is enabled that cannot be sure to work there, so the first host of
   an untested platform is not broken. The controls it therefore skips must appear in the report
   as not applicable (L10), with the reason; a silent skip would look like compliance.

   </details>

8. You rewrote a role. How do you show that behaviour did not change, what can that not see, and
   why is `--list-tasks` not the tool for it?

   <details><summary>Answer</summary>

   Enforce with the old version, then run the new one with `--check --diff`: `changed=0` means
   the hosts already match the new code. It does not see a control the new code dropped, so run
   the old version in `--check` afterwards as well. `--list-tasks` does not evaluate `when`, so it
   lists every task and shows structure, not what actually runs.

   </details>

## Further reading

- [Role argument validation](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html) - `meta/argument_specs.yml`, types, `choices` and nested `options`
- [Conditionals](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_conditionals.html) and [Blocks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_blocks.html) - `when` and what a block hands to its tasks
- [Using variables](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html) - the full order of precedence
- [`ansible.builtin.include_vars`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/include_vars_module.html) - loading data files at run time
- [`ansible.builtin.first_found`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/first_found_lookup.html) - the lookup behind the fallback chain
- [`ansible.builtin.assert`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/assert_module.html) - `that`, `fail_msg` and `quiet`
- [Using filters to manipulate data](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_filters.html) - `to_datetime`, `map` and `type_debug`
- [`ansible.posix.json` callback](https://docs.ansible.com/projects/ansible/latest/collections/ansible/posix/json_callback.html) - the callback behind the contract test
- [Glossary](../GLOSSARY.md) - terms of this lesson: `assert`, capability flag, exception,
  `first_found`, `include_vars`, Level 1 / Level 2, platform data, profile (CIS)
