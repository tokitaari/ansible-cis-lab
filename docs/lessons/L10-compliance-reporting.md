# L10 - Compliance reporting: audit mode, enforce mode and custom facts

*[Deutsch](L10-compliance-reporting.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 4.01, 4.05, 5.01 | 1.1.1, 1.5, 1.6, 2.1, 2.2, 2.4, 3.3, 5.1, 5.2, 5.3.3, 5.4.1, 5.4.2, 5.4.3, 6.3, 7.1 | ~30 min | L02, L04, L07, L09 |

A hardening role that can only change hosts is half a tool. Before the change window someone
asks what would change, afterwards what is now in order, and for a hundred hosts the answer has
to be a file that a person who never saw the playbook can read. This lesson is about that
second job: running the same code to look instead of to change, turning what it finds into data,
putting the data into a report, and letting a host describe itself with custom facts.

## Learning goals

After this lesson you can ...

- [ ] explain why remediation code can serve as audit code, and which results mean "unknown"
- [ ] switch a block between audit and enforce with a variable without losing `--check`
- [ ] name the side effects that ignore check mode: handlers, background tasks, fact scripts
- [ ] model a control result as ok, deviation or not applicable, and say what a score divides by
- [ ] aggregate per-host results on the control node and report the hosts that have none
- [ ] write a report that is identical on the second run, and say what a timestamp costs
- [ ] choose between a static and an executable fact and say when, and with whose rights, each runs
- [ ] predict what `ansible_local` holds before and after a re-gather, also under `--check`

## Theory

### One code path for audit and enforce

A hardening role runs in two situations. In a change window it must change hosts. Before that,
and on a schedule afterwards, someone only asks "what is not in order?" - an auditor, a
scheduler, a change manager who wants the blast radius. The obvious answer is two code bases:
a role that remediates and a script that checks. They drift apart. The script tests what its
author believes the role does, every rule is written twice, and a bug in one never shows in
the other.

The alternative uses something every idempotent module already has. To report `changed`, a
module compares the current state with the requested one; in check mode (L02) it stops after
the comparison. A task that *would* change something is therefore a deviation, and the
remediation code is the audit code. Reading the results takes one rule per kind of task:

| Task in check mode | What the result says | Read it as |
|---|---|---|
| `copy`, `file`, `template`, `lineinfile`, `package`, `service` | `changed` is true or false | decided: deviation or in order |
| `command`, `shell`, `raw` without `creates`/`removes` | skipped, `changed: false` | **unknown** - nothing was checked |
| `command` with `creates` or `removes` | `changed` true (with a message that it would have run) or false | decided |
| `stat`, `slurp`, `package_facts`, a `command` with `check_mode: false` | the real result | data to evaluate |

The second row is the trap. If an audit only counts `changed`, a host whose single control is a
skipped `command` looks perfect. Audit-capable code uses modules that can decide, or reads with
`check_mode: false` (L02) and compares the value itself.

The play below has two controls, a settings file with content and mode and a notice file, and
one variable. The block's `check_mode:` is a template. Run it three times: audit (the default),
enforce, audit again.

```yaml
- name: One code path for audit and enforce
  hosts: targets
  gather_facts: false
  vars:
    lesson10_mode: audit
  handlers:
    - name: Mark that the demo service was reloaded
      ansible.builtin.copy:
        dest: /tmp/lesson10/reloaded
        content: "reloaded\n"
        mode: "0644"
      # a handler has no check mode of its own: guard it with the mode
      when: lesson10_mode == 'enforce'
  tasks:
    - name: Make sure the demo directory exists
      ansible.builtin.file:
        path: /tmp/lesson10
        state: directory
        mode: "0755"
      # set-up of the demo, not a control
      check_mode: false

    - name: Controls of the demo baseline
      # dry run when auditing, and whenever --check is given
      check_mode: "{{ ansible_check_mode or lesson10_mode == 'audit' }}"
      block:
        - name: Demo settings file has the wanted content and mode
          ansible.builtin.copy:
            dest: /tmp/lesson10/demo.conf
            content: "max_retries 3\n"
            mode: "0600"
          register: lesson10_conf
          notify: Mark that the demo service was reloaded

        - name: Demo notice file has the wanted content and mode
          ansible.builtin.copy:
            dest: /tmp/lesson10/notice.txt
            content: "authorised use only\n"
            mode: "0644"
          register: lesson10_notice

    - name: Say what was found
      ansible.builtin.debug:
        msg: >-
          {{ lesson10_mode }}: {{ [lesson10_conf, lesson10_notice] | selectattr('changed') | list | length }}
          of 2 controls not met
```

```bash
ansible-playbook baseline.yml                              # audit: 2 of 2 controls not met
ansible-playbook baseline.yml -e lesson10_mode=enforce     # remediate
ansible-playbook baseline.yml                              # audit: 0 of 2 controls not met
```

The first audit leaves nothing but the demo directory on the host: no `demo.conf`, no
`notice.txt`, no `reloaded`. Its recap counts the two controls that are not met as `changed`
(plus the directory, on the very first run). After the enforce run the audit finds nothing, and a second enforce run is `changed=0`. That
sequence - measure, change, prove - is how a baseline is introduced in production.

Why `ansible_check_mode or ...`? With the simpler keyword `"{{ lesson10_mode == 'audit' }}"` the
block is a dry run when auditing - and `false` when enforcing. `false` is not "no opinion": it
overrides `--check`. In a test, `-e lesson10_mode=enforce --check` with that keyword wrote both
files for real. The `or` keeps the command-line dry run authoritative.

**What check mode does not stop.** Four things in an audited block act anyway or answer
wrongly:

- **Handlers.** A handler has no keyword of its own. Notified from a block with `check_mode:`,
  it ran for real in a test and wrote its file although the notifying task was only checked.
  Guard it with the mode variable, as above (L02: with a global `--check` handlers are checked
  too; a keyword on tasks does not reach them).
- **Background tasks.** `async` with `poll: 0` (L09) reports `changed` and `started` in check
  mode, and the job still created nothing in a test. It would count as a deviation on every
  audit; decide in a foreground task instead.
- **The flag.** `ansible_check_mode` is the *command-line* flag. Inside the audited block it
  stayed `False` in a test, so `when: not ansible_check_mode` does not protect a task there.
  Test the mode variable.
- **Dynamic includes.** A role usually runs its controls through includes (L07). `include_tasks`
  is evaluated at run time and does not accept the keyword at all: `'check_mode' is not a valid
  attribute for a TaskInclude`. What does reach the included tasks (all tested): a static
  `import_tasks`, an enclosing block, and `apply:` on the include, which hands keywords to the
  tasks it includes (L07 used it for tags). Which one fits a loop over many controls, and what
  the include must record afterwards, is a design decision of 5.01.

### Findings are data, not failures

A failed task is the wrong way to report a deviation. `assert` stops a host at its first miss
(tested), so a host with five deviations shows one, and the recap says "failed" for what is a
finding - which makes real failures (unreachable host, broken module) harder to see.
`ignore_errors` keeps the run going but hides which errors were expected. Evaluate instead: read
state with read-only tasks, compute the outcome as a value, collect the values in a list.

A control has three outcomes:

| Status | Meaning | In the score |
|---|---|---|
| `ok` | applies, met | counted as met |
| `deviation` | applies, not met | counted as not met |
| `not_applicable` | the control does not exist on this platform | not counted |

Tools use words such as pass, fail and not applicable; the demo uses its own. Keeping
`not_applicable` apart matters because the alternatives distort: counted as ok it inflates the
score, counted as a deviation it punishes the platform. A score is `ok` divided by the controls
that apply. A real list needs a fourth value for a control that could not be evaluated (an input
was unreadable) - never `ok`; the demo has none.

```yaml
- name: Evaluate the demo controls without ever failing
  hosts: targets
  gather_facts: true
  tasks:
    - name: Stat the demo settings file
      ansible.builtin.stat:
        path: /tmp/lesson10/demo.conf
      register: lesson10_st

    - name: Stat the systemd unit directory
      ansible.builtin.stat:
        path: /etc/systemd/system
      register: lesson10_units

    - name: Read the demo settings file
      ansible.builtin.slurp:
        src: /tmp/lesson10/demo.conf
      register: lesson10_body
      # a missing file is an answer, not an error
      failed_when: false

    - name: Evaluate the controls
      vars:
        lesson10_text: "{{ lesson10_body.content | default('') | b64decode }}"
      ansible.builtin.set_fact:
        lesson10_results:
          - id: demo-mode
            title: Settings file is mode 0600
            status: "{{ 'ok' if lesson10_st.stat.exists and lesson10_st.stat.mode == '0600' else 'deviation' }}"
          - id: demo-retries
            title: Settings file allows at most 3 retries
            status: "{{ 'ok' if lesson10_text is search('(?m)^max_retries\\s+[0-3]$') else 'deviation' }}"
          - id: demo-units
            title: Unit directory exists (systemd hosts only)
            status: >-
              {{ 'not_applicable' if ansible_facts.service_mgr != 'systemd'
                 else 'ok' if lesson10_units.stat.isdir | default(false)
                 else 'deviation' }}

    - name: Show the results
      ansible.builtin.debug:
        var: lesson10_results
```

Run it after the enforce run above: two `ok` and one `not_applicable` on the Alpine target
(OpenRC, the `service_mgr` fact is `openrc` there), three `ok` on the others. Delete
`/tmp/lesson10/demo.conf` and run it again: the `slurp` fails silently (in a test its `content`
was then missing, hence the `default`), and both file controls turn to `deviation`. Nothing
aborted. Applicability comes from a fact, not from host names (L04).

### From per-host results to one report

The results live in variables of each host. A play on `localhost` reads them through `hostvars`
(L00), looping over `groups['targets']`. Variables set in an earlier play are still there in a
later play of the same run (tested). A host that failed, was unreachable or was left out by `-l`
has no such variable, and an unguarded read stops the report play with `object of type
'HostVarsVars' has no attribute '...'` (the wording is from ansible-core 2.21). Guard the read -
and do not just skip such hosts: a report that silently omits a host reads as "all fine". List
them as *no data*.

```yaml
- name: Write the report on the control node
  hosts: localhost
  gather_facts: false
  vars:
    lesson10_done: >-
      {{ groups['targets'] | map('extract', hostvars) | selectattr('lesson10_results', 'defined')
         | map(attribute='inventory_hostname') | sort }}
    lesson10_missing: "{{ groups['targets'] | difference(lesson10_done) | sort }}"
    lesson10_report:
      hosts: "{{ dict(lesson10_done | zip(lesson10_done | map('extract', hostvars, 'lesson10_results'))) }}"
      no_data: "{{ lesson10_missing }}"
  tasks:
    - name: Make sure the report directory exists
      ansible.builtin.file:
        path: /tmp/lesson10/reports
        state: directory
        mode: "0755"

    - name: Write the JSON report
      ansible.builtin.copy:
        dest: /tmp/lesson10/reports/demo.json
        content: "{{ lesson10_report | to_nice_json }}\n"
        mode: "0644"

    - name: Write the Markdown report
      ansible.builtin.copy:
        dest: /tmp/lesson10/reports/demo.md
        content: |
          | Host | ok | deviation | not applicable |
          |---|---|---|---|
          {% for h, res in lesson10_report.hosts.items() %}
          {% set ok = res | selectattr('status', 'equalto', 'ok') | list | length %}
          {% set bad = res | selectattr('status', 'equalto', 'deviation') | list | length %}
          {% set na = res | selectattr('status', 'equalto', 'not_applicable') | list | length %}
          | {{ h }} | {{ ok }} | {{ bad }} | {{ na }} |
          {% endfor %}
          {% for h in lesson10_report.no_data %}
          | {{ h }} | no data | no data | no data |
          {% endfor %}
        mode: "0644"
```

Append this play to the file of the previous example to see real numbers. On its own it still
runs, and then reports every host as *no data* - the case it exists to handle. The report goes
to `/tmp/lesson10/reports` of the control node as JSON for machines and a Markdown table for
people, from the same data.

Two properties make a report usable over time. It must be **deterministic**: `to_nice_json`
sorts keys (tested), hosts are sorted, and a second run writes the same bytes, so the run is
`changed=0`. A timestamp in the content breaks that; in a test the one file that changed on the
second run was the one with a timestamp. Every run then looks like a change, drift disappears
in the noise, and version control fills with diffs. If the time matters, put it in the file
name or in the log of the runner. And it is an **output**, not managed state. A play on
`localhost` has its own recap line, so the targets stay at `changed=0`; a task with
`delegate_to: localhost` and `run_once` is counted on the first target host instead (tested:
`changed: [t1 -> localhost]`). Under `--check` a `copy` writes nothing; a report that must
appear in a dry run needs `check_mode: false` on its tasks (tested: only the task with the
keyword wrote its file).

### Custom facts: hosts that describe themselves

The report above is computed from outside, at audit time. Sometimes the host should carry its
own description, readable by any later play without re-running the controls: which baseline was
applied, and what is true right now. Fact gathering supports this. Files named `*.fact` in a
directory on the host (`/etc/ansible/facts.d` by default, absent on all eight targets) show up
as `ansible_local.<file name>`:

| | Static fact | Executable fact |
|---|---|---|
| File | JSON or INI text, not executable | executable, prints JSON |
| Answers | what was applied | what is true now |
| Computed | at deployment, by Ansible | at every gathering, on the host |
| Cost | none | runs every time, and delays every play |
| Under `--check` | read | **runs for real** |

```yaml
- name: Hosts that describe themselves with custom facts
  hosts: targets
  gather_facts: false
  vars:
    lesson10_fact_dir: /tmp/lesson10/facts.d
  tasks:
    - name: Make sure the fact directory exists
      ansible.builtin.file:
        path: "{{ lesson10_fact_dir }}"
        state: directory
        mode: "0755"

    - name: Static fact - what was applied
      ansible.builtin.copy:
        dest: "{{ lesson10_fact_dir }}/applied.fact"
        content: "{{ {'profile': 'demo', 'revision': 3} | to_nice_json }}\n"
        mode: "0644"

    - name: Executable fact - what is true now
      ansible.builtin.copy:
        dest: "{{ lesson10_fact_dir }}/live.fact"
        content: |
          #!/bin/sh
          # read-only: facts are gathered in every run, also in --check
          count=$(ls -1 /tmp/lesson10 2>/dev/null | wc -l)
          printf '{"entries": %d, "shell": "%s"}\n' "$count" "$(basename "$(readlink -f /bin/sh)")"
        mode: "0755"

    - name: Gather the local facts again
      ansible.builtin.setup:
        fact_path: "{{ lesson10_fact_dir }}"
        gather_subset: min
        filter: ansible_local

    - name: Show what the host says about itself
      ansible.builtin.debug:
        var: ansible_local
      when: not ansible_check_mode
```

The lab examples use `/tmp/lesson10/facts.d` through the `fact_path` option of `setup`; in
production the default path is the one that plain fact gathering reads. The second run of the
play is `changed=0`; the executable fact reports the entries of `/tmp/lesson10` and which shell
`/bin/sh` is. Four properties decide whether facts are reliable:

- **Gathering happens before your files exist.** After deploying, `ansible_local` is stale
  (empty `{}` in a test) until a `setup` with `filter: ansible_local` gathers again. Under
  `--check` nothing was written, so it stays empty - which is why the `debug` is skipped there.
  The same data is `ansible_facts.ansible_local`. A `gather_subset` of `!all,!min` skips local
  facts: in a test the script did not run.
- **Types survive in JSON, not in INI.** JSON keeps numbers and key case (`revision: 3` stays an
  integer). INI gives every value as a string and lowercases the option names (`Mixed_Case`
  became `mixed_case`; section names kept their case).
- **A broken fact is text, not an error.** Invalid JSON, a non-zero exit code or a script
  without the execute bit all leave a string in `ansible_local` (`error loading facts as JSON or
  ini ...`, `Failure executing fact script ..., rc: 3`) and the play goes on. The consumer must
  check that it got a mapping.
- **Rights.** A fact script runs on the host with the rights of the task that gathers. In a
  test the scripts ran as the connection user (uid 1000, 1001 on ubuntu) without `become` and as
  root (uid 0) with `become: true`, on all eight targets - with an explicit `setup` task and
  with the implicit gathering at the start of a play (`become` set on the play). A script that reads files only root
  may read needs the privileged gathering. The directory is also a place where code runs as that
  user: whoever can write to it executes code as root in the next privileged run. Keep the files
  `root:root` and the directory closed to others.

A static fact is managed state like any file: no timestamp in it, or the second run is never
`changed=0`. An executable fact is code on every host and in every play: keep it fast, read-only
(it runs under `--check`), free of network access, and plain POSIX `sh` - the shell differs per
platform (see below).

## CIS background

Every Benchmark recommendation has an audit procedure and a remediation procedure (L01), and
this lesson is the Ansible side of keeping them together: the audit mode of a role is the audit
procedure, the enforce mode the remediation. Exercise 5.01 spans the Level 1 sections of the
stages before it (the header lists the ones the catalogue ties to it) and, as Level 2, 6.3
(auditd, L09).

A report is evidence, which is why auditors and insurers ask for one (L01). Read it with its
limits in mind. "All ok" means all *implemented* controls are ok: Manual recommendations, controls
the role does not have and controls marked not applicable are outside the number, as the
*Manual* recommendations are outside a CIS-CAT score. Excepted controls and controls of the
other profile are reporting states of their own; how a role decides them (`when`, `cis_level`,
documented exceptions) is the subject of L11. And compliance is still not security (L01).

The audit mode is also what makes drift visible. A scheduled audit-only run, kept as a series of
reports, shows when a host left the baseline - the reason to keep the audit free of side
effects and the report free of timestamps in managed files.

## Platform differences

| os_family | Hosts | `/bin/sh` (for fact scripts) | `service_mgr` fact | `/etc/systemd/system` |
|---|---|---|---|---|
| Debian | debian, ubuntu | dash | `systemd` | exists |
| RedHat | rocky, alma, fedora | bash | `systemd` | exists |
| Suse | opensuse | bash | `systemd` | exists |
| Alpine | alpine | BusyBox ash (`/bin/sh` is `/bin/busybox`) | `openrc` | does not exist |
| Archlinux | arch | bash | `systemd` | exists |

Measured on the lab's targets. A fact script therefore has to be POSIX `sh`: no arrays, no
`[[ ]]`, and only the tools BusyBox also has - the example passed in a test with BusyBox
applets only. The facts directory `/etc/ansible/facts.d` was absent on all eight hosts, so a play
creates it. The keywords that `sshd -T` prints differ in case between hosts (see L03), which
matters as soon as a report compares them.

### In the lab containers

- An audit reads the container, not a machine. For kernel parameters that is the container's
  view: a `net.*` key is per network namespace, a `kernel.*` key belongs to the host (L05).
- The lab connects as the user `ansible` (uid 1000, 1001 on ubuntu) without `become`: tasks that
  need root, and fact gathering that reads root-only files, need `become: true`.
- All examples use `hosts: targets` and therefore need 0.02 (Python on Alpine). They write below
  `/tmp/lesson10` of each target and of the control node; remove it with `rm -rf /tmp/lesson10`
  (on the targets, for example `ansible targets -m ansible.builtin.file -a 'path=/tmp/lesson10
  state=absent'`).

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The audit calls a wrong host fine | the check is a `command` or `shell` task, skipped in check mode, and only `changed` is counted | use a module that decides, or read with `check_mode: false` and compare |
| `--check` with the enforce mode wrote files | the keyword is `{{ mode == 'audit' }}`, which is `false` when enforcing and overrides `--check` | `ansible_check_mode or ...` |
| `when: not ansible_check_mode` does not protect an audited task | the variable is the command-line flag, not the keyword | test the mode variable |
| An audit run reloaded a service | a handler notified from an audited block runs for real | guard the handler with the mode |
| A background job is a deviation on every audit | `poll: 0` reports `changed` when the job starts, also in check mode | decide in a foreground task (L09) |
| `has no attribute` in the report play | a host has no result: it failed, was unreachable or was limited out | guard with `defined` and list the host as no data |
| The report changes on every run | a timestamp, or unsorted content | keep both out of the content; time in the file name or the log |
| `ansible_local` is empty or old after a deployment | facts were gathered before the files existed, or `--check` wrote nothing | gather again with `setup`; read with a `default` |
| A fact is a string such as `error loading facts` | invalid JSON, non-zero exit code, or no execute bit | run the script by hand; check that the value is a mapping |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [4.01](../../exercises/stage4-advanced/4.01-audit-only-report/README.md) | read-only evaluation with `check_mode: false` on readers, results as data with a status per control, `n/a` outside the score, aggregation over `hostvars`, hosts without data, a deterministic JSON and Markdown report |
| [4.05](../../exercises/stage4-advanced/4.05-custom-facts/README.md) | `facts.d`, static and executable facts, `ansible_local` and the re-gather, the rights and the cost of a fact script, no timestamps in managed files |
| [5.01](../../exercises/stage5-capstone/5.01-capstone-cis-role/README.md) | check mode as the audit engine behind a mode variable, what it does not stop (handlers, background tasks), why an include cannot carry the keyword, the report of a role |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A colleague already has a nightly audit script. Why would you still give the remediation role
   an audit mode?

   <details><summary>Answer</summary>

   Two code bases drift apart: the script tests what its author believes the role does, every
   rule exists twice and a bug in one never shows in the other. In audit mode the role's own
   tasks decide what is not in order, so the audit cannot disagree with the remediation. It
   also costs one switch instead of a second code base.

   </details>

2. In an audit run a control implemented as `command` is skipped, and the host appears fully
   compliant. Why, and what can you do?

   <details><summary>Answer</summary>

   A `command` task cannot predict its effect, so check mode skips it: `changed` is false and
   nothing was checked. That is "unknown", not "ok". Use a module that decides (`stat`, `copy`,
   `lineinfile` and so on), or read the state with a task that has `check_mode: false` and
   evaluate the value yourself.

   </details>

3. The enforce mode of your play sets `check_mode: "{{ mode == 'audit' }}"` on a block. Someone
   runs it with `-e mode=enforce --check`. What happens, and which expression is safe?

   <details><summary>Answer</summary>

   The expression is `false`, and `false` overrides `--check`: the block's tasks change the
   host for real. `ansible_check_mode or mode == 'audit'` stays a dry run when either asks for
   one.

   </details>

4. An audited block notifies a handler. The audit leaves the host unchanged, yet the service was
   reloaded. How, and how do you prevent it?

   <details><summary>Answer</summary>

   The keyword applies to the tasks of the block only. The handler has none and runs for real
   as soon as a checked task reports `changed`. Guard the handler with `when:` on the mode
   variable.

   </details>

5. The group has twelve hosts and the JSON report holds eleven. What could the twelfth be, and
   what must the report do about it?

   <details><summary>Answer</summary>

   A host that failed before it produced a result, was unreachable, or was left out by `-l`: it
   has no result variable. A report that silently leaves it out reads as "all fine". It lists
   the host explicitly as *no data*, and the guard in the aggregation (`defined`) keeps the read
   from failing.

   </details>

6. A report template prints the time of the run. What does that do to the run, and where does
   the time belong?

   <details><summary>Answer</summary>

   The file differs on every run, so the run is never `changed=0`, real drift is lost in the
   noise and version control fills with diffs. Keep managed files a pure function of their
   inputs; put the time in the file name or in the log of the runner.

   </details>

7. "Which baseline revision was applied?" and "is root login off right now?" - which is a static
   and which an executable fact, and what does each cost?

   <details><summary>Answer</summary>

   The revision is *what was applied*: a static fact written at deployment, it costs nothing
   afterwards. The state of root login is *what is true now*: an executable fact, which runs
   on every gathering, delays every play, runs also under `--check` (so it must be read-only)
   and needs the right privileges to see what it measures. A static fact can be stale; an
   executable one can be slow or fail.

   </details>

8. You deploy a fact file in the middle of a play and read `ansible_local.x` right after it: it
   is undefined. After a `setup` with `filter: ansible_local` it is there - except under
   `--check` on a fresh host. Why?

   <details><summary>Answer</summary>

   Facts are gathered once, before the file existed, so the variable is stale until a new
   gathering. Under `--check` the `copy` writes nothing, so even the new gathering finds no
   file. Consumers need a `default` or a skip when `ansible_check_mode` is true.

   </details>

## Further reading

- [Validating tasks: check mode and diff mode](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html) - the keyword, the flag and `check_mode: false`
- [Blocks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_blocks.html) and [Handlers](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html) - what a block's keywords reach and when a handler runs
- [Discovering variables: facts and magic variables](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_vars_facts.html) - local facts and `hostvars`
- [`ansible.builtin.setup`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/setup_module.html) - `fact_path`, `gather_subset` and `filter`
- [Special variables](https://docs.ansible.com/projects/ansible/latest/reference_appendices/special_variables.html) - `hostvars`, `groups` and `ansible_check_mode`
- [Using filters to manipulate data](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_filters.html) - `to_nice_json`, `selectattr`, `difference`
- [Glossary](../GLOSSARY.md) - terms of this lesson: audit mode, compliance report, custom facts,
  `delegate_to` / `run_once`, enforce mode, finding
