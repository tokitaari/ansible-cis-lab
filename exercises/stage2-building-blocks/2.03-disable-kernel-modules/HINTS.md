# 2.03 - Disable unneeded kernel modules

## Hint 1

`loop: "{{ cis_disabled_modules_l1 }}"` and use `{{ item }}` in `dest` and `content`.

## Hint 2

`content:` can be a multi-line string: `content: |` followed by two indented lines that use `{{ item }}`.

## Hint 3

```yaml
- name: CIS - disable unneeded kernel modules
  hosts: "..."
  become: "..."
  vars:
    cis_disabled_modules_l1: ["..."]   # the six names of the README
  tasks:
    - name: Disable kernel module
      ansible.builtin.copy:
        dest: "..."              # /etc/modprobe.d/00-cis-<module>.conf, one per loop item
        content: "..."           # the two lines install and blacklist, e.g. as a block scalar |
        owner: root
        group: root
        mode: "..."
      loop: "..."
```

No `modprobe` task: in the lab containers it would act on the host kernel.

Reference: `lab solution 2.03`.
