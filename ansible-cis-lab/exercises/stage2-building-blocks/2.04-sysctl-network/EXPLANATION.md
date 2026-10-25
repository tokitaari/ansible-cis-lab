# 2.04 - Kernel parameters: network hardening via sysctl: Explanation

### Solution
See `lab solution 2.04` - two dicts, two looped tasks. The kernel task:
```yaml
- name: Persist global kernel parameters
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: /etc/sysctl.d/60-cis-kernel.conf
    sysctl_set: "{{ not (lab_in_container | default(false)) }}"
    reload: "{{ not (lab_in_container | default(false)) }}"
  loop: "{{ cis_sysctl_kernel | dict2items }}"
```
Using `lab_in_container` instead of hard-coding `false` makes the same code correct on
real servers.

### Module options
| Option | Effect |
|---|---|
| `sysctl_file` | where to persist (`/etc/sysctl.d/*.conf` is read at boot) |
| `sysctl_set: true` | also apply the value now (`sysctl -w`) |
| `reload: true` (default!) | run `sysctl -p <file>` - applies **everything** in the file |

### Why the parameters matter
- `ip_forward=0`, `send_redirects=0` - a server is not a router.
- `accept_redirects=0`, `secure_redirects=0` - ICMP redirects can reroute your traffic (MITM).
- `accept_source_route=0` - the sender must not choose the path.
- `rp_filter=1` - drop packets whose source address cannot be routed back (anti-spoofing).
- `log_martians=1` - log impossible source addresses.
- `tcp_syncookies=1` - survive SYN floods.
- `randomize_va_space=2` - full ASLR; `suid_dumpable=0` - no core dumps with secrets;
  `ptrace_scope=1` - processes cannot attach to non-children.

### Container pitfall in detail
Docker sets some `net.*` values itself (e.g. `ip_forward`) when creating the
namespace. A container restart resets all live values - only the file in
`/etc/sysctl.d` survives, and only if something applies it at boot
(`systemd-sysctl.service`). On OpenRC the `sysctl` service is skipped inside
containers (`rc_sys=docker`), which is why the live setting matters here.

### Collections
`ansible.posix.sysctl` is not in ansible-core. The lab image installs the `ansible`
community package, which bundles it. In your own projects declare it in
`collections/requirements.yml`.

## Reference solution

Show it with `lab solution 2.04`, apply it with `lab solve 2.04`.
