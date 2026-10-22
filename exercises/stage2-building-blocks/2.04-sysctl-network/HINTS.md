# 2.04 - Kernel parameters: network hardening via sysctl

## Hint 1

`loop: "{{ cis_sysctl_network | dict2items }}"` gives you `item.key` and `item.value`. Pass `value: "{{ item.value }}"` (strings are safest).

## Hint 2

Network: `sysctl_file: /etc/sysctl.d/60-cis-network.conf`, `sysctl_set: true`, `reload: false` (setting is enough). Kernel: `sysctl_set: false` **and** `reload: false` - the default `reload: true` would load the file and change your host.

## Hint 3

```yaml
- name: Persist global kernel parameters (no live change in the lab)
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: /etc/sysctl.d/60-cis-kernel.conf
    sysctl_set: false
    reload: false
  loop: "{{ cis_sysctl_kernel | dict2items }}"
```
