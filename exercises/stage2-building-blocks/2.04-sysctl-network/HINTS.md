# 2.04 - Kernel parameters: network hardening via sysctl

## Hint 1

`loop: "{{ cis_sysctl_network | dict2items }}"` gives you `item.key` and `item.value`. Pass `value: "{{ item.value }}"` - the module takes the value as text anyway, so `0` and `"0"` end up the same.

## Hint 2

Network: `sysctl_file: /etc/sysctl.d/60-cis-network.conf`, `sysctl_set: true`, `reload: false` (setting is enough). Kernel: `sysctl_set: false` **and** `reload: false` - the default `reload: true` would load the file and change your host. Before both: a `file` task for `/etc/sysctl.d` - on rocky and alma it is missing, and the module fails with `[Errno 2] No such file or directory`.

## Hint 3

The playbook's tasks as a skeleton - fill in every `"..."`. The two dicts (`cis_sysctl_network`, `cis_sysctl_kernel`) belong in `vars:` before `tasks:`.

```yaml
- name: Ensure /etc/sysctl.d exists
  ansible.builtin.file:
    path: "..."
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Set and persist network parameters (namespaced - safe to apply)
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: "..."                # 60-cis-network.conf
    sysctl_set: "..."                 # apply live
    reload: "..."                     # setting is enough
  loop: "..."                         # the network dict as key/value pairs

- name: Persist global kernel parameters (applied only on real hosts)
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: "..."                # 60-cis-kernel.conf
    sysctl_set: "..."                 # never live inside a container: lab_in_container
    reload: "..."                     # the default true would load the whole file
  loop: "..."
```

Reference: `lab solution 2.04`.
