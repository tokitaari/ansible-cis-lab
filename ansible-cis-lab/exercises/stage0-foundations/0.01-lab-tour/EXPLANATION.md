# 0.01 - Lab tour: inventory and connectivity: Explanation

### What happened
`ping` is not ICMP. It is a real Ansible module: Ansible copies a small Python
program to the target, runs it and expects JSON back. That only works where Python
exists. Seven targets have it, **Alpine does not** - on purpose. Minimal images
(containers, appliances, network devices) often lack Python.

### Inventory structure
```
targets
├── debian_family:  debian, ubuntu
├── redhat_family:  rocky, alma, fedora
├── suse_family:    opensuse
├── arch_family:    arch
└── alpine_family:  alpine
```
Grouping by OS family is deliberate: package names, service names, file locations
and defaults differ along exactly these lines. `group_vars/<group>.yml` lets you
attach data to each family later.

### Useful patterns
- `ansible 'targets:!alpine_family' -m ansible.builtin.ping` - all except a group
- `ansible 'redhat_family:&targets' ...` - intersection
- `ansible-inventory --host debian` shows the *merged* variables for one host -
  the first debugging step when "a variable has the wrong value".

### Real world
In production you would add `ansible_host`, jump hosts (`ansible_ssh_common_args`)
and dynamic inventories (Azure, AWS, Satellite). The questions stay the same.

## Reference solution

Show it with `lab solution 0.01`, apply it with `lab solve 0.01`.
