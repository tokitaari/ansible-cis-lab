# 2.04 - Kernel parameters: network hardening via sysctl: Explanation

### What the check verifies
`lab check 2.04` runs `check.yml` on all eight targets and then your playbook once more with
`--check`, expecting `changed=0` (`meta.yml` says `idempotency: true`). `check.yml`:
- reads the 16 network parameters live with one `sysctl -n` call and compares each value with
  the expected one as text;
- expects a line `key = value` (blanks around `=` allowed) for each of the 16 in
  `/etc/sysctl.d/60-cis-network.conf`;
- expects such a line for each of the three global parameters in
  `/etc/sysctl.d/60-cis-kernel.conf`.

It does not test: the live value of the three global parameters (on purpose - they belong to the
host kernel, and the check could not tell your value from the host's), that you used
`ansible.posix.sysctl`, two dicts or `dict2items`, and what else the two files contain. A live
change to a global parameter goes unnoticed: avoiding it is your part of the contract.

### How it works

#### Namespaced and global parameters
`net.*` parameters exist once per network namespace, and every container has its own. The
`kernel.*` and `fs.*` parameters of this exercise are global: there is one value for the whole
machine. The lab targets run privileged, so nothing stops a write to a global key from inside a
target - it changes the kernel of the machine that runs Docker. Measured on fresh targets: the
three global values are the same on all eight hosts (`randomize_va_space=2`, `suid_dumpable=2`,
`ptrace_scope=1`), because they are the host's. The network values start far from the CIS ones on
every host: `ip_forward=1`, `rp_filter=2` (loose mode), `send_redirects=1`, `log_martians=0`; so
the exercise really changes live values.

#### Three switches: `sysctl_file`, `sysctl_set`, `reload`
| Option | Effect |
|---|---|
| `sysctl_file` | the file the line is written to (default `/etc/sysctl.conf`) |
| `sysctl_set: true` | also write the value to `/proc/sys` now (default `false`) |
| `reload: true` (default) | run `sysctl -p <file>` - this loads **every** line of the file |

How the module decides (read in the source of `ansible.posix` 2.2.2, measured in a private
network namespace): it compares the line in the file with the wanted value. With
`sysctl_set: true` it also compares the live value. With `reload: true` and a correct file it
still compares the live value, and if that differs it runs `sysctl -p` on the whole file. So the
default `reload: true` on `60-cis-kernel.conf` would load all three global values into the host
kernel, on the first run and on every later run where the host value differs. Under `--check`
the module writes nothing.

The reference solution makes the decision a variable:
```yaml
cis_apply_global_sysctl: "{{ not (lab_in_container | default(false)) }}"
```
and uses it for `sysctl_set` and `reload` of the global task. `lab_in_container` is `true` in the
lab inventory (`group_vars/all.yml`); on a real server the same code applies the values at once.

#### Values are text
The module declares `value` as a string: `value: 0` arrives as `"0"`, and `true`/`false` become
`1`/`0`. `| string` in the solution is harmless but not needed. Values with several numbers
(some `net.ipv4` ranges) are compared word by word.

#### The file does nothing until something reads it
`/etc/sysctl.d/*.conf` is read at boot - by `systemd-sysctl.service` on systemd hosts, by the
`sysctl` service on OpenRC. In the lab containers that differs per host (see the table): the
unit is active on five hosts, missing on rocky and alma, and Alpine's `sysctl` service is in no
runlevel - the lab image does not enable it. That is why the network values are set live as
well. `./lab.sh reset` recreates the container: files and live values are back to the start.

#### Why the parameters matter
- `ip_forward=0`, `send_redirects=0` - a server is not a router.
- `accept_redirects=0`, `secure_redirects=0` - ICMP redirects can reroute your traffic (MITM).
- `accept_source_route=0` - the sender must not choose the path.
- `rp_filter=1` - drop packets whose source address cannot be routed back (strict mode; `2`,
  the start value here, only checks that the source is reachable at all).
- `log_martians=1` - log impossible source addresses.
- `tcp_syncookies=1` - survive SYN floods.
- `randomize_va_space=2` - full ASLR; `suid_dumpable=0` - no core dumps with secrets;
  `ptrace_scope=1` - processes cannot attach to non-children.

#### Collections
`ansible.posix.sysctl` is not in ansible-core. The lab image installs the `ansible` community
package, which bundles it. In your own projects declare it in `collections/requirements.yml`.

### Per-family notes
| `os_family` | Hosts | `/etc/sysctl.d` at the start | Read at boot in the container |
|---|---|---|---|
| Debian | debian, ubuntu | present (`README.sysctl`) | `systemd-sysctl.service` active |
| RedHat | rocky, alma, fedora | rocky, alma: **absent**; fedora: `99-sysctl.conf` | rocky, alma: no such unit; fedora: active |
| Suse | opensuse | present, empty | active |
| Archlinux | arch | present, empty | active |
| Alpine | alpine | present (`README`) | OpenRC `sysctl` service in no runlevel |

Start values: identical on all eight hosts, except `net.ipv4.conf.default.accept_redirects`,
which is `0` on opensuse and `1` elsewhere (`conf.all.accept_redirects` is `0` everywhere).

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| rocky, alma: `[Errno 2] No such file or directory: '/etc/sysctl.d/.ansible_m_sysctl_....conf'` | the directory is missing and the module does not create it | a `file` task with `state: directory` first |
| A misspelled key lands in the file without an error | with `sysctl_set: false` the module never touches `/proc/sys` | keep the key list short and reviewed; `sysctl_set: true` reports `cannot stat /proc/sys/...` for namespaced keys |
| The host's `suid_dumpable` changed | `reload` left at its default, or `sysctl_set: true` on a global key | both `false` in a container (`lab_in_container`) |
| Values are gone after `./lab.sh reset` | the target was recreated | run the playbook again |
| A `net.ipv6.*` key fails with `cannot stat /proc/sys/...` (bonus) | IPv6 is off in that namespace, so the key does not exist | test for `/proc/sys/net/ipv6` first |

### Real-world notes
- In container platforms a pod or container may only set namespaced parameters; global ones are
  a property of the node and belong to its own configuration management.
- Put each parameter in exactly one file. When two files set the same key, the one read later
  wins at boot (`sysctl.d(5)`), and a reviewer reading only yours sees the wrong value.

### Further reading
- Lesson [L05 - Kernel hardening: modules and sysctl](../../../docs/lessons/L05-kernel-modules-and-sysctl.md): namespaces, persistence and boot, the module options - the concepts before this exercise.
- Exercise [2.03 - Disable unneeded kernel modules](../2.03-disable-kernel-modules/README.md): the other half of the lesson, with the same host-versus-container question.

## Reference solution

Show it with `lab solution 2.04`, apply it with `lab solve 2.04`.
