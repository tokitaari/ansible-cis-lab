# 4.09 - System logging: one logger per host, chosen by data

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★☆ | ~60 min | 6.2 System logging (L1) | `targets` |

**Concepts:** `choice by data + assert`, `systemd drop-ins and masking`, `whole-config check before restart`, `handlers with listen`, `service across systemd and OpenRC`

## Goal

Give every target exactly one fully configured system logger - journald, rsyslog or BusyBox syslogd, chosen per OS family from data - and make sure the settings are the ones in effect, not only the ones in your file.

## Background

The benchmark asks you to pick one logger per host and configure it completely. Which one is a
decision, so it belongs in data, not in a chain of `when:` conditions. In this exercise the choice
follows what the distributions do on a real install:

| Family | Logger | What you configure |
|---|---|---|
| Debian, Suse, Archlinux | journald only | a drop-in in `/etc/systemd/journald.conf.d/` |
| RedHat | rsyslog (it reads the journal) and journald | the `rsyslog` package, a drop-in in `/etc/rsyslog.d/`, the journald drop-in |
| Alpine | BusyBox `syslogd` (OpenRC service `syslog`) | `/etc/conf.d/syslog`, the runlevel |

A file you write is not yet the setting in effect: other files may be read after yours, a daemon
may need more than a restart, and a broken line may not stop a daemon from starting. Lesson L15
explains each of these; look at the targets before you write anything.

## Requirements

- [ ] The logger of each host comes from data: a dict keyed by `ansible_facts.os_family` with the values of the table. The play stops with a clear message when a host's value is not one of `journald`, `rsyslog`, `syslogd`.
- [ ] Every systemd host: your settings live in a drop-in under `/etc/systemd/journald.conf.d/`, and in effect (as `systemd-analyze cat-config systemd/journald.conf` lists them, the last value wins) they are `Storage=persistent`, `Compress=yes` and a size limit `SystemMaxUse=<n>` (`K`, `M`, `G` or `T` allowed); on the journald-only hosts also `ForwardToSyslog=no`. journald really writes to `/var/log/journal`.
- [ ] RedHat family: `rsyslog` installed, enabled and running; a drop-in in `/etc/rsyslog.d/` sets `$FileCreateMode 0640` (or stricter); the whole rsyslog configuration passes `rsyslogd -N1` before rsyslog is restarted; no network input (`imtcp`, `imudp`); `/var/log/messages` and `/var/log/secure` are no looser than 0640; a test message reaches `/var/log/messages`.
- [ ] Alpine: `syslog` is in the runlevel `default` and running, with the rotation options `-s <KB>` and `-b <n>` in `SYSLOGD_OPTS` of `/etc/conf.d/syslog`, and the running daemon uses them.
- [ ] A daemon is restarted only when its configuration changed (handlers). Second run: `changed=0`.

## How to work

```bash
lab start 4.09            # creates /lab/work/4.09/
cd /lab/work/4.09
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 4.09            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.09 1` (gentle) ... `lab hint 4.09 3` (almost the answer).  
Passed? Read `lab explain 4.09` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Give the Debian family rsyslog instead of journald only (on a reset host - `lab check` expects journald there). What must `ForwardToSyslog` be now, and why does the RedHat family not need it?
- `find /var/log -type f -perm /0137` lists the files looser than 0640. Which ones are they on a fresh target, who creates them, and which may you tighten without breaking a program?
- Forward the logs to a central host (rsyslog `omfwd`, or `systemd-journal-upload`). What protects the messages on the way, and what happens while the central host is down?
- rsyslog writes plain files. Which family rotates them, with which tool, and where is that configured?
