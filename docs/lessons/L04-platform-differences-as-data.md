# L04 - Platform differences as data: dictionaries, loops, Jinja2 and templates

*[Deutsch](L04-platform-differences-as-data.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 2.01, 2.02, 2.06 | 1.6, 5.1, 7.1 | ~25 min | L00, L02, L03 |

Eight hosts, five OS families, one policy: if every difference gets its own `when`, the playbook
grows with every distribution. This lesson shows the alternative - keep *what differs* in data and
*what to do* in one task - and the four tools that make it work: dictionaries, loops, Jinja2
expressions and templates.

## Learning goals

After this lesson you can ...

- [ ] replace a chain of `when` conditions by a lookup in a dictionary keyed by a fact, and decide what happens for an unknown key
- [ ] read the structure of a registered loop result and act on a subset of its items
- [ ] use filters and tests to shape data, and say what happens when a variable is undefined
- [ ] write a template with loops and conditions that renders identical output on every run
- [ ] predict which value a variable has when several layers of the inventory and the play define it

## Theory

### One task, many platforms: data instead of conditions

The first reflex for "this differs on RedHat" is a task with `when: ansible_facts.os_family ==
'RedHat'`. With three families that is three near-identical tasks; with five, five - and every
change must be made five times. When only a *value* differs (a name, a mode, a path), put the
values into a dictionary and look one up with the fact as the key:

```yaml
- name: One lookup instead of five conditions
  hosts: targets
  vars:
    sshd_service:
      Debian: ssh
      RedHat: sshd
      Suse: sshd
      Alpine: sshd
      Archlinux: sshd
  tasks:
    - name: Name of the SSH daemon on this host
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }}: {{ sshd_service[ansible_facts.os_family] }}"
    - name: The same lookup with a family nobody listed
      ansible.builtin.debug:
        msg: "{{ sshd_service['Gentoo'] | default('sshd') }}"
```

Use brackets when the key is a variable; `sshd_service.Debian` works for a fixed name. Keys are
matched exactly and case-sensitive: `Archlinux`, not `Arch`, and not the inventory group
`arch_family`. A key that is missing makes
the task fail (`object of type 'dict' has no attribute 'Gentoo'`). That is a feature: a new
family is noticed on the first run instead of being treated like another. A `default` turns the
failure into a guess, which is right for a harmless value like a service name that is usually
`sshd` and wrong for a security setting. Choose it deliberately.

Data does not replace `when`. If the *behaviour* differs - a task that exists on one family
only, or a different module - a condition says it more clearly: values go into dictionaries,
steps go into conditions. Where the dictionary lives (play `vars` here, files per family in a
role) is the topic of L11.

### Loops over data

`loop` runs a task once per item and puts the item into `item`. A list is the simple case; a
dictionary becomes a list with `dict2items` (items with `key` and `value`). With long items the
output is unreadable, so `loop_control.label` chooses what is printed.

The step that surprises people is `register` on a looped task. The variable then holds a
structure whose `results` list has **one entry per item**, and each entry carries the module's
result *and* the original item under `item`. Feeding it into a second loop gives you the
original input as `item.item`:

```yaml
- name: Act only on the paths that exist
  hosts: targets
  become: true
  vars:
    wanted_modes:
      /tmp/lab-data/one.txt: "0640"
      /tmp/lab-data/two.txt: "0600"
  tasks:
    - name: Scratch directory
      ansible.builtin.file:
        path: /tmp/lab-data
        state: directory
        mode: "0755"
    - name: Only one of the two files exists
      ansible.builtin.copy:
        dest: /tmp/lab-data/one.txt
        content: "demo\n"
        mode: "0640"
    - name: Look at every path
      ansible.builtin.stat:
        path: "{{ item.key }}"
      loop: "{{ wanted_modes | dict2items }}"
      loop_control:
        label: "{{ item.key }}"
      register: probe
    - name: Apply the mode where the file exists
      ansible.builtin.file:
        path: "{{ item.item.key }}"
        mode: "{{ item.item.value }}"
      loop: "{{ probe.results | selectattr('stat.exists') | list }}"
      loop_control:
        label: "{{ item.item.key }}"
```

`selectattr('stat.exists')` keeps the entries whose `stat.exists` is true, so the second loop
only sees `one.txt`. The alternative is to loop over all results and put a condition on the task:
skipped items still show up in the output and in `results`, marked as skipped, whereas the
filter hides them from the loop entirely. Both are correct; choose the one whose output you can
read at 3 a.m. This is how a task copes with files that exist on some hosts only - the gap L03
left open.

Caution: `item` belongs to the *innermost* loop; a task file that is included from a loop and
loops itself needs `loop_var` to avoid the clash.

### Jinja2 in Ansible: expressions, filters, undefined values

Everything between `{{ }}` is a Jinja2 expression, evaluated on the **control node** with the
variables of the current host - the target never sees Jinja2, only the result. `{% %}` holds
control statements (`for`, `if`) and `{# #}` comments; both are at home in template files.
A YAML value that *starts* with `{{` must be quoted, otherwise YAML reads a dictionary.

Filters transform a value, written with `|`; tests ask a question, written with `is`:

```yaml
- name: Filters and tests in one place
  hosts: targets
  vars:
    users: [bob, alice, bob]
    limits: {tries: 4, grace: 60}
  tasks:
    - name: Shape the data
      ansible.builtin.debug:
        msg:
          - "{{ users | unique | sort | join(' ') }}"
          - "{{ limits | dict2items | map(attribute='key') | sort | list }}"
          - "{{ limits.tries * 2 }}"
          - "{{ optional_banner | default('none') }}"
          - "{{ 'tries' in limits }} {{ limits.grace is defined }}"
```

Each filter takes the result of the previous one. `unique`, `sort`, `join`, `map`,
`select`/`selectattr` and `list` cover most of what hardening playbooks need; `lower` normalises
a keyword before a comparison (L03 had a case where it mattered). The expression
`limits.tries * 2` gives the *number* 8, not the text "8": Ansible keeps the type of a result
that consists of one expression. Text that merely looks like a number (the mode `"0640"`) stays
text because you quoted it.

An **undefined variable is an error**, not an empty string: the task fails with `'x' is
undefined`, in a template too. For optional values there are three tools: `| default('none')`
supplies a value; `| default(omit)` as a module argument leaves the option out entirely, so the
module's own default applies; `| mandatory('message')` fails with a message of your choice. A
`default` also swallows a *typo* in a variable name, so use it only where the value is truly
optional.

A `when` is a Jinja2 expression without braces, and in ansible-core 2.21 it must produce a
boolean: `when: "'yes'"` fails with "Conditionals must have a boolean result". Write the
comparison out (`when: answer == 'yes'`).

### Templates: files rendered from variables

The `template` module renders a Jinja2 file on the control node and copies the result to the
target, with the same owner, mode, `validate` and `--check --diff` behaviour as `copy` (L02).
The template files live in `templates/` next to the playbook. Save this one as
`templates/app.conf.j2`:

```jinja2
{{ ansible_managed | comment }}
{% for name, value in app_settings | dictsort %}
{% if value is boolean %}
{{ name }} {{ 'yes' if value else 'no' }}
{% else %}
{{ name }} {{ value }}
{% endif %}
{% endfor %}
AllowUsers {{ app_users | join(' ') }}
{% if app_extra is defined %}
Extra {{ app_extra }}
{% endif %}
```

and render it:

```yaml
- name: Render a generic configuration file
  hosts: targets
  vars:
    app_settings: {Retries: 4, Compress: false, Mode: strict}
    app_users: [alice, bob]
  tasks:
    - name: Scratch directory
      ansible.builtin.file:
        path: /tmp/lab-app
        state: directory
        mode: "0755"
    - name: Render several files from one list
      ansible.builtin.template:
        src: "{{ item.src }}"
        dest: "{{ item.dest }}"
        mode: "{{ item.mode }}"
      loop_control:
        label: "{{ item.dest }}"
      loop:
        - {src: app.conf.j2, dest: /tmp/lab-app/a.conf, mode: "0644"}
        - {src: app.conf.j2, dest: /tmp/lab-app/b.conf, mode: "0600"}
```

Ansible removes the newline after a block tag (`trim_blocks`), so tags on their own line leave
**no blank lines** in the result - provided the tag starts in column 0: `lstrip_blocks` is off,
and an indented tag leaves its spaces behind. Keep block tags at the start of the line, as above,
or write `#jinja2: lstrip_blocks: True` as the first line of the template. Everything else,
including trailing spaces, is copied as it stands. `ansible_managed | comment` turns the text
"Ansible managed" into a comment block at the top, so the next administrator knows not to edit
by hand. Use it in configuration files and not in text people are meant to read, such as login
messages: there it is noise, and in a file format without comments it breaks the file.

A template must be **deterministic**, or the second run reports `changed`: no timestamps and no
random values, and iterate over dictionaries and sets in a fixed order (`dictsort`, `sort`),
because the order of keys can change when variables are merged or moved between layers.
`--check --diff` renders the new content and shows the difference line by line - run it before
the real run (L02), and again after: a clean `--diff` is the proof of idempotency.

### Where variables come from

The same name can be defined in many places, and one value wins. Simplified, from weakest to
strongest:

| Layer | Where |
|---|---|
| role defaults | `defaults/main.yml` of a role (L07) |
| inventory group | `group_vars/all.yml`, then `group_vars/<group>.yml` - the more specific group wins |
| inventory host | `host_vars/<host>.yml` |
| play and task | `vars:` of the play, then of the task |
| command line | `-e name=value` - beats everything |

The complete list has many more levels; this one is enough for the exercises. Define a value
at the weakest layer that is correct for everyone, and override it at the narrowest layer that
needs a different one. `ansible-inventory --host <name>` prints the **inventory layers** for one
host; play variables and `-e` are not in it. The lab's `group_vars/all.yml` defines
`lab_in_container` and `lab_org_name`. See what each layer does:

```yaml
- name: One variable, several layers
  hosts: alpine
  gather_facts: false
  tasks:
    - name: Inventory value
      ansible.builtin.debug:
        var: lab_org_name
    - name: Task variable wins over the inventory
      ansible.builtin.debug:
        var: lab_org_name
      vars:
        lab_org_name: from the task
```

Run it as it is, then with `-e lab_org_name=from-the-command-line` and watch both lines change.
Because the inventory has one group per OS family (`debian_family`, `redhat_family`, ...), a file
`group_vars/<family>_family.yml` holds data for exactly one family - the mechanism behind
data-driven roles.

## CIS background

The recommendations behind these exercises differ in kind. Permissions of the files that hold
password hashes (7.1) have a right answer *per distribution*; the SSH server section (5.1) is
one recommendation with many parameters; the login warning banners (1.6) are one text that must
appear in several files. All three are Level 1 in [the control catalogue](../../cis/controls.yml)
and all are "one decision, many places": the *intent* is common, the concrete path, group or
value is not.

The cost of abstraction is indirection: a dictionary and a template are harder to read than a
single `lineinfile`. Switch when the same difference shows up in a second task or a third family
appears. Exceptions are data too: a host that must deviate gets a different value at a narrower
variable layer instead of a patched task (L11).

## Platform differences

| os_family | Hosts | Inventory group | SSH daemon unit | `distribution` fact |
|---|---|---|---|---|
| Debian | debian, ubuntu | `debian_family` | `ssh` | Debian, Ubuntu |
| RedHat | rocky, alma, fedora | `redhat_family` | `sshd` | Rocky, AlmaLinux, Fedora |
| Suse | opensuse | `suse_family` | `sshd` | openSUSE Leap |
| Alpine | alpine | `alpine_family` | `sshd` | Alpine |
| Archlinux | arch | `arch_family` | `sshd` | Archlinux |

`os_family` is the coarse key dictionaries use; `distribution` tells members of a family apart
when one differs (fedora has a newer package manager than rocky). Do not key a dictionary on the
host name: that is inventory data, not a platform property.

### In the lab containers

- Facts are collected as on a VM, but a play that gathers facts needs Python on the target;
  alpine has it only after exercise 0.02.
- `/tmp` is the container's own, so the scratch directories in this lesson are private to each
  host and disappear on `./lab.sh reset <host>` (`.\lab.ps1 reset <host>` on Windows).
- The inventory defines one group per family and the lab-wide variables in `group_vars/all.yml`;
  the exercises read `lab_org_name` from there.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `object of type 'dict' has no attribute 'Arch'` | dictionary key spelled differently from the fact value | use the fact values `Debian`, `RedHat`, `Suse`, `Alpine`, `Archlinux` |
| A new distribution silently gets a wrong value | a blanket `default` hides the missing key | no default for security values - fail and add the row |
| `object of type 'dict' has no attribute 'path'` in the follow-up loop | the loop runs over `probe.results`, so `item` is a result, not a path | the original value is `item.item`; the data is `item.stat` |
| Output of a nested or included loop is wrong | the inner `item` shadows the outer one | name the variable: `loop_control: {loop_var: path}` |
| `Conditionals must have a boolean result` | `when` yields a string, number or list | compare explicitly: `== 'yes'`, `\| length > 0` |
| Deprecation warning for `when: "{{ x }}"` | `when` is already an expression | write `when: x` without braces |
| Stray spaces in the rendered file, shifted lines | block tags are indented, and `lstrip_blocks` is off | start block tags in column 0, or add `#jinja2: lstrip_blocks: True`; check with `--diff` |
| `changed` on every run of a `template` task | timestamp, random value or unordered iteration in the template | remove it, or sort (`dictsort`, `sort`) |
| `'x' is undefined` only on some hosts | the variable is defined at a group layer those hosts are not in | define it at `all` or add `default` where truly optional |
| The value you set in `group_vars` is not used | a narrower layer (`host_vars`, play `vars`, `-e`) overrides it | look for the name in the stronger layers; `ansible-inventory --host` for the inventory part |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [2.01](../../exercises/stage2-building-blocks/2.01-shadow-permissions-per-family/README.md) | dictionary keyed by `os_family`, missing keys, registered loop results, acting on what exists |
| [2.02](../../exercises/stage2-building-blocks/2.02-sshd-template/README.md) | `template` with variables, `for`, `join`, `ansible_managed`, deterministic output, `--diff` |
| [2.06](../../exercises/stage2-building-blocks/2.06-banners-template-loop/README.md) | one template in a loop, inventory variables and their precedence, when `ansible_managed` does not belong |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A colleague replaces five `when: ansible_facts.os_family == ...` tasks by one task with a
   dictionary. When is that not an improvement?

   <details><summary>Answer</summary>

   When the *steps* differ, not just a value: a task that exists on one family only, or a
   different module per family. A condition says that more clearly than a dictionary of
   module names. Values (names, modes, paths) go into data, steps go into conditions.

   </details>

2. A dictionary lookup fails on a host with `has no attribute`. Name two fixes and say when each
   is wrong.

   <details><summary>Answer</summary>

   Add the missing key, or give the lookup a `default`. The default is wrong for a security
   value, because a new family would silently receive a guess. Adding the row is wrong if the
   family should not be supported at all: then the failure is the intended result.

   </details>

3. After `stat` with `loop` and `register: probe`, a second loop runs over `probe.results`. What
   is `item.item`, what is `item.stat`, and how do you run the second loop on existing files only?

   <details><summary>Answer</summary>

   `item.item` is the original loop item of the `stat` task, `item.stat` its result. Filter the
   list with `probe.results | selectattr('stat.exists') | list`, or put `when: item.stat.exists`
   on the task; the filter keeps skipped items out of the output, the condition lists them as
   skipped.

   </details>

4. `{{ x }}` yields `8` in one task and `"8"` in another. What decides the type?

   <details><summary>Answer</summary>

   A result that consists of a single expression keeps its type (a number stays a number); text
   mixed with an expression, such as `"{{ x }} items"`, is always a string. A value you quoted in
   YAML (`"0640"`) is a string from the start, which is why modes are quoted.

   </details>

5. A play that applies a template reports `changed=1` on every run although no variable
   changed. What do you look for?

   <details><summary>Answer</summary>

   Something in the *rendered text* that differs between runs: a date or time, a random value,
   or iteration in a changing order (merged dictionaries, sets). Remove it or sort it with
   `dictsort` or `sort`. `--check --diff` shows the differing lines.

   </details>

6. `group_vars/all.yml` sets `site: A`, `host_vars/web1.yml` sets `site: B`, the play has `vars:
   site: C`, and you run with `-e site=D`. What does `web1` see, and how do you inspect the
   inventory part?

   <details><summary>Answer</summary>

   `D`: the command line beats everything, then the play vars (`C`), then the host layer (`B`)
   and last the group layer (`A`). `ansible-inventory --host web1` shows only the inventory
   layers (`B`); play variables and `-e` are not part of it.

   </details>

7. Why does a login banner not get `{{ ansible_managed | comment }}` while an sshd drop-in does?

   <details><summary>Answer</summary>

   The comment is for the next administrator reading a configuration file. In a banner every
   user who logs in sees it: noise, and a hint about how the host is managed. A configuration
   file wants it, as long as the format has comments.

   </details>

## Further reading

- [Templating (Jinja2)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html) and [filters](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html) in the Ansible guide
- [Loops](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_loops.html) - `loop_control`, `dict2items`, registering a loop
- [Using variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html) - the full precedence list
- [`ansible.builtin.template`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)
- [Jinja template designer documentation](https://jinja.palletsprojects.com/en/stable/templates/) - `for`, `if`, whitespace control
- [Glossary](../GLOSSARY.md) - terms of this lesson: `group_vars` / `host_vars`, Jinja2, loop,
  platform data, template, variable precedence
