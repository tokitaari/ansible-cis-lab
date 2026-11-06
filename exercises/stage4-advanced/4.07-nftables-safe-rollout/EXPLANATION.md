# 4.07 - Host firewall with nftables - safe rollout: Explanation

### What the check verifies
`lab check 4.07` runs `check.yml` on the seven hosts, then your playbook once more with `--check`
and expects `changed=0`. `check.yml` asserts:
- `nft list table inet cis_filter` succeeds, and its output contains the input hook with
  `policy drop`, `tcp dport 22`, `ct state established,related accept` and the forward hook with
  `policy drop`.
- The distribution's persistence file (Debian and Arch `/etc/nftables.conf`, RedHat
  `/etc/sysconfig/nftables.conf`, Alpine `/etc/nftables.nft`) contains the `include` of
  `/etc/cis/nftables-cis.nft` and no `flush ruleset` line.

It does not test the SSH source range, the ICMP rules, the output policy, the enabled service or
the dead-man switch. Those are yours to get right; the `--check` pass only shows that a second run
would change nothing.

### How it works

#### The dead-man switch, step by step
1. Template + `validate: nft -c -f %s` → syntax errors never reach the host.
2. Start `sleep 60; nft delete table ...` in the background. `nohup` and the redirects are
   hygiene: in tests a job started with a plain `&`, with `nohup` and redirects, and with
   `async` + `poll: 0` all survived the death of the SSH master.
3. Load the rules.
4. `meta: reset_connection` closes Ansible's persistent SSH master, so the tasks after the test
   open a new connection under the new rules. It is not what makes the test honest:
   `wait_for_connection` opens its own connection on every attempt. Measured with new
   connections dropped, it timed out with and without a reset, while an ordinary `ping` still
   answered over the old connection (`established,related` keeps it alive) - which is why a
   plain `ping` is no test.
5. `wait_for_connection` with `timeout: 20`. Success → `kill` the rollback. Failure → the play
   fails for this host, and 60 s later the table is gone again.

The timeout must stay well below the rollback delay (default of the module: 600 s). Measured
with a 15 s rollback: with `timeout: 5` the task failed as intended (`timed out waiting for ping
module test`); with `timeout: 40` it turned green after 18 s, because the rollback had deleted
the table and SSH worked again - the rollback itself passed the test. A single attempt against a
dropping firewall also blocks on its own (11 s with `timeout: 5`), so leave a margin: the
solution uses 20 against 60.

#### Own your table
`flush ruleset` is the default in many distribution templates. In shared kernels and
namespaces it removes other owners' rules. A dedicated table plus `delete table` keeps your
changes atomic and contained. Measured on the debian target: before the flush `nft list tables`
showed `ip nat` (Docker) and `inet cis_filter`; after it, nothing, and the target could no longer
resolve the name of another container. On a Docker host you would break every container's
networking. `./lab.sh reset <host>` restores a target.

#### Why not restart nftables.service
A restart is a stop plus a start, and the stop of most packaged units flushes. Enabling is
enough: at boot the service loads your include. Do not trust the unit's name - read it
(`systemctl cat nftables.service`, on Alpine `/etc/init.d/nftables`); the table below is what the
lab images contain.

#### Re-applying after restarts
The file can be unchanged while the kernel state is gone (container or host restart
without the service). Checking the *live* state (`nft list table`) closes that gap -
the same idea as "verify the effect, not the file" from 1.01 and 1.03.

### Per-family notes

| os_family | Hosts | Persistence file | Init and unit | Stop and reload |
|---|---|---|---|---|
| Debian | debian, ubuntu | `/etc/nftables.conf` | systemd, `Type=oneshot`, `RemainAfterExit=yes` | `ExecStop` is `nft flush ruleset`; `ExecReload` loads the file |
| RedHat | rocky, alma, fedora | `/etc/sysconfig/nftables.conf` | systemd, `Type=oneshot`, `RemainAfterExit=yes` | `ExecStop` and `ExecReload` both start with `flush ruleset` |
| Suse | opensuse | - | systemd | excluded: firewalld is the usual frontend |
| Archlinux | arch | `/etc/nftables.conf` | systemd, `Type=oneshot` | no `ExecStop`, no `RemainAfterExit` |
| Alpine | alpine | `/etc/nftables.nft` | OpenRC, `/etc/init.d/nftables` | `stop()` flushes; `reload()` only loads the file; `save_on_stop` defaults to `no` |

The units were read after `lab solve 4.07` had installed the package (nftables is installed by
default only on arch).

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `has no attribute 'default_ipv4'` | `gather_subset: min` leaves the network facts out | gather them (the default, or `min,network`) |
| `wait_for_connection` turns green although nothing was tested | the timeout is longer than the rollback delay, so the rollback restored access | keep the timeout well below the delay |
| `[WARNING]: reset_connection task does not support when conditional` | the `when` of the surrounding block is inherited by the `meta` task | a warning only; the solution passes on all seven hosts (not investigated whether the reset is skipped when the condition is false) |
| Docker's DNS is gone, other containers do not resolve | `flush ruleset` deleted the `ip nat` table | never flush; manage only `inet cis_filter` |
| the table is gone after a restart, the file is unchanged | rules in the kernel are not persisted by the file | check the live state, and enable the service |
| foreign rules vanish after a restart of the service | `ExecStop` runs `nft flush ruleset` (debian, ubuntu, rocky, alma, fedora) | use `enabled: true` only |

### Real-world notes
- The same pattern - arm a rollback, change, test with a new connection, disarm - protects any
  change to the path you work through (sshd, routes, VPN).
- Where firewalld, ufw or another tool owns the rules, a table of your own sits beside theirs.
  Decide which tool owns the policy before you add a second one.

### Further reading
- Lesson [L13 - Host firewall with nftables](../../../docs/lessons/L13-host-firewall-nftables.md): the concepts before this exercise, with demos and self-check questions.
- [Container limits](../../../docs/CONTAINER_LIMITS.md): why the lab never flushes the ruleset.

## Reference solution

Show it with `lab solution 4.07`, apply it with `lab solve 4.07`.
