# 5.02 - Rollout strategy: preflight, canary, batches: Explanation

### What the check verifies
`lab check 5.02` runs `check.sh` only; `meta.yml` says `idempotency: false`, so there is no
second run. The script reads `rollout.yml` as YAML and expects at least three plays,
`any_errors_fatal: true` in the first, a first `serial` play whose `serial` is a list of two or
more entries with `max_fail_percentage` 0, and the name `cis_rollout_confirm` somewhere in the
file. Then it runs the playbook once with `--check` and without the confirmation and expects a
failure whose log names `cis_rollout_confirm`.

Nothing is rolled out. The check does not look at the preflight tasks, the canary hosts, the
post-check or the real batch sizes, and it takes the first play with `serial` as *the* batch
play. Whether your rollout is safe is yours to judge: run it for real once.

### How it works

#### Why each piece exists
- **Preflight with `any_errors_fatal`**: if one host is broken before you start, you want a
  human to look - not a half-rolled-out fleet.
- **Confirmation variable**: hardening changes authentication and network rules. A required
  `-e cis_rollout_confirm=true` prevents "I only wanted to run check mode" accidents and
  appears in job logs.
- **Canary**: one host per major platform catches platform-specific breakage early.
- **`serial` + `max_fail_percentage: 0`**: a failure inside a batch stops the rest of the run
  (see *Batches*).
- **Post-check with a new connection**: the existing SSH master survives many breakages; only
  a *fresh* login proves that the next operator can still get in.

#### Preflight and the gate
"Reachable" and "Python present" are covered by fact gathering; a host without Python fails
there (Alpine before 0.02: `interpreter /usr/bin/python3 not found`). The confirmation is an
`assert` with `run_once`. It also runs under `--check`, so a dry run cannot skip the gate. The
read-only probes (`sshd -t`, `visudo -c`, `df`) need `check_mode: false`; otherwise `--check`
skips them and the preflight passes without looking.

#### Free space: what a host can know about itself
`ansible_facts.mounts` looks like the obvious source, but the facts keep a mount only if its
device starts with `/` or `\` or contains `:/` (NFS: `host:/export`), and they skip
`fstype none`. The `overlay` root of a container and `tmpfs` have none of that: in the lab
there is no entry for `/`, and a `default(0)` turns that into "0 MB free" on every host. With
`gather_subset: min` there is no `mounts` at all. `df -Pk /` asks the kernel instead and works
everywhere (`-P` is POSIX, also busybox; `-k` fixes the unit):
```yaml
- ansible.builtin.command: df -Pk /
  register: cis_df_root
  changed_when: false
  check_mode: false
- ansible.builtin.assert:
    that: (cis_df_root.stdout_lines[-1].split()[3] | int) * 1024 >= 209715200
