# L06 - Job schedulers: who runs what, and who may schedule it

*[Deutsch](L06-job-schedulers.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 2.05 | 2.4 | ~25 min | L02, L03, L04 |

A scheduler is a root-owned program that starts commands later, unattended, from a list somebody
else wrote down. That makes the files it reads one of the most valuable targets on a host, and
who may add to them one of the first questions a hardening guide asks. This lesson covers where
cron and its relatives read their jobs from, which files the daemons refuse, how the allow and
deny lists really work, and what differs between the three cron implementations in the lab.

## Learning goals

After this lesson you can ...

- [ ] name the places cron reads jobs from and say under whose authority each job runs
- [ ] explain why write access to a file the daemon reads is a root-level privilege
- [ ] predict from owner, mode and name whether a daemon accepts a drop-in, and find the log line when it does not
- [ ] say what `cron.allow` and `cron.deny` decide, in which order, and what they leave untouched
- [ ] tell Debian cron, cronie and BusyBox crond apart by what they read and what they check
- [ ] write a job with `ansible.builtin.cron` so that a second run changes nothing

## Theory

### Where jobs come from, and whose authority they run under

The daemon (`cron` or `crond`) runs as root, reads job definitions and starts each one as the
user the definition names. A definition comes from one of three places:

- **System crontab and drop-ins:** `/etc/crontab` and the files in `/etc/cron.d`. A line has
  five time fields, then a *user* field, then the command.
- **User crontabs:** one file per user in a spool directory, edited with `crontab -e`. Lines have
  no user field - the owner of the file is the user.
- **Periodic directories:** `/etc/cron.hourly`, `.daily`, `.weekly`, `.monthly`. They are not
  crontabs: a line in a crontab calls `run-parts`, which runs the executable files of the
  directory. Debian's `run-parts` skips files with a dot in the name and files that are not
  executable (tested with version 5.17).

BusyBox `crond` on Alpine is simpler: it reads one spool directory, `/etc/crontabs`, with one
file per user. The periodic directories live in `/etc/periodic` and are started by lines in
*root's* crontab.

Every definition is a command that will run as the named user - for system files, as root.
Whoever can change such a file, or put a new one into a directory the daemon reads, runs code
with that identity, and nobody has to log in for it. That is why a benchmark cares about owners
and modes of cron files, and why the next concept matters.

`ansible.builtin.cron` manages one entry per task. It marks its line with a comment
`#Ansible: <name>` and finds the entry by that name, which is why a second run reports `ok`
(renaming a job therefore creates a second entry; `state: absent` with the name removes it).
Without `cron_file` it edits a user crontab through the `crontab` command; with `cron_file` it
writes a drop-in into `/etc/cron.d` in the system format, so `user` is required:

```yaml
- name: A drop-in job and what the module wrote
  hosts: targets:!alpine
  become: true
  gather_facts: false
  tasks:
    - name: Drop-in with one nightly job
      ansible.builtin.cron:
        name: lesson demo job
        cron_file: lesson-demo
        user: root
        minute: "30"
        hour: "3"
        job: "/bin/true"
    - name: Read the file back
      ansible.builtin.command: cat /etc/cron.d/lesson-demo
      register: dropin
      changed_when: false
      when: not ansible_check_mode
    - name: Show it
      ansible.builtin.debug:
        var: dropin.stdout_lines
      when: not ansible_check_mode
```

The file holds the marker and the line `30 3 * * * root /bin/true`, written `root:root` with mode
`0644`. The play skips alpine because `/etc/cron.d` is not where BusyBox looks; there the same
module without `cron_file` edits root's crontab and works (first run `changed`, second `ok`). The
harmless demo job stays behind: remove it with `rm /etc/cron.d/lesson-demo` or
`./lab.sh reset <host>` (`.\lab.ps1 reset <host>` on Windows).

### What the daemon accepts: permissions as a precondition

Permissions on cron files read like plain hardening: the fewer may write, the better. For cron
they are also a **precondition**. The daemon checks a file before it obeys it and refuses any
that somebody else could have modified. Your play does not see this: the task succeeded, the
file exists, the job never runs. Measured with real daemons:

| Daemon | Refuses a drop-in when ... |
|---|---|
| Debian cron 3.0 (Ubuntu 24.04) | the owner is not root; group or others may write; the file has a second hard link; the name contains a dot |
| cronie 1.7.1 (Debian package; rocky gave the same refusals for `0666` and `0700`) | the owner is not root; group or others may write; an execute bit is set (`0700` is refused, `0400`, `0600` and `0644` run). A dot in the name or a second hard link is accepted |
| BusyBox crond 1.36.1 and 1.37.0 | there is no mode check; the spool file must be named for an existing user - a file owned by that user was skipped without a message, a root-owned one ran (checked on both versions) |

`/etc/crontab` follows the same rules: with mode `0666` both Debian cron and cronie ignored it,
and with `0644` the same job ran. Three consequences: **owner root and no write bit for group or
others satisfies every daemon**; extra bits can hurt (an execute bit disables a cronie drop-in);
and names with letters, digits, `-` and `_` are safe everywhere, because the dot rule is
Debian's alone.

A refusal goes to the daemon's log, not to Ansible. cronie writes `BAD FILE MODE (<path>)` or
`WRONG FILE OWNER (<path>)` to the journal; none of the seven systemd targets has a
`/var/log/cron*` file. Where Debian's cron reports a refusal, and with which text, I did not
capture. The unit name differs by family (see the table below):

```bash
# Rocky: the unit is crond; Debian and openSUSE: cron; Arch: cronie
ansible rocky -b -m ansible.builtin.command -a "journalctl -u crond --no-pager -n 20"
```

You can also audit before the daemon does. This play writes four demo files with different modes
into a scratch directory and lists, together with the real `/etc/cron.d`, every file that is
not owned by root or that group or others may write:

```yaml
- name: Which drop-ins would the daemon refuse?
  hosts: targets:!alpine
  become: true
  gather_facts: false
  tasks:
    - name: Directory for the demo files
      ansible.builtin.file:
        path: /tmp/lesson-cron.d
        state: directory
        owner: root
        group: root
        mode: "0755"
    - name: One demo file per mode
      ansible.builtin.copy:
        dest: "/tmp/lesson-cron.d/{{ item.key }}"
        content: "# demo file, no job\n"
        owner: root
        group: root
        mode: "{{ item.value }}"
      loop: "{{ {'plain': '0644', 'private': '0600', 'group-writable': '0664', 'world-writable': '0666'} | dict2items }}"
      loop_control:
        label: "{{ item.key }}"
    - name: Collect the demo files and the real drop-in directory
      ansible.builtin.find:
        paths:
          - /tmp/lesson-cron.d
          - /etc/cron.d
        file_type: file
      register: found
    - name: Files that others can write or that root does not own
      vars:
        safe: "{{ found.files | rejectattr('wgrp') | rejectattr('woth') | selectattr('uid', 'equalto', 0) | map(attribute='path') | list }}"
      ansible.builtin.debug:
        msg: "{{ found.files | map(attribute='path') | difference(safe) | sort }}"
```

`find` returns stat data per file (`uid`, `wgrp`, `woth`, ...); the filter keeps what both
daemons accept and the play prints the rest. It models the rules the daemons share, not one
daemon: it knows neither the dot rule nor the execute bit. Remove the demo files with
`rm -r /tmp/lesson-cron.d`.

### Who may schedule: allow and deny lists

Unless something restricts it, a user may run `crontab -e` and schedule jobs as themselves. The
`crontab` command consults two list files, in this order:

1. If `/etc/cron.allow` exists, only the users listed in it may use `crontab`.
2. Otherwise, if `/etc/cron.deny` exists, everybody except the users listed in it may.
3. If neither exists, the implementation decides.

Measured with Debian cron and cronie: root is always allowed, an allow file wins over a deny
file, and an *empty* allow file means nobody but root. Case 3 differs: Debian cron lets everybody
use `crontab`, the cronie package from Debian lets only root. RPM-family packages avoid the
question by shipping an empty `cron.deny` (checked on rocky, alma and fedora), which allows
everybody. `at` has the same two files, `at.allow` and `at.deny`, but with neither of them only
root may use it (tested with Debian's `at` 3.2.5).

What the lists do **not** do matters as much (tested with Debian cron and cronie):

- They decide who may *use the `crontab` command*. A user who is not on the allow list keeps
  every crontab that already exists, and its jobs keep running.
- They have no effect on `/etc/crontab`, `/etc/cron.d` and the periodic directories.
- BusyBox reads neither file: the strings `cron.allow` and `cron.deny` do not occur in the
  BusyBox 1.36.1 and 1.37.0 binaries (checked with `grep -c -a`), so on Alpine a list file is
  inert.

A short play names the model each host is set up for. It reads only, so it is safe everywhere:

```yaml
- name: Which access model does this host use?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Look for the list files of cron and at
      ansible.builtin.stat:
        path: "/etc/{{ item }}"
      loop:
        - cron.allow
        - cron.deny
        - at.allow
        - at.deny
      register: lists
    - name: Name the model for each scheduler
      vars:
        present: "{{ lists.results | selectattr('stat.exists') | map(attribute='item') | list }}"
        cron_model: "{{ 'allow list' if 'cron.allow' in present else ('deny list' if 'cron.deny' in present else 'no list') }}"
        at_model: "{{ 'allow list' if 'at.allow' in present else ('deny list' if 'at.deny' in present else 'no list') }}"
      ansible.builtin.debug:
        msg: "cron: {{ cron_model }}, at: {{ at_model }}"
```

The output names which *files* exist, not the effective policy: `no list` means "the
implementation decides", and that is exactly the case you should not rely on.

### Other places jobs hide

Cron is one scheduler of several, and a host audit has to ask for the others:

- **`at`** runs a job once. Queued jobs only run while the `atd` service runs: without it `at`
  accepts the job and warns `No atd running?` (tested). The package is not always installed;
  `command -v at` tells. `ansible.posix.at` schedules from a play.
- **systemd timers** start a `.service` unit on a schedule. No cron file or list governs them;
  `systemctl list-timers` shows what is active (it works on all seven systemd targets).
- **anacron** runs the daily, weekly and monthly jobs of hosts that are not always on. On Debian
  the three matching lines in `/etc/crontab` step aside when `/usr/sbin/anacron` exists.

## CIS background

Section **2.4** of [the control catalogue](../../cis/controls.yml) is Level 1: the scheduler is
enabled and running (scheduled maintenance and checks must happen), its files and directories
cannot be changed by others, and the use of `crontab` is limited to named users. The last two
close two different paths for an attacker: *modifying* a definition that root already trusts,
and *adding* one under their own name. Older Benchmarks put cron and `at` into one
recommendation; newer ones list them separately. The catalogue covers cron only; `at` and
timers belong in an audit, not in the exercise.

The cost is small - root and a few named service accounts schedule jobs - and it is paid in
deployment: jobs of an application belong in a reviewed drop-in, not in a user crontab. A
control can also be **not applicable**: BusyBox has no list file that is read, so the
recommendation cannot be met as written. That is a documented exception, not a missing line
(L01 on exceptions, 4.01 for how an audit reports `n/a`).

## Platform differences

| os_family | Hosts | Implementation (package) | Service | User spool | List files at delivery |
|---|---|---|---|---|---|
| Debian | debian, ubuntu | Debian cron (`cron`) | `cron` | `/var/spool/cron/crontabs` | none |
| RedHat | rocky, alma, fedora | cronie (`cronie`) | `crond` | `/var/spool/cron` | empty `cron.deny` |
| Suse | opensuse | cronie (`cronie`) | `cron` | `/var/spool/cron` | `cron.deny`, not empty |
| Alpine | alpine | BusyBox `crond` | `crond` (OpenRC) | `/etc/crontabs` | none; no list file is read |
| Archlinux | arch | cronie (`cronie`) | `cronie` | `/var/spool/cron` | `cron.deny`, not empty |

Debian cron and cronie read `/etc/crontab`, `/etc/cron.d` and the periodic directories; BusyBox
reads only its spool directory (the 1.36.1 and 1.37.0 binaries have no reference to `cron.d`,
checked with `grep -c -a`). The service names differ even where the implementation is the same
(`cron` on openSUSE, `cronie` on Arch), so keep them in data (L04). BusyBox's `crontab` stops
for an ordinary user with `must be suid to work properly` in the 1.36.1 build I tested; I did
not verify that on Alpine. I did not look at the content of the non-empty `cron.deny` files.

### In the lab containers

- Cron really runs in all eight targets, as part of the container; a job started there does
  nothing to your host (see [the container limits](../CONTAINER_LIMITS.md)).
- The systemd targets log to the journal (`journalctl -u <service>`); there is no
  `/var/log/cron*`.
- The examples need Python on the target, so alpine needs 0.02 first - the two examples that
  write drop-ins skip it with `targets:!alpine`.
- Demo files stay until you remove them or reset the host.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The play is green, the job never runs | the daemon refused the file (owner, mode, name) | read the journal (`BAD FILE MODE`, `WRONG FILE OWNER`); owner root, no write bit for group or others |
| A drop-in `cron_file: backup.job` is ignored on Debian | Debian cron skips names with a dot | letters, digits, `-` and `_` only |
| A cronie drop-in is ignored although only root can write it | an execute bit is set (`0700`) | `0644` or `0600` |
| After creating `cron.allow`, a user's jobs still run | the lists only gate the `crontab` command | remove that user's crontab, or move the job to a reviewed drop-in |
| `You (alice) are not allowed to use this program (crontab)` | an allow list exists and alice is not on it | add her, or schedule through a drop-in |
| A host without list files is "open" on one distribution and "closed" on another | the default for case 3 belongs to the implementation | make the intent explicit with a list file |
| Renaming `name:` adds a second entry | the module identifies its entry by the name in the `#Ansible:` marker | keep names stable; remove the old name with `state: absent` |
| A file in `/etc/crontabs` on Alpine does nothing | the owner is the user, or no such user exists | owned by root, named for an existing user |
| `at` accepts the job and nothing happens | `atd` is not running | enable and start the service |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [2.05](../../exercises/stage2-building-blocks/2.05-cron-hardening/README.md) | what the daemons read and accept, how the list files work and which implementation honours them, why one intent needs different files on different hosts |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. Why is write access to a file in `/etc/cron.d` as good as a root shell?

   <details><summary>Answer</summary>

   The daemon runs as root and starts every definition as the user named in it, unattended.
   A line with `root` in the user field runs as root at the next matching minute, so changing
   the file - or adding a file the daemon accepts - means running code as root.

   </details>

2. A drop-in has mode `0664`; the play that wrote it was green and its job never ran. Where do
   you look, and what do you change?

   <details><summary>Answer</summary>

   The daemon refused the file because group members may write it; the refusal is in its log
   (`journalctl -u <service>`, cronie says `BAD FILE MODE`), not in the play. Set the owner to
   root and remove the write bits for group and others - `0644` or `0600`.

   </details>

3. Name two things that Debian cron refuses and cronie accepts, and one that cronie refuses and
   Debian cron accepts.

   <details><summary>Answer</summary>

   Debian cron refuses a name with a dot and a second hard link; cronie accepts both. cronie
   refuses a drop-in with an execute bit (`0700`); Debian cron ran it. Both refuse a
   non-root owner and write bits for group or others.

   </details>

4. `cron.allow` contains only `deploy`. Alice has a crontab with a nightly job. Does the job
   run, may she edit it with `crontab -e`, and may root?

   <details><summary>Answer</summary>

   The job keeps running: the lists gate the `crontab` command, not existing crontabs. Alice
   may not edit it, because she is not on the allow list. Root may - it is always allowed.

   </details>

5. Neither `cron.allow` nor `cron.deny` exists. May an ordinary user run `crontab -e`? What do
   you conclude for a hardened host?

   <details><summary>Answer</summary>

   It depends on the implementation: Debian cron allows everybody, the Debian cronie package
   only root, and RPM-family packages ship an empty `cron.deny`, which allows everybody. A
   hardened host should not rely on the default but state its intent in a list file.

   </details>

6. Why does a `cron.allow` file on Alpine not restrict anybody, and which question replaces
   "is the list there?"

   <details><summary>Answer</summary>

   BusyBox's `crond` and `crontab` never read it - the binaries contain no reference to the
   file name - so a list file there controls nothing, however well a scanner is satisfied by
   it. The useful question is which files and directories the daemon *does* read and who may
   change them: the first two concepts of this lesson.

   </details>

## Further reading

- [`ansible.builtin.cron`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/cron_module.html) and [`ansible.posix.at`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/at_module.html) - all options
- [`crontab(1)`](https://man.archlinux.org/man/crontab.1) and [`crontab(5)`](https://man.archlinux.org/man/crontab.5) - the allow and deny files, the system format with its user field
- [`at(1)`](https://man.archlinux.org/man/at.1) - `at.allow`, `at.deny` and the queue
- [`systemd.timer(5)`](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html) - timers as the other scheduler on systemd hosts
- [Glossary](../GLOSSARY.md) - terms of this lesson: allow and deny lists, at, cron, systemd timer
