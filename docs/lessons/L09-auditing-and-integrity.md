# L09 - Auditing and integrity: auditd, AIDE and long-running tasks

*[Deutsch](L09-auditing-and-integrity.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 3.04, 4.08 | 6.1, 6.3 | ~35 min | L02, L04, L07 |

Prevention fails sooner or later, and then two questions decide how bad it gets: what happened,
and what has been changed? The kernel's audit framework answers the first, a file integrity
checker such as AIDE the second. Both are cheap to configure and expensive to run: they write a
lot, they scan a lot, and they need a process around them. This lesson covers the audit
subsystem and its rule files, what happens when the log fills the disk, how an integrity
database works, and the Ansible mechanism that keeps a scan of several minutes from blocking a
play: background tasks.

## Learning goals

After this lesson you can ...

- [ ] explain why the audit subsystem belongs to the host kernel and what that means for a play that touches it
- [ ] read a watch rule and a syscall rule and say what a key, `auid` and `unset` are
- [ ] say how files in `rules.d` become the rule set, in which order, and what `-e 2` changes for automation
- [ ] name what `auditd.conf` can do when a log file is full, when space runs low and when the disk is full, and the trade-off
- [ ] explain what an AIDE database holds, why a check compares hashes, and read the exit code of a check
- [ ] say why a baseline needs a process: patching, review, and where the database lives
- [ ] predict what `poll: 0` returns, where the failure of a background job shows up, and when `async` helps at all
- [ ] explain why `poll: 0` together with `creates` reports `changed` on every run

## Theory

### The audit subsystem: kernel records, daemon stores

A log written by an ordinary program is weak evidence: whoever can change the program can change
its log. The Linux **audit framework** moves the recording into the kernel. A rule tells the
kernel which events to record; for each match the kernel sends a record to the daemon `auditd`,
which appends it to a log file (`/var/log/audit/audit.log` is the `log_file` default on all
eight lab hosts). Rules are loaded into the kernel with `auditctl`; the daemon only receives and
stores.

The framework is **not namespaced**: a kernel has one rule set, and a container runs on the
host's kernel. A play that loads rules or starts `auditd` inside a container therefore changes
the host (see [the container limits](../CONTAINER_LIMITS.md)), which is why the catalogue marks
auditd `container: config` (L01): write the configuration, activate nothing. After the package
was installed, a status query (`auditctl -s`) from inside a target failed on all eight hosts
here: `Operation not permitted` on four of them (audit 4.0.x), `There was an error while
processing parameters` on the other four (4.1 and newer). I did not look for the reasons.

Rules come in three kinds (`audit.rules(7)`):

```
-D
-w /etc/motd -p wa -k banner_demo
-a always,exit -F arch=b64 -S unlink,unlinkat -F auid>=1000 -F auid!=unset -k delete_demo
```

- A **control** rule configures the audit system instead of watching: `-D` deletes all loaded
  rules, `-b` sets the kernel's backlog, `-f` the failure mode, `-e` the enabled flag. They stand
  at the top of a rule set (`-e` at the end, see below).
- A **watch** (`-w path -p perms -k key`) records access to a file: `r` read, `w` write, `x`
  execute, `a` attribute change. A directory is watched recursively, but the watch stops at
  mount points.
- A **syscall rule** (`-a action,list -S syscall -F field=value -k key`) is matched against
  every system call of every program, so the manual advises syscall rules only when you have
  to, and several syscalls in one rule. `always,exit` means "record when the call
  returns". On machines with two syscall ABIs the numbers can differ, so such a rule is written
  once per `arch` (`b32`, `b64`).

A **key** is free text attached to every record the rule produces. `ausearch -k <key>` and
`aureport --key --summary` select by it, so a good key answers one question ("who touched this
file?") and the log becomes searchable; the manual recommends a key on every rule.

`auid` is the **audit user id**, also called *loginuid*: the id a person logged in with, set once
per login by the PAM module `pam_loginuid` in entry-point services such as `login`, `sshd` or
`crond`. Its manual says it should not be used by `sudo` or `su`, because that would replace the
id with the account just switched to. An unset value is `unset`, the same as -1, and prints as
4294967295 - which is why a rule that selects real users says `-F auid>=1000 -F auid!=unset`:
the unset value is a huge unsigned number and passes the first test.

```yaml
- name: Who are you, as far as the kernel knows?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Compare the effective user with the login user
      ansible.builtin.command: sh -c 'echo "uid=$(id -u) loginuid=$(cat /proc/self/loginuid)"'
      register: who
      changed_when: false
      check_mode: false
    - name: Show both numbers
      ansible.builtin.debug:
        msg: "{{ who.stdout }}"
```

The play reads `/proc/self/loginuid`, which needs no package. On the seven systemd hosts it
prints `uid=0` and the id of the account Ansible logged in with (1000, on ubuntu 1001); on
alpine `loginuid=4294967295`. L08 found no `UsePAM` line in alpine's `sshd_config`; I did not
check why its login leaves the value unset. Run it without `become` and the first number
changes while the second does not.

### Rule files, load order and the lock

Rule sets are kept as files. Every file in `/etc/audit/rules.d` whose name ends in `.rules` is a
component; `augenrules` merges them in natural sort order (`ls -v`, so `100-` comes after `60-`),
drops comments and empty lines and writes the result to `/etc/audit/audit.rules`
(`augenrules(8)`). Files with another ending are ignored. The manual adds three rules about
position: the last `-D` without an option is emitted first, then the last `-b` and `-f`, and
**the last `-e` is always emitted as the last line**. I tested it with audit 3.1.2: an `-e 2`
in a file named `05-early.rules` ended up last in `audit.rules`, after the rules of `100-late.rules`;
a `*.conf` file in the directory was ignored. The same test showed a trap for scripts:
`augenrules --check` prints `Rules have changed and should be updated` or `No change`, but its
exit code is 0 either way (audit 3.1.2; other versions not tested), so a task has to read the
text.

Two states have to be told apart. The files are *configuration*; the *loaded* rules live in the
kernel. Writing a file audits nothing: `augenrules --load` (or the service's start, below)
sends the merged set to the kernel, and `auditctl -l` lists what is loaded. Which unit does the
loading depends on the version. On the seven systemd hosts of the lab (audit 4.0 and newer) a
second unit `audit-rules.service` exists next to `auditd.service`; on opensuse `auditd.service`
still has `ExecStartPost=-/sbin/augenrules --load`. `systemctl cat` shows what a host does.
The packages ship different starting points, too: debian, ubuntu, rocky and alma ship a
`rules.d/audit.rules` with `-D`, `-b 8192`, `--backlog_wait_time 60000` and `-f 1`; fedora and
opensuse ship `-D` and `-a task,never`; on alpine and arch the directory is empty.

The enabled flag has three values (`auditctl(8)`): `-e 0` disables auditing, `-e 1` enables it,
`-e 2` **locks** the configuration. A locked configuration refuses every change, the attempt is
audited, and only a reboot lifts the lock. That is the point (an attacker with root cannot
simply delete the rules) and a cost for automation: a mistake in a locked rule set is fixed
with a reboot, and a play that wants to change rules on a host that has been running locked
cannot do it. Test the rules unlocked, lock only the final set, and plan the reboot.

#### When the log grows: `auditd.conf`

Audit logs are written without limit until somebody sets one, and a full disk is a bad moment
to decide what the daemon should do. `/etc/audit/auditd.conf` is a `key = value` file
(`auditd.conf(5)`) with three stages:

| Stage | Setting | The daemon can ... |
|---|---|---|
| a log file reached its size | `max_log_file` (MB), `max_log_file_action` | `ignore`, `syslog`, `suspend`, `rotate` (keep `num_logs` files, the oldest is overwritten), `keep_logs` (like `rotate`, but nothing is ever deleted) |
| space is getting low | `space_left`, `space_left_action` | `ignore`, `syslog`, `rotate`, `email`, `exec <script>`, `suspend`, `single`, `halt` |
| last chance before the disk is full | `admin_space_left` (the smaller number), `admin_space_left_action` | the same list |
| disk full or write error | `disk_full_action`, `disk_error_action` | `ignore`, `syslog`, `exec`, `suspend`, `single`, `halt` (`rotate` for a full disk) |

`email` sends a message to `action_mail_acct` and to syslog and needs a mail system (the manual
says `/usr/lib/sendmail` must exist). `suspend` keeps the daemon alive but stops writing - the
audit log has a gap. `single` and `halt` stop the machine: no events are lost, and neither is
availability spared. `keep_logs` loses nothing by itself, but it makes the disk fill and so
triggers the next stage; the manual calls it best combined with a script that archives logs.

The shipped defaults are identical on all eight lab hosts (and on the Ubuntu 24.04 host I tested
with): 8 MB per file, `rotate` with 5 files, a `syslog` warning at 75 MB free, `suspend` at 50
MB free and on a full disk or write error. They never take the machine down, and they lose
records: `rotate` overwrites the oldest file and `suspend` leaves a gap. A hardened setting picks
which of the two failures you accept - audit completeness or availability - and the choice
belongs in the exception list of L01, not in a comment.

### AIDE: baseline, check, update

Audit records say who did something. They do not say whether the binary in `/usr/bin` is still
the one the package shipped. **AIDE** (Advanced Intrusion Detection Environment) answers that:
it records attributes and hashes of selected files in a **database**, the *baseline*, and a
later **check** compares the file system with it.

What is recorded is chosen in the configuration (`aide.conf(5)`). A **rule** is a named set of
attributes, built with `+` and `-`; `p` is permissions, `u` owner, `g` group, `s` size, `m`
mtime, and a checksum name such as `sha256` adds the content hash. **Selection lines** attach a
rule to paths: `/path Rule` adds everything whose path matches the regular expression, `!/path`
leaves it out, `=/path` adds only that level (the children of a directory only if the expression ends in `/`). A regular
expression must start with `/` and is anchored at the beginning of the path. Tested with a small
tree: a path excluded with `!` produced no report when it changed, and a file whose content was
changed to the same size, with the old mtime put back, was reported by a rule with `sha256`
and **not** by a rule with only `p+u+g+s+m`. That is why a check compares hashes: size and mtime
are what an attacker restores first.

Three settings name the databases: `database_in` is read by a check and an update,
`database_out` is written by `--init` and `--update`, `database_new` is the second database of
`--compare`. The consequence is a step people forget: `--init` writes `database_out` and
leaves `database_in` alone, so the new database must be **promoted** to the name `database_in`
before the first check can work (`aide(1)`). Debian adds a wrapper, `aideinit`, which builds the
database and offers to replace the old one; the Red Hat family has none.

A check tells its result in the **exit code**, built from three bits: 1 if files were added, 2
if files were removed, 4 if files changed, summed (`aide(1)`). Added and changed is 5, removed and
changed 6. Codes from 14 up are errors; a missing database gave 18 in my test. A caller must
therefore treat 1 to 7 as "differences found", not as "the tool failed", and 0 as the only
clean result. `--update` returns the same codes: it reports the differences *and* writes a new
database, still to `database_out` (tested), which then has to be promoted like the first one.

The mechanism is the easy part; the **process** decides whether it is a control:

- **Review before promoting.** After every patch run the file system differs from the baseline.
  An update promoted without reading the report accepts whatever else changed - an intrusion
  included. A patch workflow gets two steps: check and read, then update and promote.
- **Where the database lives.** An attacker with root on the host can rewrite the files *and*
  the database. A baseline that matters is copied off the host or stored where the watched host
  cannot write. The lab does not do that; a real host should.
- **Cost.** Initialising reads every selected file, so a whole file system takes minutes, in
  proportion to its size. Selection lines should leave volatile paths out (logs, caches); a
  report full of expected changes is read by nobody.

A check that nobody starts protects nothing, so it runs on a schedule. On a systemd host a
schedule is **two units**: a *timer* that says when and a *service* that says what. The timer
carries `OnCalendar=` (a calendar expression, `systemd.time(7)`), `Persistent=true` (the time of
the last run is kept on disk, and a run that was missed while the host was off happens at the
next start) and often `RandomizedDelaySec=` (a random delay so that many hosts do not start at
the same moment). The service is of `Type=oneshot`: it counts as up until its main process
exits and is then simply dead, which is right for a check that runs and ends
(`systemd.timer(5)`, `systemd.service(5)`). systemd keeps unit files in memory, so a unit that
changed on disk is only seen after `systemctl daemon-reload`. A calendar expression is easy to
get wrong and cheap to test, because `systemd-analyze` evaluates it without any unit:

```yaml
- name: When would a timer with this expression fire?
  hosts: targets:!alpine
  gather_facts: false
  tasks:
    - name: Evaluate a calendar expression
      ansible.builtin.command: systemd-analyze calendar '*-*-* 05:30:00' --iterations=3
      register: calendar
      changed_when: false
      check_mode: false
    - name: Show the next three runs
      ansible.builtin.debug:
        var: calendar.stdout_lines
```

The shipped packages differ: Debian and Ubuntu install `dailyaidecheck.timer` and a matching
service (debian 13 and ubuntu 26.04 also `dailyaidecheck-buildcache.service`); the Red Hat
family ships no timer and no cron file, only a logrotate file (a search of the package's
`systemd/system`, `/etc/cron*` and `/etc/default` files found none).

This play builds a baseline on a tiny tree with its own configuration, so it runs in seconds
and leaves the host's AIDE alone. It installs AIDE on the five hosts of 4.08, changes a file
**after** the baseline, and checks:

```yaml
- name: Baseline, tamper, check - on a tiny tree
  hosts: debian_family:redhat_family
  become: true
  vars:
    demo: /tmp/lesson09
  tasks:
    - name: Refresh the apt index (the Debian images ship without one)
      ansible.builtin.apt:
        update_cache: true
      changed_when: false
      check_mode: false
      when: ansible_facts.os_family == 'Debian'
    - name: Install AIDE
      ansible.builtin.package:
        name: aide
        state: present
    - name: Create the directories for the files and the database
      ansible.builtin.file:
        path: "{{ demo }}/{{ item }}"
        state: directory
        mode: "0700"
      loop: [data, db]
    - name: Create the watched file once
      ansible.builtin.copy:
        dest: "{{ demo }}/data/app.conf"
        content: "level=1\n"
        force: false
        mode: "0644"
    - name: Write a minimal AIDE configuration
      ansible.builtin.copy:
        dest: "{{ demo }}/aide.conf"
        content: |
          database_in=file:{{ demo }}/db/aide.db
          database_out=file:{{ demo }}/db/aide.db.new
          database_new=file:{{ demo }}/db/aide.db.new
          report_url=stdout
          Hash = p+u+g+s+m+sha256
          {{ demo }}/data Hash
        mode: "0644"
    - name: Build the new database
      ansible.builtin.command:
        cmd: "aide --init --config {{ demo }}/aide.conf"
        creates: "{{ demo }}/db/aide.db.new"
    - name: Promote it to the baseline (never overwrite an existing one)
      ansible.builtin.copy:
        src: "{{ demo }}/db/aide.db.new"
        dest: "{{ demo }}/db/aide.db"
        remote_src: true
        force: false
        mode: "0600"
      when: not ansible_check_mode
    - name: Change the file after the baseline
      ansible.builtin.copy:
        dest: "{{ demo }}/data/app.conf"
        content: "level=9\n"
        mode: "0644"
    - name: Check against the baseline
      ansible.builtin.command: "aide --check --config {{ demo }}/aide.conf"
      register: aide_check
      changed_when: false
      failed_when: aide_check.rc > 7
      check_mode: false
      when: not ansible_check_mode
    - name: Read the result
      ansible.builtin.debug:
        msg:
          rc: "{{ aide_check.rc }}"
          summary: "{{ aide_check.stdout_lines | select('search', '(Added|Removed|Changed) entries') | list }}"
      when: not ansible_check_mode
```

The exit code is 4: one changed file, none added or removed. A second run changes nothing (the
file already says `level=9`) and reports 4 again, because the baseline still says `level=1`.
Under `--check` the promotion and the check are skipped: on a fresh host there is no database yet.
Remove the demo with `rm -rf /tmp/lesson09` (the package stays) or `./lab.sh reset <host>`
(`.\lab.ps1 reset <host>` on Windows).

### Long-running tasks: `async`, `poll` and `async_status`

A normal task holds the connection to its host until the module returns. A scan of minutes
makes that visible: the play waits, the connection must survive the wait, and the host keeps
one of Ansible's parallel slots (`forks`, 10 in the lab's `ansible.cfg`) busy. **Asynchronous
tasks** hand the work to a background process on the target and let the connection go:

- `async: N` is the **time limit** in seconds for the job, not a delay. A job that exceeds it is
  stopped and reported as `Timeout exceeded` (tested).
- `poll: N` with N above zero makes Ansible **wait**: it asks for the state every N seconds,
  keeps the host busy, and the task ends with the job's real result. Hosts still run side by
  side as long as `forks` allows.
- `poll: 0` is **fire and forget**: the task returns as soon as the job is *started*, with a job
  id and `started: true`, and the play moves on. Collecting the result is a separate task,
  `ansible.builtin.async_status`, which asks for the job id and reports `finished: false` until
  it is done. A loop with `until: result.finished`, `retries` and `delay` is the usual way to
  wait.

On the target the job writes its state to a file below the home of the executing user,
`~/.ansible_async/<job id>` (`/root/.ansible_async/...` with `become`), which is what
`async_status` reads. `mode: cleanup` removes it.

```yaml
- name: Start a slow job, then collect it
  hosts: targets
  gather_facts: false
  tasks:
    - name: Start a job that takes a few seconds
      ansible.builtin.command: sh -c 'sleep 5; echo finished > /tmp/lesson09-job.txt'
      async: 60
      poll: 0
      register: slow_job
      changed_when: false
    - name: The play moves on at once
      ansible.builtin.debug:
        msg: "job {{ slow_job.ansible_job_id }} runs in the background, state in {{ slow_job.results_file }}"
    - name: Wait for the job
      ansible.builtin.async_status:
        jid: "{{ slow_job.ansible_job_id }}"
      register: slow_result
      until: slow_result.finished
      retries: 10
      delay: 2
      changed_when: false
    - name: Show the outcome
      ansible.builtin.debug:
        msg: "rc={{ slow_result.rc }} after {{ slow_result.attempts }} attempts"
```

The wait task prints `FAILED - RETRYING` lines while the job runs; they mean "not finished
yet", not an error. Both `changed_when: false` keep the play repeatable: without them, one job
shows up as **two** changes in the recap, because `async_status` copies the job's own `changed`
(tested).

Four properties decide how you write such tasks:

- **A failure is invisible until you collect it.** The start task is `changed` whatever the job
  will do. In a test, a job that exited with 3 left the recap at `failed=0`; the failure
  appeared only when `async_status` read the job (`finished: true`, `failed: true`, `rc: 3`,
  the stderr). A job that nobody collects can fail without any trace in the run.
- **A job outlives the play.** A job started with `poll: 0` and never collected still ran to the
  end after the play had finished (tested). Whatever depends on the result must collect it.
- **Several items, several jobs.** A task with a `loop` and `poll: 0` starts one job per item
  and returns a list; the collecting task loops over `results`.
- **It does not make the job faster.** What the job does takes as long as it takes. With four
  hosts and a 3-second sleep the foreground task needed 3.9 s with `forks=10` and 7.1 s with
  `forks=2`; the same with `poll: 0` and a wait loop needed 5.1 s and 5.9 s, and with `poll: 1`
  9.1 s at `forks=2` (a single run each, on one machine). If all hosts fit into `forks`, an
  ordinary task is as parallel as a background task. `async` pays when there are more hosts
  than `forks`, when the play should do other work while the job runs, or when the job must not
  depend on one connection staying up.

### Background jobs and idempotency

L00 introduced the rule: a second run changes nothing. A `command` task gets there with
`creates:`, which skips the command when a file exists. With `poll: 0` it breaks. The task
result is only "job started", and the module - including its `creates:` test - runs later in
the background, after the status of the start task was decided. This play runs a job that
`creates:` a marker file; run it **twice**:

```yaml
- name: Why creates is not enough with poll 0
  hosts: targets
  gather_facts: false
  tasks:
    - name: Start the job, guarded only by creates
      ansible.builtin.command:
        cmd: sh -c 'sleep 1; echo built > /tmp/lesson09-marker'
        creates: /tmp/lesson09-marker
      async: 30
      poll: 0
      register: marker_job
    - name: Collect the job
      ansible.builtin.async_status:
        jid: "{{ marker_job.ansible_job_id }}"
      register: marker_result
      until: marker_result.finished
      retries: 10
      delay: 1
    - name: What the job itself reported
      ansible.builtin.debug:
        msg: "changed={{ marker_result.changed }} {{ marker_result.msg }}"
```

First run: `changed=2` in the recap (start and collect). Second run: the marker exists, the job
reports `changed=False Did not run command since '/tmp/lesson09-marker' exists` - and the recap
still says `changed=1`, because the start task was already `changed`. Under `--check` it is the
same: the start task reports `changed`, although in check mode the job does nothing (the marker
was not created in a test on a fresh host). The play is not idempotent, and a checker that runs
a second time will say so. The cause tells the way out: the decision "do we need this job at
all?" has to be made **before** the job starts, by a task that runs in the foreground and has an
honest `changed` of its own. What that task is, is the part of 4.08 that is yours to build.
`creates:` stays as a guard *inside* the job, but it only covers the moment between the check
and the start of the job: while a long job runs, the file does not exist yet, so a second run
that starts then starts a second job (in a test with a stand-in job, both jobs ran).

Remove the marker and the job file with `rm -f /tmp/lesson09-marker /tmp/lesson09-job.txt`.

## CIS background

Section **6.3** of [the control catalogue](../../cis/controls.yml) is Level 2 and marked
`container: config`; section **6.1** is Level 1 and `container: full`. 6.3 asks that the
important events of a host are recorded where an attacker cannot erase them: changes to who may
act with administrative rights, commands run as another user, changes of the clock (which
confuses the correlation of logs), changes of accounts and of the files that decide how a login
is checked, and the login records themselves; that the rule set is locked against change; and
that the log has a retention policy. 6.1 asks for the other half: a checker that knows what
the files should look like, with its database initialised and a regular check.

The costs are the reason 6.3 is Level 2. Auditing needs disk space, CPU for syscall rules and
people to read the output; an immutable rule set needs a reboot for every change; and
`single`/`halt` on a full disk trades availability for audit. AIDE costs I/O at scan time
and attention at every patch window. A Level 1 AIDE without a review process produces reports
nobody reads, and an audit log without anyone searching it is storage. Benchmarks number these
differently (L01) and some current Benchmarks put the two topics in different places; the
catalogue ids are the lab's own. The lab can configure auditd but not run it (see below), and
it can run AIDE completely.

## Platform differences

| os_family | Hosts | Audit package (version measured) | Rules shipped in `rules.d` | Units after the install | AIDE |
|---|---|---|---|---|---|
| Debian | debian (13), ubuntu (26.04) | `auditd` (4.0.2, 4.1.2) | `-D`, `-b 8192`, `--backlog_wait_time 60000`, `-f 1` | `auditd.service`, `audit-rules.service`, both enabled | `aide` and `aide-common` (0.19.1, 0.19.2), `/etc/aide/aide.conf`, database `/var/lib/aide/aide.db`, wrapper `aideinit`, `dailyaidecheck.timer` |
| RedHat | rocky (10.2), alma (10.2), fedora (44) | `audit` (4.0.3, 4.0.3, 4.2.1) | rocky and alma: the four lines of Debian; fedora: `-D`, `-a task,never` | both enabled; `auditd` was `activating` on rocky, `failed` on alma and fedora | `aide` (0.19.2), `/etc/aide.conf`, database `/var/lib/aide/aide.db.gz`, no `aideinit`, no timer |
| Suse | opensuse (Leap 16.0) | `audit` (4.0) | `-D`, `-a task,never` | both enabled, `auditd` inactive; `auditd.service` runs `augenrules --load` after the start | not in 4.08; `aide` was not installed, I did not look for the package |
| Alpine | alpine (3.24) | `audit` (4.1.2) | none (`rules.d` is empty) | OpenRC script `/etc/init.d/auditd`, stopped | not in 4.08, no `aide` |
| Archlinux | arch | `audit` (4.2.1) | none (`rules.d` is empty) | both units present and disabled | not in 4.08, no `aide` |

All values were measured on the lab's targets after installing the packages (the Debian family
with the service start suppressed, so their `is-active` is not shown). `auditd.conf` is
`/etc/audit/auditd.conf` with the same ten defaults on all eight hosts (see above); `augenrules`,
`auditctl` and `ausearch` are present everywhere the package is, alpine included. Which unit
loads the rules is version-dependent: read `systemctl cat auditd.service audit-rules.service`
before you assume. The AIDE option names (`database_in` and so on) are the same in both
configurations; the Red Hat file builds its paths from `@@define DBDIR` and compresses the
database (`gzip_dbout=yes`, `.gz`), the Debian file lists three `@@x_include` lines.

### In the lab containers

- The audit subsystem belongs to the host kernel, so the lab only **configures** auditd
  ([container limits](../CONTAINER_LIMITS.md)): files are written, nothing is loaded and no
  service is started on purpose. The reference solutions guard that with `lab_in_container`
  (L05). On a VM or bare metal the same role also enables and starts the service. After a plain
  package install the RPM hosts above had `auditd` already enabled, and three of them had
  tried to start it; nothing in the lab depends on that.
- AIDE runs completely: it scans the container's file system. A first database of a whole
  target takes minutes, which is the reason for the `async` part of 4.08.
- The `async` examples need nothing but the 0.02 prerequisite; `systemd-analyze` exists on the
  seven systemd hosts only, hence `targets:!alpine`. The AIDE example needs network access for
  the package, and the five hosts of 4.08.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| A rule file is in `rules.d` and nothing is audited | the files are configuration; the rules are only active once loaded | load them (`augenrules --load`, or start the service) - on a real host, never in the lab |
| A rules file is ignored | the name does not end in `.rules` | rename it; read the merged result in `/etc/audit/audit.rules` |
| Rules are merged in an unexpected order | natural sort of the file names: `100-` after `60-`, `5-` before `50-` | use fixed-width numeric prefixes |
| `augenrules --check` is "successful" although the rules changed | its exit code is 0 either way | read its text, or compare the generated file |
| A rule change on a running host has no effect | the set was locked with `-e 2` | reboot, or leave the lock out while you test |
| The audit log has a gap | `suspend` (or a full disk with `suspend`) stops the writing | decide the actions on purpose and watch the free space |
| `aide --check` fails in a play although it worked | any difference gives a non-zero code (1 to 7) | accept 1 to 7 as "differences", fail only on higher codes |
| `aide --check` after `--init` reports a missing database | `--init` writes `database_out`, the check reads `database_in` | promote the new file to the `database_in` name |
| An AIDE report is full of changes after patching | the baseline predates the update | read the report, then update and promote the new database |
| `FAILED - RETRYING` appears in the output | `async_status` has not seen `finished` yet | nothing - it is the wait loop; it fails only when the retries are used up |
| A background job failed and the run is green | the start task only says "started" | collect with `async_status` and check `failed` or `rc` |
| A `poll: 0` task with `creates:` is `changed` on every run | the module and its `creates:` run later in the background | decide before the job starts |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [3.04](../../exercises/stage3-intermediate/3.04-auditd-rules/README.md) | what the audit subsystem is and why the lab only configures it, rule kinds, keys, `rules.d` and the merge, `-e 2`, the `auditd.conf` actions |
| [4.08](../../exercises/stage4-advanced/4.08-aide-async/README.md) | baseline, `database_in`/`database_out`, exit codes, timer and service units, `async`, `poll: 0`, `async_status` and the idempotency trap |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A file `/etc/audit/rules.d/50-demo.rules` contains a rule and the host was installed an hour
   ago. Is anything audited? What would you check, and where?

   <details><summary>Answer</summary>

   Not necessarily: the files are configuration, and the rules count only once they are loaded
   into the kernel. `auditctl -l` lists the loaded rules; `/etc/audit/audit.rules` is the merged
   file, and the init system's units (`auditd.service`, on newer versions also
   `audit-rules.service`) do the loading.

   </details>

