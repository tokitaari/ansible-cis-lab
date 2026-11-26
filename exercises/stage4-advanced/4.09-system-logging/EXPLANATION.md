# 4.09 - System logging: one logger per host, chosen by data: Explanation

### What the check verifies
`lab check 4.09` runs `check.yml` on all eight targets and then your playbook once more with
`--check`, expecting `changed=0` (`meta.yml` says `idempotency: true`). The check knows the same
table as the README and tests each host for its logger:

- **systemd hosts:** it reads `systemd-analyze cat-config systemd/journald.conf`, keeps the last
  value of every key and asserts `Storage=persistent`, `Compress=yes`, `SystemMaxUse` as a number
  with an optional `K`/`M`/`G`/`T`, on journald-only hosts `ForwardToSyslog=no`, and at least one
  `system.journal` below `/var/log/journal`.
- **RedHat family:** `rsyslogd -N1` exits 0, `rsyslog` is `enabled` and `active`, at least one
  `$FileCreateMode` line exists in `rsyslog.conf` or `rsyslog.d/*.conf` and none is looser than
  0640, no uncommented line names `imtcp` or `imudp`, a `logger` line with the host name appears
  in `/var/log/messages` within five seconds, and `/var/log/messages` and `/var/log/secure` exist
  with a mode no looser than 0640.
- **Alpine:** `syslog` is listed by `rc-update show default`, exactly one `/sbin/syslogd` runs,
  and both `SYSLOGD_OPTS` and the running command line contain `-s` and `-b` with a non-zero value.

It does not test that the choice lives in a dict or that an `assert` guards it, where your
journald settings are written (an edited main file passes where one exists), that the mode line
has an effect, that `rsyslogd -N1` ran *before* the restart, or the mode of Alpine's
`/var/log/messages`. Measured with the reference solution: the check fails on all seven systemd
hosts of a fresh lab; the first run changes 8 tasks on rocky, alma and fedora, 5 on debian and
ubuntu, 4 on arch, 3 on opensuse and alpine; the second run and `--check` change nothing; the
whole runner job (`tools/run-solutions.sh 4.09`: reset, 0.02, solve, check, second run) took
157 s.

### How it works

#### The choice is data
```yaml
cis_logger_by_family: {Debian: journald, RedHat: rsyslog, Suse: journald,
                       Archlinux: journald, Alpine: syslogd}
cis_logger: "{{ cis_logger_by_family[ansible_facts.os_family] }}"
```
Every block of the play has `when:` on `cis_logger`, never on the family. To move a family to
another logger you change one value (or override `cis_logger` in `host_vars`), and the `assert`
stops a typo before the first change instead of silently skipping every block.

#### The value in effect, not the value in your file
journald reads its main file, then all drop-ins sorted by file name *across* `/etc`, `/run` and
`/usr/lib`. On debian and ubuntu the package `systemd` ships
`/usr/lib/systemd/journald.conf.d/syslog.conf` with `ForwardToSyslog=yes`; `syslog.conf` sorts
after `60-cis.conf`, so it wins (measured: `cat-config` lists it after the lab drop-in). A file of
the same name in `/etc` replaces a vendor file, and a symlink to `/dev/null` removes it - after
masking, `cat-config` prints the name of the link and nothing below it. The solution finds the
vendor files with `find` and `contains: "^ForwardToSyslog="`, so it does not depend on the name.
On opensuse the vendor file is `20-defaults-SUSE.conf` (`Audit=no`) and stays.

#### Persistent means: flushed
`Storage=persistent` plus a restart was not enough on rocky and alma, which have no
`/var/log/journal`: journald reported "Runtime Journal (/run/log/journal/...)". Only `journalctl
--flush` made it create the directory and switch ("System Journal (/var/log/journal/...)");
afterwards the flag file `/run/systemd/journal/flushed` exists and a later restart writes to
`/var` at once. The solution therefore has two handlers with `listen: journald config changed`:
restart, then flush, in the order of the `handlers:` section.

#### A whole-config check before the restart
`rsyslogd -N1 -f <drop-in>` exits 1 for a *valid* drop-in ("no active actions configured"),
so `validate:` cannot check a drop-in alone. `rsyslogd -N1` checks the whole configuration with
the drop-in included; it found an unknown directive, a missing module and a trailing character
(exit 1 each). `systemctl restart rsyslog` succeeded with every one of these broken drop-ins
(`active`), so the check is the only thing that notices. As a task between the drop-in and the
end of the play, a failure stops the host and its pending handlers do not run.

