# 2.03 - Disable unneeded kernel modules: Explanation

### Solution
```yaml
- name: CIS - disable unneeded kernel modules
  hosts: targets
  become: true
  vars:
    cis_level: 1
    cis_disabled_modules_l1: [cramfs, freevxfs, hfs, hfsplus, jffs2, usb-storage]
    cis_disabled_modules_l2: [squashfs, udf, dccp, tipc, rds, sctp]
    cis_disabled_modules: >-
      {{ cis_disabled_modules_l1
         + (cis_disabled_modules_l2 if cis_level | int >= 2 else []) }}
  tasks:
    - name: Disable kernel module
      ansible.builtin.copy:
        dest: "/etc/modprobe.d/cis-{{ item }}.conf"
        content: |
          install {{ item }} /bin/false
          blacklist {{ item }}
        owner: root
        group: root
        mode: "0644"
      loop: "{{ cis_disabled_modules }}"
```

### One file per module
One file per module makes exceptions trivial (delete one file) and diffs readable.
A single big file is also fine - pick one convention and keep it.

### `install /bin/false` vs `blacklist`
- `blacklist` only stops *automatic* loading through aliases (e.g. udev). An explicit
  `modprobe cramfs` still works.
- `install cramfs /bin/false` replaces the load command - explicit loading fails too.
CIS asks for both.

### Level 2 (bonus)
`squashfs` is L2 because snaps (Ubuntu) and many live/installer images need it.
`sctp`/`dccp`/`tipc`/`rds` had real CVEs reachable by unprivileged users - but some
telecom stacks rely on SCTP. That is why the profile split exists.

### What the container cannot show you
`modprobe -n -v cramfs` should print `install /bin/false`. That proves the config.
Whether the module is *currently loaded* (`lsmod`) reflects your host kernel, not the
container - see `docs/CONTAINER_LIMITS.md`.

## Reference solution

Show it with `lab solution 2.03`, apply it with `lab solve 2.03`.