2. `rules.d` holds `100-late.rules`, `60-watch.rules` and `05-lock.rules`, and only the last one
   contains `-e 2`. In which order are the files merged, and where does the `-e 2` stand in
   `/etc/audit/audit.rules`?

   <details><summary>Answer</summary>

   In natural sort order: `05-lock.rules`, `60-watch.rules`, `100-late.rules` (a plain
   alphabetical sort would put `100-` first). The last `-e` of the merge is emitted as the last
   line of the generated file wherever it stood, so the lock ends up after the rules of
   `100-late.rules`.

   </details>

3. Why does a rule that selects real users say `-F auid>=1000 -F auid!=unset`, and what does
   the demo play print for `uid` and `loginuid` with `become: true`?

   <details><summary>Answer</summary>

   An unset loginuid is -1, which the audit system treats as an unsigned number (4294967295), so
   it passes `>=1000` and must be excluded separately. With `become` the uid is 0 and the
   loginuid is the id of the account Ansible logged in with (alpine: unset).

   </details>

4. The disk with the audit log is almost full. What happens with `rotate`, `suspend`, `single`
   and `keep_logs` as the action, and what does each cost?

   <details><summary>Answer</summary>

   `rotate` removes the oldest records to make room: the host keeps running and loses
   evidence. `suspend` keeps the daemon alive but stops writing: a gap in the log. `single`
   moves the machine to single-user mode: nothing is lost and the service is down. `keep_logs`
   deletes nothing, so it is not an answer to a full disk, only a reason for the next stage to
   trigger.

   </details>