#### What `$FileCreateMode` really does
The `rsyslog` unit sets `UMask=0066` (measured on rocky and fedora), and the package scriptlet
loops over `messages`, `secure`, `maillog` and `spooler`: they exist with 0600 before the first
start, owned by no package. A probe with `$FileCreateMode 0400`
produced a fresh `messages` with 0400 on fedora (legacy action lines in `rsyslog.conf`) but 0600
on rocky: el10 (alma has the same `rsyslog.conf`) writes its actions as `action(type="omfile"
...)`, and legacy directives do not affect RainerScript objects (omfile documentation). On rocky
and alma the line is what an audit of the configuration looks for, while the unit's umask is
what keeps the files at 0600.

### Per-family notes
| `os_family` | Hosts | Before | Solution changes | Vendor drop-in |
|---|---|---|---|---|
| Debian | debian, ubuntu | journald persistent, `ForwardToSyslog=yes` | drop-in, mask `syslog.conf`, restart, flush | `syslog.conf` (package `systemd`) |
| RedHat | rocky, alma / fedora | journald volatile / persistent, no rsyslog | drop-in, rsyslog + drop-in, restart, flush | none |
| Suse | opensuse | journald persistent | drop-in, restart, flush | `20-defaults-SUSE.conf` (`Audit=no`) |
| Alpine | alpine | `syslogd -t` running, in no runlevel | `SYSLOGD_OPTS`, runlevel `default`, restart | - |
| Archlinux | arch | journald persistent | drop-in, restart, flush | none |

After the solution journald reported "max 200M" on the hosts measured (debian, ubuntu, fedora,
opensuse, arch). On rocky and alma the flush created the journal file with 0640 `root:root`, the
other hosts have `root:systemd-journal`; `systemd-journald.service(8)` suggests `systemd-tmpfiles
--create --prefix /var/log/journal` to give a new directory the right owner and mode.

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `ForwardToSyslog=no` is in your file, `cat-config` ends with `yes` | a vendor drop-in sorts after yours | mask it with a `/dev/null` link of the same name |
| `Storage=persistent`, still "Runtime Journal" | journald waits for a flush request | `journalctl --flush` after the restart |
| `validate: rsyslogd -N1 -f %s` fails on a correct drop-in | a drop-in has no actions | check the whole configuration with `rsyslogd -N1` |
| rsyslog is `active` with a broken line | rsyslog starts and logs the error | the `-N1` task before the restart |
| `$FileCreateMode 0640`, files are 0600 | `UMask=0066` in the unit; on el10 the line has no effect on `action()` | read the mode of the files, not only the line |
| `module(load="builtin:omfile" fileCreateMode=...)` fails | `omfile` is loaded already in `rsyslog.conf` | a legacy line or `fileCreateMode` per action |
| `Destination directory /etc/systemd/journald.conf.d does not exist` | only opensuse ships it in `/etc` | an `ansible.builtin.file` task with `state: directory` first |
| `rsyslogd -N1` fails with `capng_apply=-4` (error -2455) on rocky/alma | el10 rsyslog cannot drop its capabilities in the container on some host kernels | the image's `00-lab-container.conf` (`libcapng.enable="off"`, CONTAINER_LIMITS) |
| `logger: command not found` on opensuse | the image has no `logger` | `systemd-cat` (L15) |
| A restart of `syslog` also restarts `crond` | `crond` needs `logger` (OpenRC) | expected; plan it |

### Real-world notes
- The benchmark wants one logger; a second one doubles disk use and the places to look. On the
  RedHat family rsyslog reads the journal, so journald still needs its storage and size settings.
- A local log is lost with the host. Forward to a central host over TLS (rsyslog `omfwd` with a
  `StreamDriver`, or `systemd-journal-upload`) and decide how much the sender buffers while the
  central host is down.
- Check the rotation: journald limits itself; files written by rsyslog need `logrotate`, which
  came with rsyslog on debian and ubuntu and was already installed on the RedHat family.

### Further reading
- Lesson [L15 - System logging](../../../docs/lessons/L15-system-logging.md): the paths of a message, journald drop-ins and storage, rsyslog syntax and checks, `listen`, BusyBox syslogd - the concepts before this exercise.
- Exercise [4.08 - File integrity with AIDE](../4.08-aide-async/README.md): the other part of section 6 (6.1) that runs fully in the containers.

## Reference solution

Show it with `lab solution 4.09`, apply it with `lab solve 4.09`.
