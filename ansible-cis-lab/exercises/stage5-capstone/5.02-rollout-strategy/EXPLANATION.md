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

### Dry runs
`--check` still runs preflight (read-only commands with `check_mode: false`), so you
can test the gate logic without touching hosts.

### Batch sizes
`serial: [1, "30%", "100%"]` means 1 host, then 30 % of the remaining hosts, then
the rest. For 2,000 servers you might use `[1, 10, "5%", "25%", "100%"]` - the idea is
to grow confidence before growing blast radius.

## Reference solution

Show it with `lab solution 5.02`, apply it with `lab solve 5.02`.
