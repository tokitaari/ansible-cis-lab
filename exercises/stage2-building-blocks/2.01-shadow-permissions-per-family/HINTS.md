# 2.01 - /etc/shadow: correct permissions per OS family

## Hint 1

Facts are needed for `os_family` - keep `gather_facts` on. Lookup: `shadow_perms[ansible_facts.os_family].mode`.

## Hint 2

Task 1: `ansible.builtin.stat` with `loop: [/etc/shadow, /etc/gshadow]` and `register: shadow_files`. Task 2: `ansible.builtin.file` with `loop: "{{ shadow_files.results }}"` and `when: item.stat.exists`. The path is `item.item`.

## Hint 3

```yaml
vars:
  shadow_perms:
    Debian: {group: shadow, mode: "0640"}
    Suse: {group: shadow, mode: "0640"}
    Alpine: {group: shadow, mode: "0640"}
    RedHat: {group: root, mode: "0000"}
    Archlinux: {group: root, mode: "0600"}
...
- ansible.builtin.file:
    path: "{{ item.item }}"
    owner: root
    group: "{{ shadow_perms[ansible_facts.os_family].group }}"
    mode: "{{ shadow_perms[ansible_facts.os_family].mode }}"
  loop: "{{ shadow_files.results }}"
  when: item.stat.exists
```
