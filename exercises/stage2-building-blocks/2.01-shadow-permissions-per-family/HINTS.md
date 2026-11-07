# 2.01 - /etc/shadow: correct permissions per OS family

## Hint 1

Facts are needed for `os_family` - keep `gather_facts` on. Lookup: `shadow_perms[ansible_facts.os_family].mode`.

## Hint 2

Task 1: `ansible.builtin.stat` with `loop: [/etc/shadow, /etc/gshadow]` and `register: shadow_files`. Task 2: `ansible.builtin.file` with `loop: "{{ shadow_files.results }}"` and `when: item.stat.exists`. The path is `item.item`.

## Hint 3

```yaml
- name: Protect password hashes
  hosts: "..."
  become: "..."
  vars:
    shadow_perms:                # one entry per os_family value
      Debian: {group: "...", mode: "..."}
      Suse: {group: "...", mode: "..."}
      Alpine: {group: "...", mode: "..."}
      RedHat: {group: "...", mode: "..."}
      Archlinux: {group: "...", mode: "..."}
  tasks:
    - name: Find which shadow files exist
      ansible.builtin.stat:
        path: "..."              # the loop item
      loop: "..."                # the paths, backups too if you like
      register: "..."
    - name: Set owner, group and mode per OS family
      ansible.builtin.file:
        path: "..."              # the original item of the stat result
        owner: root
        group: "..."             # looked up by ansible_facts.os_family
        mode: "..."
      loop: "..."                # the registered results
      when: "..."                # only files that exist
```

Reference: `lab solution 2.01`.