5. An AIDE check ends with exit code 6 and another with 0. What do the numbers say, and why
   should a play not fail on 6?

   <details><summary>Answer</summary>

   0 means no differences. 6 is 2 + 4: files were removed and files changed; the code is a sum
   of three bits (1 added, 2 removed, 4 changed). Codes 1 to 7 mean "the tool worked and found
   differences", which is its job; failing on them hides the report. Fail on codes above 7,
   which are errors.

   </details>

6. After a patch run AIDE reports 40 changed files. You run `--update` and move the new
   database into place without reading the report. What did you give up?

   <details><summary>Answer</summary>

   The baseline now includes whatever else changed - a replaced binary among the 40 files
   included. Read the report first (does the list match the packages that were updated?), then
   update and promote. The check is only as good as the review before the promotion.

   </details>

7. A task starts a job with `async: 600` and `poll: 0`; the job fails after one second. What does
   the recap show, where can you see the failure, and what changes if the play ends right after
   the start?

   <details><summary>Answer</summary>

   The start task is `changed` and the recap shows no failure. The failure is visible only
   through `async_status` for the job id (`failed: true`, `rc`, stderr). If the play ends
   without collecting, nobody reads the result and the run is green; and a job that is still
   running continues after the play.

   </details>

8. The same task has `creates: /var/lib/x/db`, the file exists, and the play still reports
   `changed` on every run, also with `--check`. Why, and where does the decision have to move?

   <details><summary>Answer</summary>

   With `poll: 0` the start task is decided before the module runs: it reports that a job was
   started. The module and its `creates:` test run later in the background and only the job's
   own result (`async_status`) says "did not run, file exists". The decision has to be made
   before the job starts, in a foreground task that reports its own state.

   </details>

## Further reading

- [`ansible.builtin.async_status`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/async_status_module.html) and [Asynchronous actions and polling](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_async.html) - the mechanism and its limits
- [`ansible.builtin.command`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html) - `creates` and `removes`
- [`audit.rules(7)`](https://man.archlinux.org/man/audit.rules.7) and [`auditctl(8)`](https://man.archlinux.org/man/auditctl.8) - rule syntax, fields, the enabled flag
- [`augenrules(8)`](https://man.archlinux.org/man/augenrules.8) and [`auditd.conf(5)`](https://man.archlinux.org/man/auditd.conf.5) - merging rule files and the daemon's settings
- [`pam_loginuid(8)`](https://man.archlinux.org/man/pam_loginuid.8) - where the login id comes from
- [`aide(1)`](https://manpages.debian.org/unstable/aide/aide.1.en.html) and [`aide.conf(5)`](https://manpages.debian.org/unstable/aide/aide.conf.5.en.html) - commands, exit codes, rules and selection lines
- [`systemd.timer(5)`](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html) and [`systemd.service(5)`](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html) - timers and `Type=oneshot`
