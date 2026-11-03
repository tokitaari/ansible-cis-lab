# L02 - Safe changes: check mode, validate, handlers and conditionals

*[Deutsch](L02-safe-changes.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 1.01, 1.02, 1.03, 1.04, 1.05 | 2.1, 2.2, 5.1, 5.2, 7.1 | ~25 min | L00 |

A hardening change that runs on eight hosts at once can break eight hosts at once: a wrong
mode on a system file, a typo in a service configuration, a restart that never happens. This
lesson is about changes you can predict before you make them, check before they take effect,
and undo when they go wrong - the habits that separate a hardening playbook from a hardening
accident.

## Learning goals

After this lesson you can ...

- [ ] predict what `--check --diff` reports for a task, and name the cases where it cannot know
- [ ] decide which tasks must still run in check mode and which output must stay out of the diff
- [ ] explain what `validate` proves about a file and what it does not
- [ ] choose between running a handler at the end of the play, now, or even after a failure
- [ ] write a condition that skips a host that does not need a change instead of failing it
- [ ] order a risky change so that a mistake costs one host, not all of them

## Theory

### Check mode: what it can and cannot predict

L00 introduced `--check --diff`. The mechanism deserves a closer look because hardening work
depends on it. In check mode every module is asked what it *would* do. Modules such as
`file`, `copy`, `template`, `package` and `service` compare the current state with the
requested one and answer without touching the host. A module that cannot predict its effect -
`command`, `shell`, `raw` unless `creates`/`removes` is given - is **skipped**.

A skipped task does not fail. It still produces a registered result, but one without output,
and that is the trap:

```yaml
- name: Read-only probes in check mode
  hosts: targets
  become: true
  tasks:
    - name: Read the kernel release
      ansible.builtin.command: uname -r
      register: kernel
      changed_when: false
    - name: Report it
      ansible.builtin.debug:
        msg: "kernel {{ kernel.stdout }}, dry run: {{ ansible_check_mode }}"
```

Run with `--check`, this prints `kernel , dry run: True`: the first task was skipped, so
`kernel.stdout` is empty. Nothing failed, the answer is simply wrong. A task that only *reads*
is safe to run for real, so you tell Ansible to do so with `check_mode: false` on that task.
`ansible_check_mode` is the variable that tells a task whether the run is a dry run.

The opposite keyword, `check_mode: true`, makes a single task run in check mode even in a
normal run - a cheap way to ask "would this change anything?" without acting on it.

`--diff` shows the difference a module computes: file content, permissions, state. A file that
holds a secret must not appear there, because the diff goes to the terminal, to CI logs and to
chat. Switch it off per task:

```yaml
- name: Hide file contents from the diff
  hosts: targets
  become: true
  tasks:
    - name: Token file is in place
      ansible.builtin.copy:
        dest: /etc/lab-token
        content: "s3cret\n"
        mode: "0600"
      diff: false
```

Limits to keep in mind: check mode predicts one task at a time. If a later task depends on the
*result* of an earlier one (a file that the earlier task would have created, a package it would
have installed), the dry run can show an error or a "changed" that the real run would not
produce. A clean `--check` is strong evidence, not a proof; the proof is the real run followed
by a second run with `changed=0`.

```bash
ansible-playbook change.yml --check --diff          # what would change, and how?
ansible-playbook change.yml --check --diff -l debian   # the same, for one host
```

### `validate`: test the file before it exists

Some files are dangerous because the program that reads them refuses to start on an error: a
daemon configuration, a sudo rule, a PAM file. If your change installs a broken file and a
handler then restarts the daemon, the service is down - and if the service is how you reach the
host, so are you.

The modules that write files (`copy`, `template`, `lineinfile`, `blockinfile`) accept
`validate`. Ansible writes the new content to a **temporary file**, runs your command with
that file's path in place of `%s`, and installs the file only if the command exits with 0:

```yaml
- name: Install a script only if it parses
  hosts: targets
  become: true
  tasks:
    - name: Helper script is valid shell
      ansible.builtin.copy:
        dest: /etc/lab-helper.sh
        content: |
          #!/bin/sh
          echo "hello"
        owner: root
        group: root
        mode: "0755"
        validate: /bin/sh -n %s
```

`sh -n` reads a script and reports syntax errors without running it. Break the script (an `if`
without `fi`) and the task fails with `failed to validate` and the shell's message; the file
on the host is untouched. Leave out `%s` and the module refuses to run at all.

What `validate` proves is narrow: **the new file is syntactically acceptable to the checker,
read on its own.** It does not prove that the file wins over other files that configure the
same program, that the setting does what you meant, or that the service keeps running after a
restart. Configuration that is assembled from several files, with rules about which setting
counts, needs a second check of the *effective* result - most daemons can print it. Many
programs have a test mode for exactly this purpose; finding the right call is part of the
exercises.

The checker runs on the target as the `become` user, without a shell: no pipes, no `&&`, no
variable expansion in the command line itself. If you need those, put them into a small script
and validate with the script.

### Handlers: act only when something changed

Restarting a service on every run is noisy and sometimes harmful - connections drop for no
reason. A **handler** is a task that runs only if some task reported `changed` and named it
with `notify`:

```yaml
- name: Handlers run once, at the end of the play
  hosts: targets
  become: true
  tasks:
    - name: First setting changes
      ansible.builtin.copy:
        dest: /etc/lab-a.conf
        content: "a=1\n"
        mode: "0644"
      notify: Announce change
    - name: Second setting changes
      ansible.builtin.copy:
        dest: /etc/lab-b.conf
        content: "b=1\n"
        mode: "0644"
      notify: Announce change
    - name: Run pending handlers now
      ansible.builtin.meta: flush_handlers
    - name: Runs after the handler
      ansible.builtin.debug:
        msg: "handlers are done"
  handlers:
    - name: Announce change
      ansible.builtin.debug:
        msg: "a config file changed"
```

Both tasks notify the same handler, and it runs **once**. Without the `flush_handlers` line it
would run after the last task of the play, not in the middle. That matters whenever a later
task depends on the effect of the handler: a check that connects to the restarted service
must come after the flush, not before. On a second run nothing changes, so the handler does
not run at all.

Three properties cause most surprises:

- **Handler names are global** for the play and matched by exact text. A typo in `notify`
  fails the run with "handler not found". With `listen: <topic>` in the handler, tasks notify
  the topic instead, and several handlers can share it.
- **A failed task skips the handlers.** The change that was already made stays on the host, and
  the *next* run reports `ok` for it - so the handler that should have followed never runs.
  The service keeps running on the old configuration until someone notices. `force_handlers:
  true` on the play runs the notified handlers even after a failure.
- **Handlers also run in check mode**, and their modules are again only asked what they would
  do. A dry run therefore shows where a restart *would* happen.

```yaml
- name: Handlers after a failed task
  hosts: targets
  become: true
  force_handlers: true
  tasks:
    - name: Setting changes
      ansible.builtin.copy:
        dest: /etc/lab-a.conf
        content: "a=2\n"
        mode: "0644"
      notify: config changed
    - name: A later task fails
      ansible.builtin.command: "false"
      changed_when: false
  handlers:
    - name: Announce change
      listen: config changed
      ansible.builtin.debug:
        msg: "handler ran despite the failure"
```

`restarted` and `reloaded` are different promises: a reload asks the running process to read
its configuration again, a restart stops it and starts a new one. Which one is right depends on
what the daemon supports and what an interruption costs; the exercises make you decide.

### Conditionals: skip what does not apply

A play for `targets` runs on eight different systems. A task for a service that only some
hosts have must not fail on the others: "not installed" is a normal outcome, not an error.
`when` takes a Jinja2 expression, written **without** `{{ }}`, and skips the task if it is
false.

Two ways to know what is installed. `package_facts` collects the installed packages into
`ansible_facts.packages`, a dictionary keyed by package name:

```yaml
- name: Act only where the package exists
  hosts: targets
  become: true
  tasks:
    - name: Collect installed packages
      ansible.builtin.package_facts:
        manager: auto
    - name: Report the sudo version
      ansible.builtin.debug:
        msg: "sudo {{ ansible_facts.packages['sudo'][0].version }}"
      when: "'sudo' in ansible_facts.packages"
    - name: Report a package nobody installs
      ansible.builtin.debug:
        msg: "found it"
      when: "'lab-no-such-package' in ansible_facts.packages"
```

The second task is skipped on every host. Quote the whole `when` here: a plain scalar that
contains `': '` or starts with a quote confuses the YAML parser. For a file or directory, `stat`
plus `register` and `when: result.stat.exists` is the equivalent.

The other tool is judging a command by its outcome. A command that reports "nothing found" with
exit code 1 and a real error with exit code 2 is not a failure in the first case:

```yaml
- name: Judge a command by its exit code
  hosts: targets
  become: true
  tasks:
    - name: Look for a marker in a file
      ansible.builtin.command: grep -q marker /etc/hostname
      register: probe
      changed_when: false
      failed_when: probe.rc > 1
    - name: React to the result
      ansible.builtin.debug:
        msg: "marker present: {{ probe.rc == 0 }}"
```

`failed_when` replaces Ansible's own idea of failure (non-zero exit code) with yours, and
`changed_when` does the same for `changed`. Compare this with `ignore_errors: true`, which
keeps the play going after *any* failure, including the ones you did not expect. Prefer a
precise condition over blanket silence; a hardening playbook that ignores errors reports
compliance it does not have.

### A way back: order the risk

Even with `validate` and a good handler, some changes can only be judged on the real system.
The cheap protection is to widen the blast radius in steps:

```bash
ansible-playbook change.yml --check --diff -l debian   # look at one host
ansible-playbook change.yml -l debian                  # change one host
ansible targets -m ansible.builtin.ping                # can we still reach everything?
ansible-playbook change.yml --step -l ubuntu           # ask before every task
ansible-playbook change.yml                            # everyone
```

`--step` asks for confirmation before each task - slow, but right for a change you do not yet
trust. Keep a second connection to a test host open while you work, so that a lock-out leaves
you an open session. Lesson L14 covers the planned version of this idea (`serial`, canary
hosts).

For a change with a clear success test, `backup: true` on `copy`/`template` keeps the previous
file, and `block`/`rescue` runs recovery tasks when something in the block fails:

```yaml
- name: Change with a way back
  hosts: targets
  become: true
  tasks:
    - name: Apply the setting, restore the old file if the check fails
      block:
        - name: Install new settings
          ansible.builtin.copy:
            dest: /etc/lab-settings.conf
            content: "mode=relaxed\n"
            mode: "0644"
            backup: true
          register: new_settings
        - name: Verify the setting
          ansible.builtin.command: grep -qx 'mode=strict' /etc/lab-settings.conf
          changed_when: false
      rescue:
        - name: Put the previous file back
          ansible.builtin.copy:
            src: "{{ new_settings.backup_file }}"
            dest: /etc/lab-settings.conf
            remote_src: true
            mode: "0644"
          when: new_settings.backup_file is defined
        - name: Stop and say why
          ansible.builtin.fail:
            msg: "verification failed on {{ inventory_hostname }}"
```

The verification fails on purpose here (the file says `relaxed`), so the rescue restores the old
file where one existed and then fails the host visibly. `backup_file` exists only if there was
a previous file to back up - hence the `when`. The `rescue` section is not a license to be
careless: it covers the failures you thought of.

## CIS background

Services and clients are attack surface, and the recommendations in sections 2.1 (server
services) and 2.2 (client services) are mostly "remove it, or at least stop and disable it".
These changes are low risk per host, but the *conditional* matters: the same play meets hosts
that have the package and hosts that do not (control 2.1 and 2.2 in
[the control catalogue](../../cis/controls.yml)).

Section 5.1 (SSH server) and 5.2 (privilege escalation) are the controls that can lock you
out: both configure the programs through which you manage the host. They are Level 1 and
should be applied everywhere, so the safeguards in this lesson are not optional for them.
Section 7.1 (system file permissions) is cheap to fix and easy to get wrong - a mode that is
too strict can break a service as surely as one that is too loose.

In production the trade-off is speed against certainty. Running `--check --diff` first, in a
change window, on one host, costs minutes; a lock-out costs a trip to the console.

## Platform differences

| os_family | Hosts | sshd service name | Init system | `package_facts` backend |
|---|---|---|---|---|
| Debian | debian, ubuntu | `ssh` | systemd | apt |
| RedHat | rocky, alma, fedora | `sshd` | systemd | rpm |
| Suse | opensuse | `sshd` | systemd | rpm |
| Alpine | alpine | `sshd` | openrc | apk |
| Archlinux | arch | `sshd` | systemd | pacman |

`ansible.builtin.service` hides the init system, but not the service *name*: the same daemon
is called differently across families, which is why a handler that restarts it needs the right
name per host. How to handle names as data is the topic of L04.

### In the lab containers

- `package_facts` with `manager: auto` needs the matching Python bindings on the target (for
  apt and rpm). The lab images ship them; Alpine uses the `apk` command and needs none beyond
  the Python that exercise 0.02 installs.
- Services run under a real init system (systemd, OpenRC), so `service` and handlers behave as
  on a VM. Hosts without the package or service simply do not have the unit: that is what the
  conditionals are for.
- `lab check` runs your playbook twice and expects `changed=0` the second time; a handler that
  runs on the second run points to a task that is not idempotent.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| A value is empty in a `--check` run, nothing failed | the task that produces it is `command`/`shell`, skipped in check mode | `check_mode: false` on read-only tasks |
| `validate must contain %s` | the command has no `%s` placeholder | put `%s` where the file path belongs |
| `validate` passes, but the program still behaves wrongly | `validate` checks the file alone, not the effective configuration | verify the effective result after the change |
| The service never picked up the new configuration | a later task failed, the handler was skipped, the next run reports `ok` | `force_handlers: true`, or put risky tasks after the handler flush |
| A check right after the change runs against the old service | the handler has not run yet, it waits for the end of the play | `ansible.builtin.meta: flush_handlers` before the check |
| "The requested handler was not found" | the `notify` text differs from the handler `name` | copy the exact name, or use `listen` with a topic |
| A `when` with `{{ var }}` triggers a deprecation warning | `when` is already a Jinja2 expression | write `when: var`, no braces |
| `ansible_facts.packages` is undefined | `package_facts` has not run for this host in this play | run `package_facts` first, in the same play or earlier |
| A real failure never shows up in the recap | `ignore_errors: true` swallows it | use `failed_when` with the exit codes that are acceptable |
| The diff shows a password | `--diff` prints file content | `diff: false` on that task |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [1.01](../../exercises/stage1-beginner/1.01-remove-telnet/README.md) | what `--check --diff` shows for a package that may not exist; skipped versus failed |
| [1.02](../../exercises/stage1-beginner/1.02-passwd-group-permissions/README.md) | reading a permission diff; quoted modes; why a missing file needs thought |
| [1.03](../../exercises/stage1-beginner/1.03-ssh-root-login/README.md) | `validate`, `notify` and handlers, the limits of `validate`, a change that can lock you out |
| [1.04](../../exercises/stage1-beginner/1.04-disable-ftp-server/README.md) | `package_facts` with `when`, one task for systemd and OpenRC, skipped hosts |
| [1.05](../../exercises/stage1-beginner/1.05-sudo-hardening/README.md) | `validate` as lock-out prevention, ordering a risky change |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A `--check` run of your playbook shows `changed=0` on a host that is not compliant. Name two
   possible reasons.

   <details><summary>Answer</summary>

   A task that would make the change is skipped in check mode (`command`/`shell`/`raw` without
   `creates` or `removes`), or a later task depends on the result of an earlier one that was
   only predicted, so the dry run cannot see the difference. A third possibility is a `when`
   that reads a registered value from a skipped task. A clean check is evidence; the second real
   run with `changed=0` is the test.

   </details>

2. `validate` succeeds for your new daemon configuration, you restart the daemon through a
   handler, and the service does not come back. How is that possible?

   <details><summary>Answer</summary>

   `validate` tests the temporary file on its own: syntax and values that the checker
   accepts. It cannot know that another file overrides the setting, that a value is valid but
   wrong for this system (a port that is taken, a path that does not exist), or that the
   running service differs from what the checker assumes. Verify the effective configuration
   and the service itself after the change, and keep a way back.

   </details>

3. Two tasks notify the same handler. Task 2 fails. What happens to the handler, and what does
   the next run report?

   <details><summary>Answer</summary>

   Without `force_handlers`, the handler does not run, because the play stopped. Task 1's change
   is already on the host, so the next run reports it as `ok`, no notification happens and the
   handler never runs for that change. With `force_handlers: true` it runs after the failure.

   </details>

4. When do you need `meta: flush_handlers` instead of waiting for the end of the play?

   <details><summary>Answer</summary>

   Whenever a later task in the same play depends on the effect of the handler: a connection
   test against the restarted service, a verification of the running configuration, or a task
   that must not run against the old service. Without the flush the handler runs after the
   last task, too late for those.

   </details>

5. A play for `targets` removes a service, but fails on two hosts with "Could not find the
   requested service". What is wrong, and what do you check for before the task?

   <details><summary>Answer</summary>

   The service module does not find a unit on hosts where the package is not installed, and that
   is reported as a failure. The condition belongs on the task: run `package_facts` and use
   `when` on the package name, so that hosts without it are skipped. "Not installed" is a normal
   state, not an error.

   </details>

6. You have to apply a risky change to eight hosts and you cannot test it elsewhere. Which
   sequence limits the damage?

   <details><summary>Answer</summary>

   `--check --diff` on one host, the real change on that host, a connectivity test of the whole
   group, then the next hosts or the rest. `--step` and `backup: true` with `block`/`rescue` help
   for a change you trust less, and a second open session keeps you from being locked out.
   Planned rollouts with `serial` and canary hosts follow in L14.

   </details>

## Further reading

- [Validating tasks: check mode and diff mode](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html)
- [Handlers: running operations on change](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html)
- [Conditionals](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_conditionals.html)
- [Blocks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html) and [Error handling in playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_error_handling.html)
- [`ansible.builtin.copy`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html) - `validate` and `backup`
- [`ansible.builtin.package_facts`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/package_facts_module.html)
