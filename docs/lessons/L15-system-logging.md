# L15 - System logging: journald, rsyslog and BusyBox syslogd

*[Deutsch](L15-system-logging.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 4.09 | 6.2 | ~25 min | L02, L03, L04 |

Logs are what you read after something went wrong, and what an attacker wants to remove first.
The benchmark asks for little: one logger per host, configured completely, its files protected,
its size limited. The work is in the details that differ per distribution - which daemon receives
a message, which file is read last, when a setting is really in effect. This lesson follows a
message from the program to the disk, explains how journald and rsyslog are configured and
checked, and covers the Ansible tools that keep such a change safe: a check of the whole
configuration before a restart, and handlers that belong together.

## Learning goals

After this lesson you can ...

- [ ] describe the paths a message takes to journald, to rsyslog and to BusyBox syslogd, and say which daemon owns `/dev/log`
- [ ] predict the value in effect from a set of journald drop-ins, and replace or remove a vendor drop-in
- [ ] explain when journald writes to `/var/log/journal` and why a restart may not be enough
- [ ] read an rsyslog rule, tell the two configuration syntaxes apart and check a configuration before a restart
- [ ] use `listen` to run several handlers for one change in a known order
- [ ] tell "running" from "enabled" for an OpenRC service

## Theory

### One message, several paths

A program that logs the traditional way writes a short line to the socket `/dev/log`: a
*facility* (who: `auth`, `authpriv`, `cron`, `mail`, `user`, `local0` ... `local7`), a *priority*
(how bad: `debug` ... `emerg`) and the text. On a systemd host journald owns that socket
(`systemd-journald-dev-log.socket` is present on all seven systemd targets). journald stores every
message, with many more fields than the syslog line, in its binary journal and reads it back with
`journalctl`.

A traditional syslog daemon such as rsyslog then gets the messages in one of two ways:

- **It reads the journal files**, like `journalctl` does. On the RedHat family rsyslog loads
  `imjournal` and switches off its own socket (`imuxsock` with `SysSock.Use="off"`, measured on
  rocky, alma and fedora).
- **journald forwards a copy** to a second socket when `ForwardToSyslog=yes`, and rsyslog
  receives it there (`imuxsock`). Debian's, Ubuntu's and openSUSE's `rsyslog.conf` load
  `imuxsock`, and systemd's `syslog.socket` triggers rsyslog there (measured: stopping rsyslog
  warns that `syslog.socket` is still active).

Which way a family uses decides what `ForwardToSyslog` must be. On rocky the probe message
arrived once in `/var/log/messages` with `ForwardToSyslog=no` and once with `yes` - `imjournal`
does not need the copy. Without any syslog daemon the copy has no receiver.

On Alpine there is no journal: BusyBox `syslogd` owns `/dev/log` and writes every message to
`/var/log/messages`.

The rules of the syslog daemon decide which file a message ends up in. The same `logger -p
auth.info` line landed in `/var/log/auth.log` on debian and in `/var/log/messages` on rocky:
rocky's rules send `authpriv` (not `auth`) to `/var/log/secure`.

To send a message yourself, `logger` is the classic tool; the opensuse image does not have it,
`systemd-cat` (on all seven systemd targets) writes to the journal directly:

```bash
ansible opensuse -b -m ansible.builtin.shell -a "echo hello from L15 | systemd-cat -t lesson15 && sleep 1 && journalctl -t lesson15 -n 1 --no-pager -o cat"
```

`-t` sets the identifier, and `journalctl -t` selects by it. Reading the system journal needs root
or membership in a group such as `systemd-journal`, hence `-b`.

### journald: files, drop-ins and the value in effect

journald reads one main file and then its drop-ins. Where the main file lives differs: debian,
ubuntu and arch have `/etc/systemd/journald.conf`; rocky, alma, fedora and opensuse only
`/usr/lib/systemd/journald.conf` (systemd 257 to 262 on the targets). Either way you do not edit
it - the drop-in directory `/etc/systemd/journald.conf.d/` is the place for your settings, and a
package can put its own drop-ins into `/usr/lib/systemd/journald.conf.d/`.

The rule that matters (`journald.conf(5)`): the drop-ins of all directories are sorted by **file
name**, regardless of the directory, and for a key with a single value the file read last wins.
Two consequences:

