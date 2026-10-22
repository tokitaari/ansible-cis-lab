# Container limits - what the lab can and cannot show

*[Deutsch](CONTAINER_LIMITS.de.md)*

All targets share **one kernel - your host's**. Containers isolate *namespaces*, not the
kernel. To make most CIS controls realistic the targets run `privileged` with a real init
system. That brings a responsibility: some actions inside a target change your host.

## Rules used throughout the lab

| Never do this inside a target | Why | What the exercises do instead |
|---|---|---|
| `modprobe -r`, `rmmod`, loading modules | modules belong to the host kernel | write `/etc/modprobe.d` only (2.03) |
| `sysctl -w kernel.*` / `fs.*`, `sysctl -p` on such files | not namespaced → changes the host | persist only; `reload: false` (2.04) |
| start `auditd`, `auditctl`, `augenrules --load` | the audit subsystem is global | configure rules only (3.04) |
| set the clock (chrony/ntpd with CAP_SYS_TIME) | changes the host clock | not part of the exercises |
| `nft flush ruleset` | deletes Docker's DNS rules in the container namespace | own table `inet cis_filter` (4.07) |

The inventory variable `lab_in_container: true` (in `ansible/inventory/group_vars/all.yml`)
is the switch the reference solutions use. The same code does the full job on real VMs.

## Which CIS areas are realistic here

| Area | In the lab | Note |
|---|---|---|
| Packages, services, cron, banners | full | |
| SSH, sudo, PAM, password policy, accounts | full | real PAM stacks, real sshd |
| Network sysctls (`net.*`) | full | per network namespace |
| Host firewall (nftables) | full | in the container's network namespace |
| File permissions, AIDE | full | AIDE scans the container filesystem |
| Kernel modules, process hardening sysctls | config only | effect is host-wide |
| auditd | config only | effect is host-wide |
| Separate partitions, mount options | not possible | needs block devices / a VM |
| Bootloader (GRUB password, permissions) | not possible | containers do not boot via GRUB |
| SELinux / AppArmor enforcement | not possible | the LSM belongs to the host kernel |
| Time synchronisation | not possible | would change the host clock |

## Side effects you might notice

- `systemd-sysctl.service` in the targets applies `/etc/sysctl.d` at container start. After
  exercise 2.04 that includes the `kernel.*` values from `60-cis-kernel.conf` (ASLR=2,
  suid_dumpable=0, ptrace_scope=1). These are hardening values and usually already the
  default on modern hosts; if you prefer to avoid it, mask the unit in the target images
  (`systemctl mask systemd-sysctl.service` in `targets/common/bootstrap.sh`).
- Privileged containers can see host devices. Nothing in the exercises touches them.

## Want the full picture?

The roles are written to run on VMs unchanged: set `lab_in_container: false` in your own
inventory and the guarded tasks (module unloading, global sysctls, auditd service) become
active. A Vagrant/libvirt or cloud VM per distribution is the natural next step after the lab.
