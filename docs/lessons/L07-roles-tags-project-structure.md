# L07 - Roles, tags and project structure: one baseline, many switches

*[Deutsch](L07-roles-tags-project-structure.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 3.01 | 1.1.1, 1.5, 1.6, 2.1, 2.2, 2.4, 3.3, 5.1, 5.2, 7.1 | ~35 min | L02, L04 |

A hardening baseline is hundreds of tasks. Spread over one playbook per topic they get copied,
drift apart and can only be run as a whole. A role gives them one home with a fixed layout, a
visible interface and switches to run a part. This lesson covers what a role is made of, which
of its values a user may change, how to split and select its tasks, and how `ansible-lint` keeps
the result in shape.

## Learning goals

After this lesson you can ...

- [ ] list the directories of a role and say which ones Ansible loads on its own
- [ ] decide whether a value belongs into `defaults/` or `vars/`, and predict which layer wins
- [ ] explain why role variables and registered results need a prefix
- [ ] choose between `import_tasks` and `include_tasks` and read the difference in `--list-tasks`
- [ ] select tasks with tags and mark the tasks that other tasks depend on with `always`
- [ ] say what each `ansible-lint` profile adds and read a violation
- [ ] explain how to show that a refactoring did not change behaviour

## Theory

### A role is a directory with a contract

The problem: a playbook that grows past a screen mixes three things - what to do, which values
to use and which files to render. Copy it to a second project and you maintain two versions. A
role separates them by **convention**: Ansible looks for fixed names inside a directory and
loads what it finds, so the layout is the interface.

| Path in the role | Loaded | Typical content |
|---|---|---|
| `tasks/main.yml` | always, the entry point | tasks, or imports of other task files |
| `defaults/main.yml` | always | values a user may change; lowest precedence |
| `vars/main.yml` | always | internal data; high precedence |
| `handlers/main.yml` | always | handlers the tasks notify |
| `meta/main.yml` | always | Galaxy metadata, role dependencies |
| `templates/`, `files/` | on demand | found by *name* from `template` and `copy` |

`ansible-galaxy role init <name>` writes a skeleton: `README.md`, `defaults/`, `handlers/`,
`meta/`, `tasks/`, `tests/` and `vars/` (checked with ansible-core 2.21; no `templates/` or
`files/`). Empty files are fine: a role whose `defaults/main.yml` is empty, only `---`, or only
a comment still runs.

The examples of this lesson use a small demo role, `demo_stamp`. It renders a file whose
template depends on the host and reports what it did. Build it in a scratch directory on the
control node (the script is long because it is the role; read the comments, not every line):

```bash
mkdir -p /tmp/lesson07/roles/demo_stamp/{defaults,vars,tasks,handlers,templates}
cd /tmp/lesson07/roles/demo_stamp

# values a user may change
cat > defaults/main.yml <<'EOF'
---
demo_stamp_path: /tmp/lesson-stamp.conf
demo_stamp_mode: "0644"
demo_stamp_note: baseline
demo_stamp_level: 1
EOF

# internal data
cat > vars/main.yml <<'EOF'
---
demo_stamp_header: managed by the demo_stamp role
EOF

# three templates: generic, one for a whole family, one for one distribution
cat > templates/stamp.conf.j2 <<'EOF'
header={{ demo_stamp_header }}
note={{ demo_stamp_note }}
EOF
cat > templates/stamp.Debian.conf.j2 <<'EOF'
header={{ demo_stamp_header }}
note={{ demo_stamp_note }}
family=Debian
EOF
cat > templates/stamp.Fedora.conf.j2 <<'EOF'
header={{ demo_stamp_header }}
note={{ demo_stamp_note }}
distribution=Fedora
EOF

# the entry point
cat > tasks/main.yml <<'EOF'
---
- name: Pick the template for this host
  ansible.builtin.set_fact:
    demo_stamp_source: "{{ lookup('ansible.builtin.first_found', demo_stamp_candidates) }}"
  vars:
    demo_stamp_candidates:
      files:
        - "stamp.{{ ansible_facts.distribution }}.conf.j2"
        - "stamp.{{ ansible_facts.os_family }}.conf.j2"
        - stamp.conf.j2
      paths:
        - "{{ role_path }}/templates"
  tags: [always]

- name: Write the stamp
  ansible.builtin.template:
    src: "{{ demo_stamp_source }}"
    dest: "{{ demo_stamp_path }}"
    owner: root
    group: root
    mode: "{{ demo_stamp_mode }}"
  notify: Announce stamp change
  tags: [stamp]

- name: Report on the stamp
  ansible.builtin.import_tasks: report.yml
  tags: [report]

- name: Extras for the chosen level
  ansible.builtin.include_tasks: "level_{{ demo_stamp_level }}.yml"
  tags: [extras]
EOF

# the two task files the entry point pulls in
cat > tasks/report.yml <<'EOF'
---
- name: Look at the stamp
  ansible.builtin.stat:
    path: "{{ demo_stamp_path }}"
  register: demo_stamp_stat

- name: Say which template was used
  ansible.builtin.debug:
    msg: "{{ demo_stamp_source | basename }} -> {{ demo_stamp_path }}, exists: {{ demo_stamp_stat.stat.exists }}"
EOF
for n in 1 2; do
cat > "tasks/level_$n.yml" <<EOF
---
- name: Extras of level $n
  ansible.builtin.debug:
    msg: "level $n extras"
EOF
done

# the handler the stamp task notifies
cat > handlers/main.yml <<'EOF'
---
- name: Announce stamp change
  ansible.builtin.debug:
    msg: the stamp changed
EOF
```

Two details of the entry point matter later. The first task chooses a template with
`first_found`: it walks a list of file names, most specific first, and returns the first that
exists in `paths`. The chain here is *distribution*, then *family*, then a generic file; if no
candidate exists the lookup fails with `No file was found when using first_found`, so keep a
generic last entry. And that task is tagged `always` - the fourth concept explains why.

A role does nothing until a play uses it:

```yaml
- name: Apply the demo role
  hosts: targets
  become: true
  roles:
    - role: demo_stamp
```

Save it as `/tmp/lesson07/site.yml` and run it twice:

```bash
cd /tmp/lesson07
ansible-playbook site.yml
ansible-playbook site.yml
```

The first run changes the file on every host and runs the handler; the second reports
`changed=0` and no handler. The task names carry the role name (`demo_stamp : Write the stamp`),
which is how you tell roles apart in the output.

**Where Ansible looks for a role.** The "not found" message lists the places searched: a
`roles/` directory next to the playbook, the directories of `roles_path` (in the lab
`/lab/work/roles:/lab/ansible/roles`) and the playbook's own directory. The **current working
directory** is searched as well, although the message does not list it; when the same name
exists in `roles_path` and in the working directory, `roles_path` wins (measured). The
working-directory rule bites in the lab: with `/lab` as working directory, `role: cis` can
resolve to the catalogue directory `cis/` if nothing named `cis` exists in `roles_path`. Run
from the project directory, keep roles under one `roles/`, and read the list in the error
message when a role is not found.

**Three ways to call a role.** `roles:` is static and has a fixed place in a play: `pre_tasks`,
then `roles:`, then `tasks:` - even when the YAML lists `tasks:` first. `ansible.builtin.import_role`
is also static but runs where it stands among the tasks, and `ansible.builtin.include_role`
is dynamic: it is resolved when the task is reached. `--list-tasks` shows the tasks of
`roles:` and of `import_role`, and only the include itself for `include_role`. A role listed
twice in `roles:` runs once - unless the parameters differ or `meta/main.yml` sets
`allow_duplicates: true`.

### `defaults/` and `vars/`: an interface and internal data

The problem: a role is used by people who did not write it. They need a short list of values
they may change, and they need the platform facts and internal constants to stay as the author
set them. The two directories encode exactly that, through **precedence**. From weaker to
stronger, for what this lesson uses:

| Layer | Beats |
|---|---|
| role `defaults/main.yml` | nothing; every other layer overrides it |
| inventory (`group_vars`, `host_vars`) | the role defaults |
| play `vars:` | the role defaults and the inventory |
| role `vars/main.yml` | the play and the inventory |
| `-e name=value` | everything |

The complete list has more levels (L04 has the short version). Check it with the demo role.
The play sets one default and one role variable:

```yaml
- name: Which layer wins, a default or a role variable?
  hosts: targets
  become: true
  vars:
    demo_stamp_note: set by the play
    demo_stamp_header: set by the play
  roles:
    - role: demo_stamp
  post_tasks:
    - name: Read the stamp back
      ansible.builtin.command: cat /tmp/lesson-stamp.conf
      register: lesson_stamp
      changed_when: false
      when: not ansible_check_mode
    - name: Show it
      ansible.builtin.debug:
        var: lesson_stamp.stdout_lines
      when: not ansible_check_mode
```

Save it as `/tmp/lesson07/override.yml` and run `ansible-playbook override.yml` from that
directory. The file ends up with `note=set by the play` - the play beat the default - and still
with `header=managed by the demo_stamp role`: the play lost against `vars/main.yml`. Add
`-e demo_stamp_header=cli` and the header changes, because only the command line beats a role's
`vars/`. The stamp file also keeps its Debian line on Debian and Ubuntu, so the rendered text
differs by host.

The rule of thumb follows: **if a user might want a different value, it is a default.** A value
in `vars/` cannot be overridden from the inventory or the play, which is right for a service
name that is a fact of the platform and wrong for a path, a limit or a list of packages.

**Prefix every name.** Variables from `defaults/` and `vars/` are not private. They live in the
namespace of the whole play: a role's `defaults/` and `vars/` are visible to every task after
the role, even when the role's tasks were skipped by a `when` (measured). Two roles that both
define `owner` overwrite each other, and a role variable can silently replace one the play
author already had. So a role prefixes everything it owns - defaults, vars, `register`,
`set_fact` - with its own name (`demo_stamp_...`). `ansible-lint` enforces it with the rule
`var-naming[no-role-prefix]`.

### `import_tasks` and `include_tasks`: static and dynamic

The problem: a role's `tasks/main.yml` should stay readable, so the tasks move into files of
their own, one per topic. Two modules pull a file in, and they differ in **when**:

- `import_tasks` is **static**. The file is read when the playbook is parsed, its tasks become
  part of the play, and tags and `when` of the import are copied to every task inside.
- `include_tasks` is **dynamic**. The file is read when the task is reached, so its name may
  contain a variable and the include may have a `loop`. Tags and `when` apply to the include,
  not to the tasks inside.

The difference is visible without running anything:

```bash
cd /tmp/lesson07
ansible-playbook site.yml --list-tasks
ansible-playbook site.yml --list-tags
ansible-playbook site.yml --tags extras -e demo_stamp_level=2
```

`--list-tasks` shows the two tasks of `report.yml` individually, both tagged `report`, but only
one line for the include - the tasks of `level_1.yml` or `level_2.yml` exist only once the
play runs. The third command picks the second level file by variable. It also shows that the
tag of the include stops at the include: the tasks inside carry no `extras` tag, so with
`--tags extras` the include runs but its tasks do not. Either tag the tasks inside the file,
or write the include in its long form with `file:` and `apply:` (`apply: {tags: [extras]}`),
which hands the tags down to the included tasks - measured, with `apply` both tasks of the
file run under `--tags extras`.

More measured consequences:

- A `when` on an import is evaluated once per task inside: every task is shown as `skipping`.
- `loop` on `import_tasks` is refused at load time: `You cannot use loops on 'import_tasks'
  statements. You should use 'include_tasks' instead.`
- A missing file behind `import_tasks` fails `--syntax-check`; behind `include_tasks` it
  passes the check and fails when the task is reached. Fixed names are safer.

Use `import_tasks` for a fixed split of a role into files, and `include_tasks` when the file
name or the repetition depends on data.

### Tags: choosing what runs

The problem: a full run of a hardening role takes minutes and touches everything, while the
question is often "only SSH" or "everything but the firewall". **Tags** label tasks, blocks,
imports, role entries and plays, and the command line selects by label: `--tags a,b` runs
only tasks carrying one of them, `--skip-tags` runs everything else, `--list-tags` shows what
exists. A tag on a block, an import or a role entry is inherited by every task inside it:

```yaml
- name: Tag the whole role
  hosts: targets
  become: true
  roles:
    - role: demo_stamp
      tags: [baseline]
```

Save it as `/tmp/lesson07/site_tag.yml`; `--tags baseline` now runs the entire role, and
`--tags stamp` still runs only its one task (plus the `always` task and fact gathering). That
is the design to aim for: a coarse tag for the whole unit and a fine tag per topic, named
after what an operator wants to run alone.

The sharp edge: **with `--tags`, tasks without a matching tag are skipped** - including
tasks that other tasks depend on. Two special tags handle it. `always` runs the task whatever
`--tags` says (only `--skip-tags always` stops it); `never` does the opposite - the task runs
only when one of its other tags is named explicitly. What the demo role does under each
selection:

| Command | What runs |
|---|---|
| no option | all tasks |
| `--tags report` | the `always` task, then the two tasks of `report` |
| `--tags extras` | the `always` task, then the include itself; not the tasks inside it |
| `--skip-tags stamp` | everything except writing the file |
| `--tags report --skip-tags always` | fails: `'demo_stamp_source' is undefined` |

The last line is the pitfall. Without `always`, a task that computes or loads something for
later tasks is skipped under every `--tags` selection that does not name it, and the first
task that uses the result fails. Whatever later tasks need goes under `always`; whatever is a
dangerous extra goes under `never` plus a tag you name on purpose.

`--list-tasks` honours the selection: `--list-tasks --tags report` prints the `always` task and
the two tasks of `report` without running anything - a cheap way to see what a tag combination
will do before it touches a host.

### Linting a role

The problem: YAML that Ansible accepts can still be wrong in ways that surface late - an
unquoted mode that YAML reads as an octal number, a command that reports `changed` on every
run, a variable that collides with another role's. `ansible-lint` reads playbooks and roles
and reports such patterns. Its rules are grouped into **profiles**, each including the one
before it, so you can raise the bar step by step (`ansible-lint -P` lists them with every
rule):

| Profile | What it adds (a selection) |
|---|---|
| `min` | the content loads at all: syntax errors, files that cannot be parsed |
| `basic` | formatting and idioms: `var-naming`, `name`, `yaml`, `role-name`, `schema`, `key-order`, no deprecated modules |
| `moderate` | readable names: `name[casing]`, `name[template]`, `name[imperative]` |
| `safety` | avoid risk: `risky-file-permissions`, `latest`, `risky-shell-pipe` |
| `shared` | ready for sharing: `no-changed-when`, `no-handler`, `meta-*`, `galaxy`, `max-tasks`, `unsafe-loop` |
| `production` | strictest: `fqcn`, `avoid-dot-notation`, `use-loop`, `single-entry-point`, `meta-no-dependencies` |

A deliberately poor role shows what a run says. The role has a default without a prefix, a
module without its collection name, an unquoted mode, an unnamed task and a `command` that
never says when it changes something:

```bash
mkdir -p /tmp/lesson07/roles/lintdemo/{tasks,defaults}
cd /tmp/lesson07
cat > roles/lintdemo/defaults/main.yml <<'EOF'
---
owner: root
EOF
cat > roles/lintdemo/tasks/main.yml <<'EOF'
---
- name: Write a file
  copy:
    dest: /tmp/lintdemo
    content: hi
    mode: 0644

- ansible.builtin.command: cat /tmp/lintdemo
  register: result

- name: Show who owns it
  ansible.builtin.debug:
    msg: "{{ owner }} {{ result.stdout }}"
EOF
ansible-lint --offline --profile basic --format pep8 roles/lintdemo
ansible-lint --offline --profile production --format pep8 roles/lintdemo
```

`basic` reports four violations, `production` six (shortened, without the note about
directory expansion that `ansible-lint` always prints for a directory argument):

```
roles/lintdemo/defaults/main.yml:2:1: var-naming[no-role-prefix]: Variables names from within roles should use lintdemo_ as a prefix. (vars: owner)
roles/lintdemo/tasks/main.yml:3:3: fqcn[action-core]: Use FQCN for builtin module actions (copy).
roles/lintdemo/tasks/main.yml:6: yaml[octal-values]: Forbidden implicit octal value "0644"
roles/lintdemo/tasks/main.yml:8: name[missing][/]: All tasks should be named.
roles/lintdemo/tasks/main.yml:8: no-changed-when: Commands should not change things if nothing needs doing.
roles/lintdemo/tasks/main.yml:8:13: var-naming[no-role-prefix]: Variables names from within roles should use lintdemo_ as a prefix. (register: result)
Failed: 6 failure(s), 0 warning(s) in 3 files processed of 3 encountered. Profile 'production' was required, but 'min' profile passed.
```

Read a line as `file:line:column: rule[detail]: message`. The rule name is what you search for
in the documentation or silence deliberately; the last line says which profile was demanded
and which one the content actually reaches. With `basic`, `fqcn` and `no-changed-when` are
not reported - they belong to higher profiles, which is why the same role can pass one level
and fail the next. The exit code is `2` when anything fatal remains, so a pipeline can gate
on it. Without `--profile` all rules apply.

Three details from the same measurements:

- `--offline` stops `ansible-lint` from trying to reach Galaxy. The repository has an
  `.ansible-lint` that sets `offline: true`; a role outside the repository, like the demo
  role, is linted with the flag on the command line.
- `meta/main.yml` is optional for a local role and a file with only `dependencies: []` passes
  `production`, but a present, incomplete `galaxy_info` is validated: `galaxy_info: {}` fails
  with `schema[meta]`. Give it a name, author, description, license, minimum version and
  platforms, or leave the key out.
- A role directory must match `^[a-z][a-z0-9_]*$`: `role-name` flags a directory called
  `Bad-Name` already at `basic`. Lowercase letters, digits and underscores, starting with a
  letter, are safe.

Lint checks form, not behaviour. For a **refactoring** - moving tasks into a role without
changing what they do - the evidence is behavioural: apply the old playbooks to fresh hosts,
record what the checks say, apply the role to fresh hosts, and compare. A second run with
`changed=0` and a clean `--check --diff` show that the role is idempotent. Frameworks such as
Molecule automate the same loop: apply to a fresh instance, verify, apply again.

## CIS background

All ten catalogue sections in the header (see [the control catalogue](../../cis/controls.yml))
list this exercise because it collects earlier work: banners, kernel modules, sysctl values,
services, cron and file permissions, SSH, sudo and account files. The benchmark itself says
nothing about how automation is structured; the structure is yours, and the benchmark shapes
three choices.

First, **traceability**: an auditor asks which task implements a recommendation, and an
operator asks to re-run only that part. Tags that mirror the benchmark's topics answer both
without a spreadsheet. Second, the **profile**: Level 1 and Level 2 differ in how much a role
does, so the level is a value in `defaults/` that tasks and imports test with `when` (L01 used
it from the command line; L11 shows how a role honours it and records exceptions). Third,
**ownership**: a role is one reviewable, versioned artifact. A hardening change that arrives
as a diff to one directory can be read, tested on fresh hosts and rolled back; the same change
scattered over many playbooks cannot.

A cost to name: a baseline role is applied to every host, so its defaults are decisions for
every host. Review `defaults/` like a security policy, not like configuration.

## Platform differences

A role's mechanics - layout, precedence, imports, tags, lint - run on the control node and
are identical for all eight targets. The platforms differ in the data a role chooses by. The
demo role picks a template with the chain *distribution, then family, then generic*:

| os_family | Hosts | `distribution` fact | Template the demo role picks |
|---|---|---|---|
| Debian | debian, ubuntu | Debian, Ubuntu | `stamp.Debian.conf.j2` for both: debian matches by distribution, ubuntu falls through to the family |
| RedHat | rocky, alma, fedora | Rocky, AlmaLinux, Fedora | fedora: `stamp.Fedora.conf.j2`; rocky and alma: the generic file |
| Suse | opensuse | openSUSE Leap | the generic file |
| Alpine | alpine | Alpine | the generic file |
| Archlinux | arch | Archlinux | the generic file |

The table is the result of the lookup applied to the values in the second column, computed
with the same `first_found` expression; the `distribution` values are the ones L04 measured on
the lab hosts. Note the space in `openSUSE Leap`: a file name built from it simply does not
exist, and the lookup moves on to the next candidate. Keep the generic file last - without it a
platform you did not anticipate fails the task.

### In the lab containers

- The demo role lives in `/tmp/lesson07` on the **control node**, outside `/lab/work`, so it
  cannot collide with the roles of the exercises (3.01 starts from a skeleton that
  `lab start 3.01` creates in `/lab/work/roles/cis`). The lab's `ansible.cfg` sets `roles_path`
  to `/lab/work/roles:/lab/ansible/roles`; the `roles/` directory next to the playbook is
  searched too.
- The play runs on all hosts of `targets`; alpine needs Python from exercise 0.02 first,
  because the play gathers facts.
- The stamp file lands in `/tmp` of each target. Remove it with
  `ansible targets -b -m ansible.builtin.file -a "path=/tmp/lesson-stamp.conf state=absent"` or
  with `./lab.sh reset <host>` (`.\lab.ps1 reset <host>` on Windows).
- Run `ansible-lint` on the control node, where the pinned version is installed; the same
  version runs in the repository's CI gate.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `The role 'x' was not found in: ...` | name or location wrong; the message lists the directories searched | fix the name, put the role into `roles_path` or `roles/` next to the playbook |
| A role is found although it is not in `roles_path` | the current working directory is searched too, and is not listed in the message | run from the project directory; keep roles in one `roles/`; do not name a directory like a role |
| A play variable or inventory value has no effect on a role | the value lives in the role's `vars/`, which beats both | move values users may change to `defaults/`; override a `vars/` value only with `-e` |
| `Finalization of task args ... 'demo_stamp_source' is undefined` under `--tags` | the task that sets the variable is not tagged `always` | tag preparation tasks `always` |
| `--tags extras` runs the include but not the tasks in its file | on `include_tasks` the tag stays on the include | tag the inner tasks, use `apply: {tags: [...]}`, or use `import_tasks` |
| `You cannot use loops on 'import_tasks' statements.` | imports are resolved at parse time, before a loop exists | `include_tasks` with `loop`, or loop inside the file |
| `Could not find or access '.../level_3.yml'` only at run time | a dynamic include's file name comes from a variable and is not checked in advance | validate the variable, or choose from a fixed list |
| Two roles interfere through a variable of the same name | role variables share the play's namespace | prefix every default, var, `register` and `set_fact` with the role name |
| The second `- role: x` in `roles:` does nothing | a role with identical parameters runs once | give it different parameters, or set `allow_duplicates: true` in `meta/main.yml` |
| `No file was found when using first_found` | none of the candidates exists | end the list with a generic file, or pass `skip: true` (the lookup then returns an empty result you handle yourself) |
| `Failed: n failure(s) ... Profile 'production' was required` and exit code 2 | rules of the demanded profile are violated | fix them, or demand a lower profile with `--profile` while the role matures |
| `schema[meta]` on `meta/main.yml` | `galaxy_info` is present but incomplete | complete it, or remove the key |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [3.01](../../exercises/stage3-intermediate/3.01-build-the-cis-role/README.md) | the layout of a role and what is loaded on its own, defaults against vars and the prefix rule, static imports and their tags, `always`, choosing data by platform, linting and the before/after comparison of a refactoring |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. Which files of a role does Ansible load without being told, and which does it only look up
   by name?

   <details><summary>Answer</summary>

   `tasks/main.yml`, `defaults/main.yml`, `vars/main.yml`, `handlers/main.yml` and
   `meta/main.yml` are loaded when the role is used. `templates/` and `files/` are only
   searched when a task such as `template` or `copy` names a file. Further task files are read
   only when an import or include names them.

   </details>

2. A role defines `ssh_port: 22` in `defaults/main.yml` and `ssh_port: 2222` in `vars/main.yml`
   by mistake. The inventory sets `ssh_port: 2200`, the play sets nothing, and you run with
   `-e ssh_port=2300`. Which value do the tasks see, and which without `-e`?

   <details><summary>Answer</summary>

   With `-e` it is 2300: the command line beats every other layer. Without it it is 2222,
   because the role's `vars/` beats the inventory (2200) and the defaults (22). The duplicate is
   the mistake: a value users may change belongs only in `defaults/`.

   </details>

3. Why does a role named `hardening` call its registered variable `hardening_cron_stat`
   instead of `cron_stat`?

   <details><summary>Answer</summary>

   Variables of a role, including registered results and facts it sets, share the namespace of
   the whole play. An unprefixed name can overwrite or be overwritten by another role or by the
   play, and the damage appears far from its cause. The prefix keeps a role's names its own,
   and `ansible-lint` flags the omission as `var-naming[no-role-prefix]`.

   </details>

4. `--list-tasks` shows four tasks for a file imported with `import_tasks` but only one line
   for a file pulled in with `include_tasks`. Why, and what does that mean for `--tags`?

   <details><summary>Answer</summary>

   An import is resolved when the playbook is parsed, so its tasks exist before the run and
   inherit the tags and conditions of the import. An include is read when the task is reached;
   `--list-tasks` cannot see inside, and a tag on the include does not reach the tasks of the
   file unless you tag them or use `apply`.

   </details>

5. After a refactoring, `ansible-playbook site.yml --tags ssh` fails on the first task that
   uses a variable which a task near the top of the role sets with `set_fact`. A full run
   works. What happened, and what is the fix?

   <details><summary>Answer</summary>

   Under `--tags ssh` the task that sets the variable has no matching tag and is skipped, so
   the variable is undefined for the tasks that follow. Tag every task that later tasks depend
   on `always`, so it runs whatever `--tags` selects.

   </details>

6. `ansible-lint --profile production` ends with `Profile 'production' was required, but 'min'
   profile passed.` and exit code 2. What does the sentence say, and how do you go on?

   <details><summary>Answer</summary>

   Violations of rules in profiles above `min` remain, so the content only reaches `min`, the
   level at which it merely loads. Read each `file:line: rule` line, fix them, and run again;
   while a role matures you can demand a lower profile and raise it step by step. The non-zero
   exit code makes the run usable as a gate.

   </details>

7. You moved the tasks of a dozen playbooks into one role. How do you show that the role does
   what the playbooks did?

   <details><summary>Answer</summary>

   Behavioural evidence, not lint: apply the playbooks to fresh hosts and record the result of
   the checks, reset, apply the role, and run the same checks. Then run the role a second time
   (`changed=0`) and with `--check --diff` (no differences). If the checks agree and the run is
   idempotent, the refactoring preserved behaviour.

   </details>

## Further reading

- [Roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html) - layout, search paths, `roles:` against `import_role` and `include_role`, dependencies
- [Re-using files and roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse.html) - static imports against dynamic includes
- [Tags](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_tags.html) - `always`, `never`, inheritance, `--tags` and `--skip-tags`
- [Using variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html) - the full precedence list
- [`ansible.builtin.first_found`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/first_found_lookup.html) - the lookup used by the demo role
- [ansible-lint](https://docs.ansible.com/projects/lint/) - profiles, rules and configuration
- [Glossary](../GLOSSARY.md) - terms of this lesson: `always` (tag), `defaults/` and `vars/`,
  `first_found`, `import_tasks` / `include_tasks`, `include_vars`, lint profile, role, tag