- A vendor drop-in can win over yours. debian and ubuntu ship
  `/usr/lib/systemd/journald.conf.d/syslog.conf` (package `systemd`) with `ForwardToSyslog=yes`;
  `syslog.conf` sorts after a file called `60-something.conf`, so its value is the one in effect.
  opensuse ships `20-defaults-SUSE.conf` with `Audit=no`.
- A file in `/etc` with the **same name** as a vendor file replaces it, and a symlink with that
  name to `/dev/null` removes it ("masking"). This is the documented way to switch off a vendor
  file without touching `/usr`, where the next package update would undo your edit.

You do not have to work the order out by hand. `systemd-analyze cat-config` prints every file in
the order journald reads it, each after a `# /path` line:

```bash
ansible 'targets:!alpine' -m ansible.builtin.shell -a "systemd-analyze cat-config systemd/journald.conf | grep -E '^# /.*[.]conf$|^[A-Za-z]+='"
```

On a fresh debian the output ends with `# /usr/lib/systemd/journald.conf.d/syslog.conf` and
`ForwardToSyslog=yes`; on rocky it shows the main file with `Audit=` and nothing else. The last
line for a key is its value in effect - that is also how the check of 4.09 reads it. A masked file
appears as its `# /etc/...` line with nothing below it.

### Where the journal is stored: Storage, flush and size

`Storage=` decides where the journal lives: `volatile` (in `/run/log/journal`, lost at shutdown),
`persistent` (in `/var/log/journal`), `auto` (persistent if `/var/log/journal` exists, else
volatile) and `none`. The default is `auto`, so the directory decides. On the fresh targets it
exists on debian, ubuntu, fedora, opensuse and arch, and is missing on rocky and alma: their
journal is volatile.

Changing `Storage=` and restarting journald is not the whole story. At boot `/var` may not be
mounted yet, so journald starts in `/run` and waits until `systemd-journal-flush.service` asks it
to move (`journalctl --flush`). Measured on rocky and alma with `Storage=persistent` in a drop-in:

```
systemctl restart systemd-journald   ->  Runtime Journal (/run/log/journal/...) is 8M, max 796.5M, 788.5M free.
journalctl --flush                   ->  Received client request to flush runtime journal.
                                         (/var/log/journal/<machine-id>/system.journal exists now)
systemctl restart systemd-journald   ->  System Journal (/var/log/journal/...) is 8M, max 4G, 3.9G free.
```

The flush created `/var/log/journal` and left the flag file `/run/systemd/journal/flushed`; with
that flag a later restart goes to `/var` directly. Like every file under `/run`, the flag is gone
after a reboot, when the boot-time flush runs again.

The lines above come from journald itself: after a start it logs which journal it uses, its size
and its limit. `journalctl -u systemd-journald -n 1 --no-pager -o cat` (as root) shows the newest
one - the easiest proof that a size setting took effect. The limit is `SystemMaxUse=` for the
persistent journal and `RuntimeMaxUse=` for the volatile one; their defaults are a share of the
file system with an upper bound (`journald.conf(5)`), which gave "max 4G" on the lab's large
virtual disk. `Compress=` defaults to `yes`; `journalctl --header` lists the flags of a file, and
every journal file on the targets showed `COMPRESSED-ZSTD`.

Setting a default explicitly is still worth it: the value then no longer depends on the
distribution, and an audit can find it.

### rsyslog: rules, two syntaxes and a check of the whole configuration

`/etc/rsyslog.conf` has three parts: modules (inputs such as `imjournal`, `imuxsock`, `imtcp`),
global settings, and rules - a *selector* (`facility.priority`) followed by an *action* (usually
a file). An `include` of `/etc/rsyslog.d/*.conf` pulls in drop-ins at the point where it stands;
on all four families that have rsyslog it stands before the rules. Two syntaxes are in use, and
the targets show both:

```
$FileCreateMode 0640                                    # legacy directive (debian, opensuse)
*.info;mail.none;authpriv.none;cron.none  /var/log/messages               # legacy rule (fedora)
*.info;mail.none;authpriv.none;cron.none  action(type="omfile" file="/var/log/messages")   # el10
```

