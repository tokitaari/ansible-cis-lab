# 5.02 - Rollout strategy: preflight, canary, batches: Explanation

### Why each piece exists
- **Preflight with `any_errors_fatal`**: if one host is broken before you start, you
  want a human to look - not a half-rolled-out fleet.
- **Confirmation variable**: hardening changes authentication and network rules. A
  required `-e cis_rollout_confirm=true` prevents "I only wanted to run check mode"
  accidents and appears in job logs.
- **Canary**: one host per major platform catches platform-specific breakage early.
- **`serial` + `max_fail_percentage: 0`**: a failure in batch 1 stops batch 2. Without
  `max_fail_percentage`, Ansible would happily continue with the next batch.
- **Post-check with a new connection**: the existing SSH master survives many breakages;
  only a *fresh* login proves that the next operator can still get in.

### Free space: what a host can know about itself
`ansible_facts.mounts` looks like the obvious source, but the facts skip every mount whose
device does not start with `/` - the `overlay` root of a container, `tmpfs`, many network
file systems. In the lab there is simply no entry for `/`, and a `default(0)` turns that into
"0 MB free" on every host. `df -Pk /` asks the kernel instead and works everywhere (`-P` is
POSIX, also busybox; `-k` fixes the unit):
```yaml
- ansible.builtin.command: df -Pk /
  register: cis_df_root
  changed_when: false
  check_mode: false
- ansible.builtin.assert:
    that: (cis_df_root.stdout_lines[-1].split()[3] | int) * 1024 >= 209715200
```
Even the right number can be misleading: with **thin provisioning** a host sees the free
space of its *virtual* disk, not of the storage behind it. In the lab the targets report
the capacity of the WSL2/Docker Desktop VHDX (up to 1 TB) while the Windows drive holding
it may have only a few GB left; the same applies to qcow2 images, thin LVM pools, VMware
thin disks and SAN LUNs. A preflight inside the host cannot see that - capacity of the
backing storage belongs to the monitoring of the platform.

### Reports across batches
Under `serial`, `ansible_play_hosts` is **not** the current batch: it lists every host of the
play that has not failed, including the batches still to come. `ansible_play_batch` is the
current batch. A report task with `run_once` that reads `hostvars[h].cis_summary` for every
`ansible_play_hosts` entry therefore crashes in batch 1 (`has no attribute 'cis_summary'`) -
the 5.01 role did exactly that until the rollout ran for real. `ansible_play_batch` would not
crash, but every batch would overwrite the report with only its own hosts.

The 5.01 role reports every host that already has a summary. `hostvars` survive across plays
of one run, so the canary hosts stay in, and the last batch writes the complete report:
```yaml
cis_report_hosts: "{{ groups['all'] | map('extract', hostvars) | selectattr('cis_summary', 'defined') | map(attribute='inventory_hostname') | sort }}"
```
`--check` (and the 5.02 check) never reaches this point with real data, so only a real run
shows the bug - test rollout playbooks against a staging fleet, not just in check mode.

### Dry runs
`--check` still runs preflight (read-only commands with `check_mode: false`), so you
can test the gate logic without touching hosts.

### Batch sizes
`serial: [1, "30%", "100%"]` means 1 host, then 30 % of the remaining hosts, then
the rest. For 2,000 servers you might use `[1, 10, "5%", "25%", "100%"]` - the idea is
to grow confidence before growing blast radius.

## Reference solution

Show it with `lab solution 5.02`, apply it with `lab solve 5.02`.
