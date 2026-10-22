# 4.07 - Host firewall with nftables - safe rollout

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★★ | ~90 min | 4 Host based firewall (L1) | `targets:!suse_family` |

**Concepts:** `own nft table`, `validate: nft -c`, `dead-man switch with background job`, `reset_connection`, `co-existence with Docker`

## Goal

Deploy a default-deny inbound firewall with nftables on seven hosts - with an automatic rollback if you lock yourself out.

## Background

The most dangerous hardening change is the firewall: one wrong rule and every host
is unreachable. Professionals use a **dead-man switch**: before activating new rules,
schedule a rollback; only if a *new* connection succeeds afterwards is the rollback
cancelled.

**Do not `flush ruleset`.** Other components own rules too - here Docker's embedded
DNS (NAT rules inside each container's namespace), in production Docker, Kubernetes,
fail2ban, libvirt. A flush deletes them. Manage **your own table**
(`table inet cis_filter`) and nothing else.

openSUSE is excluded (it uses firewalld - bonus).

## Requirements

- [ ] Ruleset template `/etc/cis/nftables-cis.nft`, validated with `nft -c -f %s`: table `inet cis_filter`, input policy `drop`; accept `lo`, `established,related`, ICMP echo (rate-limited) and ICMPv6, SSH (tcp/22) only from the lab subnet (derive it from `ansible_facts.default_ipv4`); drop `invalid`; forward policy `drop`; output `accept`.
- [ ] The file must be loadable repeatedly: declare the table, delete it, define it (`table inet cis_filter` / `delete table inet cis_filter` / `table inet cis_filter { ... }`).
- [ ] Load it only when the file changed **or** the table is missing (container restart!).
- [ ] Dead-man switch: before loading, start a background job that deletes the table after 60 s. After loading, `meta: reset_connection` + `wait_for_connection`; then cancel the job.
- [ ] Persistence: the distribution's nftables config file only contains `include "/etc/cis/nftables-cis.nft"`; the nftables service is enabled (do **not** restart it - why?).
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 4.07            # creates /lab/work/4.07/
cd /lab/work/4.07
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 4.07            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.07 1` (gentle) ... `lab hint 4.07 3` (almost the answer).  
Passed? Read `lab explain 4.07` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Break it on purpose: change the SSH source to `10.255.255.0/24` and run against one host. Watch the rollback save you.
- openSUSE/firewalld: implement the same intent with `ansible.posix.firewalld` (zone, services, default target).
- Add an output policy (egress filtering). Which outbound connections does a server *really* need?
