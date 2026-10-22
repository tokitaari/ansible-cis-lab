# 4.07 - Host firewall with nftables - safe rollout: Explanation

### The dead-man switch, step by step
1. Template + `validate: nft -c -f %s` → syntax errors never reach the host.
2. Start `sleep 60; nft delete table ...` in the background (`nohup`, own process).
3. Load the rules.
4. `meta: reset_connection` closes Ansible's persistent SSH master. Without it,
   `wait_for_connection` would reuse the *already established* connection, which the
   `established,related` rule keeps alive - a false positive.
5. `wait_for_connection` opens a fresh connection. Success → `kill` the rollback.
   Failure → the play fails for this host, and 60 s later the table is gone again.

### Own your table
`flush ruleset` is the default in many distribution templates. In shared kernels and
namespaces it removes other owners' rules. In this lab you would break DNS inside the
container; on a Docker host you would break every container's networking. A dedicated
table plus `delete table` keeps your changes atomic and contained.

### Why not restart nftables.service
On Debian, `ExecStop` runs `nft flush ruleset` - a restart wipes foreign rules once.
Enabling is enough: at boot the service loads your include.

### Re-applying after restarts
The file can be unchanged while the kernel state is gone (container or host restart
without the service). Checking the *live* state (`nft list table`) closes that gap -
the same idea as "verify the effect, not the file" from 1.01 and 1.03.

## Reference solution

Show it with `lab solution 4.07`, apply it with `lab solve 4.07`.
