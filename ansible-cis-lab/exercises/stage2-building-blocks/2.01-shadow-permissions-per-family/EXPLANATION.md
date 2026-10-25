# 2.01 - /etc/shadow: correct permissions per OS family: Explanation

### Solution
```yaml
- name: Protect password hashes
  hosts: targets
  become: true
  vars:
    shadow_perms:
      Debian:    {group: shadow, mode: "0640"}
      Suse:      {group: shadow, mode: "0640"}
      Alpine:    {group: shadow, mode: "0640"}
      RedHat:    {group: root,   mode: "0000"}
      Archlinux: {group: root,   mode: "0600"}
    shadow_paths: [/etc/shadow, /etc/gshadow, /etc/shadow-, /etc/gshadow-]
  tasks:
    - name: Find which shadow files exist
      ansible.builtin.stat:
        path: "{{ item }}"
      loop: "{{ shadow_paths }}"
      register: shadow_files
    - name: Set owner, group and mode
      ansible.builtin.file:
        path: "{{ item.item }}"
        owner: root
        group: "{{ shadow_perms[ansible_facts.os_family].group }}"
        mode: "{{ shadow_perms[ansible_facts.os_family].mode }}"
      loop: "{{ shadow_files.results }}"
      loop_control:
        label: "{{ item.item }}"
      when: item.stat.exists
```

### Data over conditions
Five `when: os_family == 'X'` tasks would work, but every new distribution means
touching every task. A lookup table keeps *data* (what differs) separate from
*logic* (what to do). This is the core idea behind `vars/<os_family>.yml` in roles
(stage 3/4).

### register + loop
A looped `stat` registers `shadow_files.results` - one entry per item, each holding
`item` (the input) and `stat`. `loop_control.label` keeps the output readable.

### Mode 0000?
Root ignores permission bits for reading (CAP_DAC_OVERRIDE), so `0000` costs root
nothing and denies everyone else. RHEL uses it as the strictest possible value.

### Pitfall
An unknown family (e.g. a new distro) raises "dict object has no attribute ...".
Production code adds a default:
`shadow_perms[ansible_facts.os_family] | default({'group': 'root', 'mode': '0600'})`.

## Reference solution

Show it with `lab solution 2.01`, apply it with `lab solve 2.01`.
