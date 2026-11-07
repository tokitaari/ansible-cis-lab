# 4.08 - File integrity with AIDE - long-running tasks: Explanation

### What the check verifies
`lab check 4.08` runs `check.yml` on the five hosts and then your playbook once more with `--check`,
expecting `changed=0` (`meta.yml` says `idempotency: true`). `check.yml` asserts two things: the
database file exists (`aide.db` on Debian, `aide.db.gz` on RedHat) and `systemctl is-enabled
cis-aidecheck.timer` says `enabled`.

It does not test that `async` was used (a plain blocking command passes, and so does an empty file
at the database path), what the database holds, the text of the unit files, that the timer is
active, or that the unit runs. The second run is what catches the trap of `poll: 0` together with
`creates:`: the start task would be `changed` again. Measured on the lab with the reference
solution: the first run shows `changed=5` on all five hosts, the second run and `--check` show
`changed=0` with the start and wait tasks skipped.

### How it works

#### async in three lines
```yaml
- command: aide --init ...
  async: 1800      # max runtime
  poll: 0          # do not wait - fire and forget
  register: job
- async_status: jid="{{ job.ansible_job_id }}"
  register: r
  until: r.finished
  retries: 120
  delay: 15
```
All five hosts start their scan within seconds; the wait loop then collects them. `retries` times
`delay` (120 × 15 s) should cover `async`: if the loop gives up first, the task fails while the job
keeps running. On the lab the scans took 9 to 89 seconds (table below).

`poll: 0` is not what makes the hosts run in parallel. With `poll: 15` Ansible waits per host and
polls every 15 seconds; hosts still run side by side as long as `forks` allows. Lesson L09
measured four hosts with a 3-second job (single runs): foreground 3.9 s, `poll: 0` plus wait loop
5.1 s at `forks=10`; 7.1 s, 5.9 s and (`poll: 1`) 9.1 s at `forks=2`. The lab uses `forks = 10` for
five hosts, so the poll value changes nothing here; background jobs pay off with more hosts than
`forks`, with other work in the play, or when the job must outlive a connection.

#### creates is not enough with poll: 0
`creates: /var/lib/aide/aide.db` normally makes a command idempotent: skipped when the file
exists. With `poll: 0`, however, the task result is only "job started" - `changed`, every
run. The module (and its `creates:` test) runs later in the background, and nobody looks at its
result. So decide *before* starting the job:
```yaml
- ansible.builtin.stat:
    path: /var/lib/aide/aide.db
  register: db
- ansible.builtin.command:
    cmd: aideinit -y -f
    creates: /var/lib/aide/aide.db
  async: 1800
  poll: 0
  register: job
  when: not db.stat.exists
```
Now the second run shows `skipped`, the wait task skips too (no job id), and on the first run
`async_status` reports the real result. On a host without a database, `--check` shows the start
and the wait task as `changed` and creates nothing (measured).

`creates:` in the job is only a last guard. A long scan does not create the database until the
end, so a second run that starts while the first scan is still running finds no database, passes
the `stat` and starts a second scan (measured with a stand-in job: both jobs ran). Do not start
the play twice at the same time against the same hosts.

#### Timers instead of cron
systemd timers log to the journal, support `Persistent=true` (run missed jobs after downtime) and
can be listed (`systemctl list-timers`). CIS accepts either cron or a timer for the periodic
check. The solution adds `RandomizedDelaySec=30min`, so many hosts do not start at the same
moment.

#### The check command and its exit code
`aide --check` returns the sum of 1 (added), 2 (removed) and 4 (changed) files, so any
difference gives a non-zero code (L09). Measured right after the init on the lab, the command of
the unit exited with 7 on debian and ubuntu (11 added, 5 removed, 7 or 8 changed) and with 5 on
rocky, alma and fedora (4 added, 1 or 2 changed): the containers change files between init and
check. A `Type=oneshot` unit whose command exits non-zero counts as failed (`systemd.service(5)`,
not tried here), so the first daily run ends `failed` until the baseline is updated.

### Per-family notes
| `os_family` | Hosts | Init | Database (size) | Init time | Left behind | Include lines |
|---|---|---|---|---|---|---|
| Debian | debian, ubuntu | `aideinit -y -f` | `/var/lib/aide/aide.db` (4.1 MB, 3.5 MB) | 29 s, 89 s | `aide.db.new`, `/var/log/aide/aideinit.log` | `@@x_include /etc/aide/aide.conf.d ^[a-zA-Z0-9_-]+$` |
| RedHat | rocky, alma, fedora | `aide --init` + `mv` | `/var/lib/aide/aide.db.gz` (0.9, 0.8, 1.1 MB) | 12 s, 9 s, 14 s | `/var/log/aide/aide.log` | none, only `@@define` lines |

Measured on the lab with AIDE 0.19.1 (debian) and 0.19.2 (the others), one run. Debian's wrapper
`aideinit` runs `aide --init` with `/etc/aide/aide.conf`, and `-y` overwrites the output file, `-f`
the database; it copies, so `aide.db.new` stays next to `aide.db`. Debian and Ubuntu ship their own
`dailyaidecheck.timer`, the RedHat family ships none (L09). The timer was `enabled` and `active` on
all five hosts.

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| The start task is `changed` on every run | `poll: 0` reports "started"; `creates:` runs later in the job | `stat` first, `when: not ....stat.exists` |
| Two scans run at once | a second run started while the first scan had not created the database | do not overlap runs |
| `FAILED - RETRYING` lines | the wait loop has not seen `finished` yet | nothing - it fails only when the retries are used up |
| `[WARNING]: Module invocation had junk after the JSON data` | a terminal escape sequence in the job output | harmless, see `docs/TROUBLESHOOTING.md` |
| The unit is `failed` right after the init | the check found differences (exit code 1 to 7) | update the baseline after reading the report |
| A drop-in `99_local.conf` in `/etc/aide/aide.conf.d` has no effect | Debian reads only names matching `^[a-zA-Z0-9_-]+$` (measured: a file with a dot is ignored without a message) | name it `99_local` |
| Job files stay in `/root/.ansible_async` | nobody collects with `mode: cleanup` (L09) | not needed in the lab |

### Real-world notes
- AIDE without a process is noise: after every patch run the baseline must be updated, and alerts
  must reach someone. Read the report first, then update and promote the new database (L09). The
  tool is easy - the process around it is the work.
- To leave volatile paths out, Debian takes a drop-in in `aide.conf.d`; on the RedHat family you
  edit `/etc/aide.conf` or add an include line of your own.
- Keep a copy of the baseline off the host: an attacker with root can rewrite the database too.

### Further reading
- Lesson [L09 - Auditing and integrity](../../../docs/lessons/L09-auditing-and-integrity.md): the AIDE database, exit codes, timers and units, `async` and the idempotency trap - the concepts before this exercise.
- Exercise [3.04 - auditd: rules and log retention](../../stage3-intermediate/3.04-auditd-rules/README.md): the first half of the lesson.

## Reference solution

Show it with `lab solution 4.08`, apply it with `lab solve 4.08`.
