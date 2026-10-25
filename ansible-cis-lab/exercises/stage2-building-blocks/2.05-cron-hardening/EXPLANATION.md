# 2.05 - Job schedulers: cron permissions and access: Explanation

### Solution
See `lab solution 2.05`. The structure:
1. `stat` all candidate paths (list of `{path, mode}` dicts),
2. `file` with `when: item.stat.exists` - paths that do not exist are skipped, not created,
3. `cron.allow` via `copy`, skipped on Alpine,
4. service enabled/started with a name lookup.

### Why not `state: directory` for all cron dirs?
Creating directories that the installed cron does not read would only *look* compliant
to a scanner. Harden what exists; do not fabricate configuration.

### N/A is a legitimate result
A control can be *not applicable* (busybox crontab has no allow-list). Write down why
(comment, exception list) and apply the closest equivalent control (`/etc/crontabs`
0700). Auditors accept a documented N/A; they do not accept silence.

### `cron.allow` content
`root` alone means only root may run `crontab -e`. Service accounts that need user
crontabs must be listed. In practice prefer `/etc/cron.d/<app>` files deployed by
configuration management - visible, reviewable, versioned.

### Lesson about variability
Four service names for "cron" across five families. Facts + data structures keep
the playbook readable. In stage 4 you move these into `vars/<family>.yml` of a role.

## Reference solution

Show it with `lab solution 2.05`, apply it with `lab solve 2.05`.
