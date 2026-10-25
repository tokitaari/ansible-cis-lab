# 2.04 - Kernel parameters: network hardening via sysctl

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 2 - Building blocks | ★★★☆☆ | ~40 min | 3.3 Network kernel parameters / 1.5 Process hardening (L1) | `targets` |

**Concepts:** `ansible.posix.sysctl`, `dict2items`, `namespaced vs global sysctls`, `collections`

## Goal

Set the CIS network kernel parameters at runtime *and* persistently - and learn which parameters a container may touch.

## Background

Network sysctls stop a server from acting like a router (forwarding, redirects,
source routing) and harden it against spoofing and SYN floods. Process-hardening
sysctls (ASLR, core dumps of setuid programs, ptrace) protect memory.

**The important twist:** `net.*` parameters are *per network namespace* - each
container has its own copy, so you may set them live. `kernel.*` and `fs.*`
parameters are **global** - setting them in a privileged container changes your
HOST. For those you only write the persistent file (effective after a reboot of a
real machine). This distinction matters in production too (Kubernetes, LXC).

## Requirements

- [ ] Use the module `ansible.posix.sysctl` (a collection module - FQCN!).
- [ ] Set and persist these in `/etc/sysctl.d/60-cis-network.conf` (applied live):
  `net.ipv4.ip_forward=0`, `net.ipv4.conf.all.send_redirects=0`, `net.ipv4.conf.default.send_redirects=0`, `net.ipv4.conf.all.accept_redirects=0`, `net.ipv4.conf.default.accept_redirects=0`, `net.ipv4.conf.all.secure_redirects=0`, `net.ipv4.conf.default.secure_redirects=0`, `net.ipv4.conf.all.accept_source_route=0`, `net.ipv4.conf.default.accept_source_route=0`, `net.ipv4.conf.all.log_martians=1`, `net.ipv4.conf.default.log_martians=1`, `net.ipv4.icmp_echo_ignore_broadcasts=1`, `net.ipv4.icmp_ignore_bogus_error_responses=1`, `net.ipv4.conf.all.rp_filter=1`, `net.ipv4.conf.default.rp_filter=1`, `net.ipv4.tcp_syncookies=1`
- [ ] Only **persist** (do not apply!) in `/etc/sysctl.d/60-cis-kernel.conf`:
  `kernel.randomize_va_space=2`, `fs.suid_dumpable=0`, `kernel.yama.ptrace_scope=1`
- [ ] Keep the parameters in two dict variables and loop with `dict2items`.
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 2.04            # creates /lab/work/2.04/
cd /lab/work/2.04
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 2.04            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 2.04 1` (gentle) ... `lab hint 2.04 3` (almost the answer).  
Passed? Read `lab explain 2.04` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Which module options decide between *live* and *file only*? Read `ansible-doc ansible.posix.sysctl` for `sysctl_set` and `reload`.
- IPv6: add `net.ipv6.conf.all.accept_ra=0` etc. What happens if IPv6 is disabled in the container? How would you make the task robust?
