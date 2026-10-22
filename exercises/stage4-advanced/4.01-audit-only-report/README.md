# 4.01 - Audit-only compliance report

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★☆ | ~75 min | cross-section (L1) | `targets` |

**Concepts:** `read-only plays`, `check_mode: false on readers`, `hostvars aggregation`, `to_nice_json`

## Goal

Write a playbook that changes *nothing* on the targets, evaluates ten controls per host and produces a JSON and Markdown compliance report on the control node.

## Background

Before you remediate production systems, you measure them. Auditors want evidence,
change managers want to know the blast radius. A good audit play:
- uses only read-only modules (`stat`, `slurp`, `package_facts`, `service_facts`,
  read-only `command` with `changed_when: false`),
- never fails half-way because one control fails - it records `fail` and moves on,
- produces machine-readable output (JSON) plus something humans read (Markdown).

Try it on a freshly reset host (`./lab.sh reset debian`) and on a hardened one.

## Requirements

- [ ] Playbook `/lab/work/4.01/playbook.yml`. On the targets it must report `changed=0` - in normal mode and with `--check`.
- [ ] At least these ten controls per host, each with `id`, `title`, `status` (`pass`/`fail`/`n/a`):
  2.2 telnet not installed · 2.1 vsftpd not running/enabled · 7.1 /etc/passwd 0644 root:root · 7.1 shadow not readable by others · 5.1 PermitRootLogin no (effective) · 5.1 MaxAuthTries ≤ 4 · 5.2 sudo `use_pty` configured · 3.3 `net.ipv4.ip_forward` = 0 · 2.4 `/etc/cron.allow` exists (n/a on Alpine) · 5.4.2 root is the only UID 0 account
- [ ] `/lab/work/4.01/report.json`: an object keyed by host name, each value with `score` (percent of `pass` among pass+fail) and `results` (list).
- [ ] `/lab/work/4.01/report.md`: one table row per host with the score, plus a list of all failures.
- [ ] No `ignore_errors: true` anywhere.

## How to work

```bash
lab start 4.01            # creates /lab/work/4.01/
cd /lab/work/4.01
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 4.01            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.01 1` (gentle) ... `lab hint 4.01 3` (almost the answer).  
Passed? Read `lab explain 4.01` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Add a timestamp to the report. What does that do to the idempotency of the report file - and does it matter?
- Make the controls *data*: a list of `{id, title, expr}` where `expr` is a Jinja expression string evaluated per host. Is that elegant or too clever?