```
Even the right number can mislead: with **thin provisioning** a host sees the free space of its
*virtual* disk, not of the storage behind it. In the lab the targets report the capacity of the
WSL2/Docker Desktop VHDX while the Windows drive holding it may be nearly full; qcow2 images,
thin LVM pools, VMware thin disks and SAN LUNs behave the same. The capacity of the backing
storage belongs to the monitoring of the platform.

#### Batches
A percentage in `serial` is a share of the hosts **in the play** (after `--limit`), rounded down,
at least one - not a share of the hosts that remain. The third play has six hosts in the lab
(eight minus two canaries), so `[1, "30%", "100%"]` makes batches of 1, 1 and 4 (measured). On
2,000 servers `[1, 10, "5%", "25%", "100%"]` gives 1, 10, 100, 500 and the remaining 1,389.

`max_fail_percentage: 0` does not stop a batch of one - if its only host fails, no host is left
and the run ends anyway. It works inside a batch with several hosts: without it the healthy
hosts of that batch go on (and the next batch starts); a batch in which every host fails ends
the run either way. The threshold is a share of the **batch** and the comparison is strict:
four hosts, two failed: 50 goes on, 49 stops; one failed: 25 goes on, 24 stops. An unreachable
host counts as failed. In the lab only the last batch (four hosts) shows the setting: with
`fedora` broken, `opensuse`, `arch` and `alpine` skip the next tasks and the post-check at `0`
and run them at `100`.

#### What runs per batch
Under `serial` the whole play runs once per batch: tasks, `post_tasks` and handlers. `run_once`
runs once per batch, on its first host. A failing `run_once` assert ends the run even without
`any_errors_fatal`, and `any_errors_fatal` on a block ends the whole play, not only the block.

#### Post-check
`meta: reset_connection` drops the persistent connection, so the next task logs in again.
`wait_for_connection` opens its own connection on every attempt (see 4.07) and succeeds only
when a login works; `sshd -T` then prints the effective settings. Match the keyword
case-insensitively: arch (OpenSSH 10.6) prints `PermitRootLogin no`, the other hosts print it
in lowercase.

#### Reports across batches
Under `serial`, `ansible_play_hosts` is **not** the current batch: it lists every host of the
play that has not failed, including the batches still to come. `ansible_play_batch` is the
current batch. A `run_once` report that reads `hostvars[h].cis_summary` for every
`ansible_play_hosts` entry therefore crashes in batch 1 (`has no attribute 'cis_summary'`) - the
5.01 role did exactly that until the rollout ran for real. `ansible_play_batch` would not
crash, but every batch would overwrite the report with only its own hosts. The 5.01 role reports
every host that already has a summary; `hostvars` survive across plays, so the canaries stay in
and the last batch writes the complete report:
```yaml
cis_report_hosts: "{{ groups['all'] | map('extract', hostvars) | selectattr('cis_summary', 'defined') | map(attribute='inventory_hostname') | sort }}"
```

### Per-family notes

| os_family | Hosts | `sshd` / `visudo` | `df` | Notes |
|---|---|---|---|---|
| Debian | debian, ubuntu | `/usr/sbin` | `/usr/bin` | `sshd -T` in lowercase |
| RedHat | rocky, alma, fedora | `/sbin` (rocky, alma), `/usr/sbin` (fedora) | `/bin` (rocky, alma), `/usr/sbin` (fedora) | `sshd -T` in lowercase |
| Suse | opensuse | `/usr/sbin` | `/usr/bin` | `visudo -c` exits 1 on a fresh host (`/usr/etc/sudoers` has mode 0444); the solution tolerates exactly that complaint (see 1.05) |
| Archlinux | arch | `/usr/bin` | `/usr/bin` | `sshd -T` prints `PermitRootLogin` |
| Alpine | alpine | `/usr/sbin` | `/bin` (BusyBox) | `df -Pk /` works; no Python before 0.02 (`requires`) |

The directories are what `command -v` printed (L14 measurement). The solution calls
`/usr/sbin/sshd` and `/usr/sbin/visudo` and passed on all eight hosts.

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| "only 0.0 MB free on /" on every host | the facts have no entry for the `overlay` root and `default(0)` hides it | read `df -Pk /` |
| `has no attribute 'cis_summary'` in batch 1 | `ansible_play_hosts` lists hosts of batches that have not run | report over the hosts that have a summary |
| batches differ from your calculation | a percentage counts the hosts of the play, rounded down; `--limit` shrinks the play | calculate from the play size |
| the run goes on after a failure | the default tolerates failures in a batch with several hosts | `max_fail_percentage: 0` (strict, share of the batch) |
| the preflight passes without checking | a read-only `command` is skipped under `--check` | `check_mode: false` |
| the post-check does not find `permitrootlogin` on arch | OpenSSH 10.6 prints the keyword in camel case | match with `(?i)` |
| the report bug never shows | `--check` does not reach the report with real data | test the rollout for real against a staging fleet |

### Real-world notes
- Choose canaries per platform and role, not by size; the point is one host of each kind that
  differs.
- After an aborted run the recap lists only the hosts that got that far: compare it with the
  host list and decide in advance how a half-finished batch is repaired (`--limit`, reset).
- `-e cis_rollout_confirm=true` stays visible in the job log - a trace of who confirmed what.
- Free space inside a host says nothing about the storage behind it; watch that in the
  platform's monitoring.

### Further reading
- Lesson [L14 - Production rollout](../../../docs/lessons/L14-production-rollout.md): failure semantics, `serial` lists, gates and probes, per-batch verification, with demos and self-check questions.
- Lesson [L13 - Host firewall with nftables](../../../docs/lessons/L13-host-firewall-nftables.md): why a fresh connection is the real test.
- Lesson [L10 - Compliance reporting](../../../docs/lessons/L10-compliance-reporting.md): where the report in the 5.01 role comes from.

## Reference solution

Show it with `lab solution 5.02`, apply it with `lab solve 5.02`.
