# 2.05 - Job schedulers: cron permissions and access: Explanation

### What the check verifies
`lab check 2.05` runs `check.yml` on all eight targets and then your playbook once more with
`--check`, expecting `changed=0` (`meta.yml` says `idempotency: true`). `check.yml`:
- stats `/etc/crontab`, the four `cron.<period>` directories, `/etc/cron.d` and `/etc/crontabs`;
  every path that exists must be `root:root` with no group or other permission bit;
- except on Alpine: `/etc/cron.allow` exists, is owned by root, is not readable or writable by
  others and not writable by the group;
- the cron service of the family (dict as in the README) is running and enabled - on systemd
  hosts `service_facts` reports `enabled`, on Alpine the service must be in the `default`
  runlevel.

It does not test: the exact modes (a `0400` crontab or a `0500` directory passes too), the
content and group of `cron.allow`, that `cron.deny` is gone, and that you created nothing - a
`/etc/cron.d` made on Alpine passes as well. Those parts of the README are yours.

### How it works

#### Harden what exists
The solution keeps one list of `{path, mode}` dicts, runs `stat` on every path and then a `file`
task with `when: item.stat.exists` over the results (`item.item.path`, `item.item.mode`). Paths
that are missing are skipped, not created: a directory that the installed cron does not read
would only *look* compliant to a scanner. Harden what exists; do not fabricate configuration.

#### One intent, four service names
`cron`, `crond`, `cronie`: the dict keyed by `ansible_facts.os_family` keeps the task itself
identical on all hosts. In stage 3 this dict moves into `vars/<family>.yml` of the role.

#### What the allow and deny lists control
Measured for lesson L06 (Debian cron 3.0pl1, cronie 1.7.1, BusyBox crond 1.36.1/1.37.0):
- `cron.allow` wins over `cron.deny`; root may always use `crontab`; an empty `cron.allow`
  means root only.
- With neither file, Debian's cron lets every user run `crontab`, cronie only root.
- The lists control the `crontab` command, not running jobs: a user's existing crontab kept
  running after `cron.allow` excluded the user (cron and cronie). Remove the spool file too.
- BusyBox has no `cron.allow`/`cron.deny` support at all, and its `crontab` refuses non-root
  users unless it is installed setuid ("must be suid"). The closest control is the spool
  directory `/etc/crontabs`.

With `cron.allow` in place, `cron.deny` is ignored; the solution removes it so nobody reads a
list that has no effect (bonus 1).

#### Unsafe files are skipped silently
The daemons do not fail on a file they consider unsafe - they skip it and log a line at most.
Measured: Debian cron and cronie ignore a group- or other-writable file in `/etc/cron.d` and a
`0666` `/etc/crontab`; cronie also skips files not owned by root and, in `/etc/cron.d`, files
with an execute bit (`BAD FILE MODE`, `WRONG FILE OWNER`); Debian cron skips names with a dot
and a second hard link. A file that is too open is not an error message, it is a job that
never runs.

#### N/A is a legitimate result
A control can be *not applicable* (BusyBox has no allow-list). Write down why (comment,
exception list) and apply the closest equivalent control (`/etc/crontabs` `0700`). Auditors
accept a documented N/A; they do not accept silence.

### Per-family notes
| `os_family` | Hosts | Cron / service | At the start (fresh targets) |
|---|---|---|---|
| Debian | debian, ubuntu | Debian cron / `cron` | `/etc/crontab` `0644`, directories `0755`, no `cron.deny` |
| RedHat | rocky, alma, fedora | cronie / `crond` | `/etc/crontab` `0644`, directories `0755`, empty `cron.deny` `0644` |
| Suse | opensuse | cronie / `cron` | `/etc/crontab` `0600`, directories `0755`, `cron.deny` (6 bytes) `0600` |
| Archlinux | arch | cronie / `cronie` | `/etc/crontab` `0644`, directories `0755`, `cron.deny` (74 bytes) `0644` |
| Alpine | alpine | BusyBox crond / `crond` | no `/etc/crontab`, no `cron.*` directories; `/etc/crontabs` `0755` with root's crontab |

No target has a `cron.allow`, `at` or `atd` at the start (bonus 2: `at` is installed on none of
them).

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| A job in `/etc/cron.d` never runs, no error | the file is group- or other-writable, not root's, or (cronie) executable | `0644` or `0600`, `root:root`, no execute bit |
| Every user can still run `crontab` on Debian | neither list exists, so Debian's cron allows everyone | create `cron.allow` |
| An excluded user's jobs keep running | the lists only guard the `crontab` command | remove the user's spool file as well |
| `cron.allow` on Alpine changes nothing | BusyBox does not read it | restrict `/etc/crontabs`, document the N/A |
| The check passes, the README is not met | it tests "no group/other bits", not the exact mode | set exactly `0600`/`0700`/`0640` |

### Real-world notes
- `root` alone in `cron.allow` means only root may run `crontab -e`. Service accounts that need
  user crontabs must be listed. In practice prefer `/etc/cron.d/<app>` files deployed by
  configuration management - visible, reviewable, versioned.
- systemd timers schedule jobs too, and none of these files controls them: `systemctl
  list-timers` showed two to six timers on each of the seven systemd targets.

### Further reading
- Lesson [L06 - Job schedulers: who runs what, and who may schedule it](../../../docs/lessons/L06-job-schedulers.md): the three implementations, the lists, what the daemons skip - the concepts before this exercise.
- Lesson [L04 - Platform differences as data: dictionaries, loops, Jinja2 and templates](../../../docs/lessons/L04-platform-differences-as-data.md): the dict lookup and `stat` loops used here.

## Reference solution

Show it with `lab solution 2.05`, apply it with `lab solve 2.05`.
