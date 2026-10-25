# 4.08 - File integrity with AIDE - long-running tasks

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★☆ | ~60 min | 6.1 Filesystem integrity checking (L1) | `debian_family:redhat_family` |

**Concepts:** `async / poll / async_status`, `creates for idempotency`, `systemd timers via templates`

## Goal

Install AIDE, build the initial database on five hosts in parallel without blocking Ansible for minutes, and schedule a daily integrity check with a systemd timer.

## Background

AIDE records hashes and attributes of system files; later checks reveal changes
(rootkits, unauthorised edits). Building the first database scans the whole
filesystem - minutes per host. A normal task would hold the SSH connection the whole
time (and may hit timeouts). `async` + `poll: 0` starts the job in the background;
`async_status` collects results later.

| Family | Packages | Config | Init | Database |
|---|---|---|---|---|
| Debian | `aide`, `aide-common` | `/etc/aide/aide.conf` | `aideinit -y -f` | `/var/lib/aide/aide.db` |
| RedHat | `aide` | `/etc/aide.conf` | `aide --init` + move `aide.db.new.gz` → `aide.db.gz` | `/var/lib/aide/aide.db.gz` |

## Requirements

- [ ] Install the packages per family (dict).
- [ ] Initialise the database with `async` (e.g. 1800 s) and `poll: 0`, then wait with `ansible.builtin.async_status` (`until` loop). The init must be skipped when the database exists (`creates:`).
- [ ] Templated units `cis-aidecheck.service` (oneshot, runs `aide --check` with the family's config) and `cis-aidecheck.timer` (daily, `Persistent=true`); timer enabled and started; `daemon_reload` when units change.
- [ ] Second run: `changed=0` and no second scan.

## How to work

```bash
lab start 4.08            # creates /lab/work/4.08/
cd /lab/work/4.08
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 4.08            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.08 1` (gentle) ... `lab hint 4.08 3` (almost the answer).  
Passed? Read `lab explain 4.08` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Debian ships its own `dailyaidecheck.timer`. Would you use it instead? What would you have to verify?
- Exclude volatile paths (`/var/log`, `/var/cache`) with a drop-in instead of editing the main config.
- What happens to the AIDE baseline after every patch run? How do you integrate `aide --update` into your patching playbook?