The difference is more than looks. A legacy directive such as `$FileCreateMode` applies to the
legacy rules that *follow* it, and legacy directives do not affect RainerScript objects such as
`action(...)` (rsyslog's `omfile` documentation). Measured with a drop-in `$FileCreateMode 0400`:
a fresh `/var/log/messages` got 0400 on fedora and 0600 on rocky. The 0600 comes from somewhere
else - the RedHat `rsyslog` unit sets `UMask=0066` - which is also why every rsyslog file there was
already 0600. A configuration line and the mode of the file are two different facts; check both.

How do you know a configuration is valid before you restart? `rsyslogd -N1` parses everything,
includes and modules, and exits 1 on an error. Measured on rocky and fedora with three broken
drop-ins:

```
bogus_directive_xyz        -N1 exit 1   restart ok, active
module(load="imnotthere")  -N1 exit 1   restart ok, active
$FileCreateMode 0640x      -N1 exit 1   restart ok, active
```

rsyslog started every time and only logged its complaint. A restart is no test.

[L02](L02-safe-changes.md) showed `validate:`, which checks a file before it replaces the old one.
It does not fit here: `rsyslogd -N1 -f <file>` checks the file as if it were the *whole*
configuration, and a correct drop-in has no actions - exit 1, "no active actions configured". The
other way is a task that checks the whole configuration *after* the file was written and before
anything restarts. If it fails, the host fails, and the handlers it had notified do not run
(unless you set `force_handlers`). The price: the broken file stays on disk until you fix it, and
the next restart for any reason picks it up.

Two more parts of rsyslog matter for the benchmark: no network input unless the host is meant to
collect logs (`imtcp`, `imudp` in a `module(...)` or `$ModLoad` line; none was active on
rocky, alma and fedora after the install), and rotation - rsyslog writes
plain files, `logrotate` rotates them.

### Handlers that belong together: `listen`

A handler runs once at the end of the play when a task that `notify`-ed it reported `changed`
([L02](L02-safe-changes.md)). Some changes need more than one action afterwards - restart a
daemon, then tell it something, then test it. You can `notify` a list of handler names, but every
task that causes the change must then repeat the list. `listen:` turns it around: several handlers
listen to one topic, and a task notifies the topic.

```yaml
- name: Handlers that listen to one topic
  hosts: debian
  become: true
  handlers:
    - name: Restart journald
      ansible.builtin.systemd_service:
        name: systemd-journald
        state: restarted
      listen: lesson journald changed

    - name: Say what happened
      ansible.builtin.debug:
        msg: "journald on {{ inventory_hostname }} was restarted"
      listen: lesson journald changed
  tasks:
    - name: Drop-in directory of journald
      ansible.builtin.file:
        path: /etc/systemd/journald.conf.d
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Keep the journal for one month at most
      ansible.builtin.copy:
        dest: /etc/systemd/journald.conf.d/90-lesson.conf
        content: |
          [Journal]
          MaxRetentionSec=1month
        owner: root
        group: root
        mode: "0644"
      notify: lesson journald changed
```

The first run creates the directory - it is missing on a fresh debian, ubuntu, rocky, alma,
fedora and arch - and the file, and runs both handlers once; the second changes nothing and runs
none.
Handlers run in the order of the `handlers:` section, not in the order of the notifications, so
the section is where you define "first restart, then the rest". `./lab.sh reset debian` on the
host removes the example again.

### BusyBox syslogd and OpenRC

Alpine's `syslogd` is part of BusyBox; the OpenRC service is called `syslog`. Its options come from
`SYSLOGD_OPTS` in `/etc/conf.d/syslog` (`-t` on a fresh target: strip the timestamps that clients
send); the init script starts `/sbin/syslogd ${SYSLOGD_OPTS} -n`. It rotates on its own: `-s`
is the size in KB at which `/var/log/messages` is rotated (default 200), `-b` the number of old
files kept (default 1), `-R host:port` forwards to a remote host (BusyBox 1.37, `syslogd --help`).

On a fresh alpine `syslogd` runs, yet `rc-update show` lists it in no runlevel:

```bash
ansible alpine -m ansible.builtin.command -a "rc-update show default"
ansible alpine -m ansible.builtin.shell -a "ps -o args | grep '[s]yslogd'"
```

OpenRC started it because other services depend on it: `crond` has `need logger`, `sshd` has `use
logger`, and `syslog` provides `logger` (`rc-status -a` lists it under "needed/wanted"). Running is
not the same as enabled: OpenRC starts it only as long as something depends on it.
`ansible.builtin.service` with `enabled: true` adds a service to the runlevel `default` on OpenRC,
just as it enables a unit on systemd. The dependency works in the other direction too: restarting
`syslog` also stopped and started `crond` (measured).

## CIS background

Section 6.2 of the current benchmarks covers system logging ([the control
catalogue](../../cis-catalogue/controls.yml): 6.2, Level 1). In our own words, the
recommendations want: one logging service chosen and running; journald with persistent storage,
compression and size limits; if rsyslog is the chosen logger, the package installed, the service
enabled, journald handing messages over, restrictive modes for new log files, no reception of
remote messages unless the host is a log collector, and rotation in place; and the files under
`/var/log` readable only by those who need them. Forwarding to a central host is part of it, with
the destination left to you.

The reason is simple: a log that an attacker can read tells them what you can see, a log they
can write is no evidence, and a log that fills the disk stops the host. The trade-offs are size
against history, local against central, and one daemon against two. The benchmarks for different
distributions differ in which logger they expect by default and in the numbers of the
recommendations; look them up in the PDF of your distribution.

## Platform differences

| os_family | Hosts | Logger in the image | journald main file | Journal on a fresh target | Vendor journald drop-in | rsyslog package |
|---|---|---|---|---|---|---|
| Debian | debian, ubuntu | journald only | `/etc/systemd/journald.conf` | persistent | `syslog.conf`: `ForwardToSyslog=yes` | 8.2504 / 8.2512, brings `logrotate`; `$FileCreateMode 0640`, group `adm` |
| RedHat | rocky, alma / fedora | journald only | `/usr/lib/systemd/journald.conf` | volatile / persistent | none | 8.2604, `imjournal`, unit `UMask=0066`, files 0600 |
| Suse | opensuse | journald only (no `logger`) | `/usr/lib/systemd/journald.conf` | persistent | `20-defaults-SUSE.conf`: `Audit=no` | 8.2608, pulls `syslog-service`; `$FileCreateMode 0640` |
| Alpine | alpine | BusyBox `syslogd`, in no runlevel | - | - | - | 8.2608 in the package index |
| Archlinux | arch | journald only | `/etc/systemd/journald.conf` | persistent | none | not in the repositories (`syslog-ng` 4.12 is) |

After an install rsyslog was enabled but not started on debian, ubuntu, rocky, alma, fedora and
opensuse. The
journal files were 0640 `root:systemd-journal` on every host with a persistent journal; on rocky
and alma the files that the flush created were `root:root`. `systemd-journald.service(8)`
suggests `systemd-tmpfiles --create --prefix /var/log/journal` to give a new journal directory its
proper owner and mode.

### In the lab containers

Nothing in this lesson touches the host kernel: journald, rsyslog and syslogd run in the
containers as they do on a virtual machine, and each target has its own machine id and journal.
Two differences: the default size limits are computed from the container's file system, which is
the large virtual disk of Docker (hence "max 4G"), and `./lab.sh reset` throws every log away
together with the container. The Docker host's own logging is not affected.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Your drop-in says `no`, the daemon behaves like `yes` | a vendor drop-in sorts after yours | read `systemd-analyze cat-config`; replace or mask the vendor file |
| `Storage=persistent` and still "Runtime Journal" | journald moves to `/var` only on a flush request | `journalctl --flush` after the restart |
| `validate:` rejects a correct rsyslog drop-in | `-N1 -f` treats the file as the whole configuration | check the whole configuration after writing, before restarting |
| rsyslog is `active`, the new line has no effect | rsyslog starts with errors and only logs them | `rsyslogd -N1`, and read rsyslog's own messages |
| A file mode line is set, the files have another mode | the unit's umask, or a legacy line before `action()` rules | check the files themselves |
| A message is missing from the file you expected | the rule uses another facility (`auth` vs `authpriv`) | read the selectors of the rules |
| `logger: command not found` | not every image has it (opensuse) | `systemd-cat` on systemd hosts |
| syslogd runs on Alpine, but not after a reboot | it was started as a dependency, not from a runlevel | enable it (`rc-update add`, or `service` with `enabled: true`) |
| `Destination directory /etc/systemd/journald.conf.d does not exist` | only opensuse ships the directory in `/etc` | create it with `ansible.builtin.file` first |
| `journalctl` shows nothing or only your own messages | the system journal needs root or a log group | `-b`, or membership in `systemd-journal` |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [4.09](../../exercises/stage4-advanced/4.09-system-logging/README.md) | the three loggers and their paths, drop-in order and masking, flush, `rsyslogd -N1`, `listen`, OpenRC runlevels |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A drop-in `/etc/systemd/journald.conf.d/50-local.conf` sets `ForwardToSyslog=no`, yet the value
   in effect on debian is `yes`. Why, and what are two ways to fix it?

   <details><summary>Answer</summary>

   Drop-ins are sorted by file name across `/etc` and `/usr/lib`, and the vendor file `syslog.conf`
   sorts after `50-local.conf`, so its `yes` is read last and wins. Either give your setting a
   file that sorts later, or replace the vendor file with a file of the same name in `/etc`, or
   mask it with a `/dev/null` symlink of that name. `systemd-analyze cat-config` shows the result.

   </details>

2. On rocky you set `Storage=persistent` and restart journald, but `/var/log/journal` stays
   missing. What is journald waiting for, and why does the same restart work on fedora?

   <details><summary>Answer</summary>

   For a flush request (`journalctl --flush`, which the boot sends via
   `systemd-journal-flush.service`): until then it keeps the runtime journal in `/run`. fedora
   already has `/var/log/journal`, so the flush at boot moved its journal there, and a restart
   writes to `/var` at once; the flag file `/run/systemd/journal/flushed` records the flush.

   </details>

3. Why can `validate:` not check an rsyslog drop-in, and what do you give up when you check the
   whole configuration in a task after writing the file instead?

   <details><summary>Answer</summary>

   `rsyslogd -N1 -f <file>` checks the file as a complete configuration, and a drop-in on its own
   has no actions, so even a correct one fails. A later task checks the real, merged
   configuration and stops the host before the restart handler runs, but the broken file is
   already on disk and stays there until it is fixed.

   </details>

4. On the RedHat family journald has `ForwardToSyslog=no`, yet rsyslog writes every message to
   `/var/log/messages`. How does it get them?

   <details><summary>Answer</summary>

   Its `imjournal` input reads the journal files directly, like `journalctl`; the forwarding
   socket is not involved (the local socket input is switched off). On debian, where rsyslog
   loads `imuxsock`, it would need the forwarded copy.

   </details>

5. Two handlers listen to the same topic. The task that notifies the topic comes after a task that
   notifies the second handler by name. In which order do they run?

   <details><summary>Answer</summary>

   In the order of the `handlers:` section, once each, at the end of the play (or at
   `meta: flush_handlers`). The order of the notifications does not matter.

   </details>

6. `ps` shows `syslogd` on a fresh alpine, but `rc-update show` does not list `syslog`. Is it
   enabled?

   <details><summary>Answer</summary>

   No. OpenRC started it because `crond` needs `logger` and `sshd` uses it, and `syslog`
   provides `logger`. It is not in a runlevel, so it starts only as long as something depends on
   it; `rc-update add syslog default` (or `service` with `enabled: true`) enables it.

   </details>

## Further reading

- [journald.conf(5)](https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html) - `Storage=`, `Compress=`, `SystemMaxUse=`, `ForwardToSyslog=`, the order of the drop-ins
- [systemd-journald.service(8)](https://www.freedesktop.org/software/systemd/man/latest/systemd-journald.service.html) - sockets, the flush to `/var`, the journal directory
- [systemd-analyze(1)](https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html) - `cat-config`
- [rsyslog: omfile](https://docs.rsyslog.com/doc/configuration/modules/omfile.html) - `fileCreateMode`, legacy directives and RainerScript
- [rsyslog: $FileCreateMode](https://docs.rsyslog.com/doc/configuration/action/rsconf1_filecreatemode.html) - the legacy directive and its position
- [BusyBox commands](https://busybox.net/downloads/BusyBox.html) - `syslogd`, `logread`
- [Handlers: running operations on change](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html) - `notify`, `listen`, order, `force_handlers`
- [`ansible.builtin.find`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/find_module.html) - `contains:`
- [`ansible.builtin.service`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/service_module.html) - `enabled` on systemd and OpenRC
- [Glossary](../GLOSSARY.md) - terms of this lesson: `ForwardToSyslog`, journald, `listen`,
  mask (drop-in), rsyslog, syslogd (BusyBox)
