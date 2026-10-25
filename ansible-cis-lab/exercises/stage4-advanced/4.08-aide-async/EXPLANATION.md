# 4.08 - File integrity with AIDE - long-running tasks: Explanation

### async in three lines
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
All five hosts start their scan within seconds; the wait loop then collects them.
With `poll: 15` instead of `0` Ansible would block per host but keep the connection
short-lived - also valid, less parallel.

### creates = idempotency for commands
`creates: /var/lib/aide/aide.db` → the command is skipped when the file exists. In
check mode Ansible can evaluate it, so `--check` shows `skipped`, not `changed`.

### Timers instead of cron
systemd timers log to the journal, support `Persistent=true` (run missed jobs after
downtime) and can be listed (`systemctl list-timers`). CIS accepts either cron or a
timer for the periodic check.

### Operational reality
AIDE without a process is noise: after every patch run the baseline must be updated,
and alerts must reach someone. The tool is easy - the process around it is the work.

## Reference solution

Show it with `lab solution 4.08`, apply it with `lab solve 4.08`.
