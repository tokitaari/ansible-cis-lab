# 2.05 - Job schedulers: cron permissions and access

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 2 - Building blocks | ★★★☆☆ | ~45 min | 2.4 Job schedulers (L1) | `targets` |

**Concepts:** `per-family service names`, `stat loops`, `conditional resources`, `N/A handling`

## Goal

Harden cron on all eight hosts - with three different cron implementations and four different service names.

## Background

Cron runs commands as root on a schedule. Writable cron files = persistent root
access for an attacker. CIS asks for:

- the cron daemon is enabled and running (scheduled maintenance must work),
- `/etc/crontab` is `0600 root:root`,
- `/etc/cron.hourly`, `cron.daily`, `cron.weekly`, `cron.monthly`, `cron.d` are `0700 root:root`,
- `/etc/cron.allow` exists (`0640 root:root`) - only listed users may use `crontab`.

Reality check:

| Family | Implementation | Service |
|---|---|---|
| Debian | Vixie/Debian cron | `cron` |
| RedHat | cronie | `crond` |
| Suse | cronie | `cron` |
| Archlinux | cronie | `cronie` |
| Alpine | busybox crond | `crond` |

Alpine has no `/etc/crontab` and no `cron.*` directories (it uses `/etc/crontabs/`
and `/etc/periodic/`), and busybox `crontab` ignores `cron.allow`.

## Requirements

- [ ] A dict maps `os_family` → cron service name; the service is `started` and `enabled`.
- [ ] For every path in the list that **exists**, set the CIS permissions (file `0600`, directories `0700`, `root:root`).
- [ ] Create `/etc/cron.allow` (`0640 root:root`, content `root`) on all families except Alpine.
- [ ] On Alpine, apply the same intent: `/etc/crontabs` `0700 root:root`.
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 2.05            # creates /lab/work/2.05/
cd /lab/work/2.05
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 2.05            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 2.05 1` (gentle) ... `lab hint 2.05 3` (almost the answer).  
Passed? Read `lab explain 2.05` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- CIS also mentions `/etc/cron.deny`. With `cron.allow` present, `cron.deny` is ignored - remove it to avoid confusion.
- `at` is another scheduler (`/etc/at.allow`). Which hosts have it installed?
