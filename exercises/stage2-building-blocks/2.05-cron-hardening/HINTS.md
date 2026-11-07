# 2.05 - Job schedulers: cron permissions and access

## Hint 1

Make one list of dicts: `[{path: /etc/crontab, mode: '0600'}, {path: /etc/cron.d, mode: '0700'}, ...]`, stat each `item.path`, then loop over the results with `when: item.stat.exists` and use `item.item.mode`.

## Hint 2

Service: `name: "{{ cron_service[ansible_facts.os_family] }}"`. For `cron.allow` use `copy` with `content: "root\n"` and `when: ansible_facts.os_family != 'Alpine'`. Alpine gets one task of its own: `/etc/crontabs` as a directory, `root:root`, `0700`. That single exception is fine - the rest is data-driven.

## Hint 3

The playbook's tasks as a skeleton - fill in every `"..."`. The service dict and the list of `{path, mode}` dicts belong in `vars:` before `tasks:`.

```yaml
- name: Find existing cron paths
  ansible.builtin.stat:
    path: "..."
  loop: "..."                         # the list of path/mode dicts
  register: cron_stat

- name: Restrict cron files and directories
  ansible.builtin.file:
    path: "..."                       # the path of the original loop item
    owner: root
    group: root
    mode: "..."
  loop: "..."                         # the stat results
  loop_control:
    label: "{{ item.item.path }}"
  when: "..."                         # only paths that exist

- name: Restrict crontab usage to root (not supported by busybox crontab)
  ansible.builtin.copy:
    dest: /etc/cron.allow
    content: "..."
    owner: root
    group: root
    mode: "0640"
  when: "..."                         # every family except Alpine

- name: Remove cron.deny (ignored once cron.allow exists)
  ansible.builtin.file:
    path: /etc/cron.deny
    state: "..."
  when: "..."

- name: Alpine - restrict the spool directory instead
  ansible.builtin.file:
    path: "..."
    state: directory
    owner: root
    group: root
    mode: "0700"
  when: "..."

- name: Cron daemon is enabled and running
  ansible.builtin.service:
    name: "..."                       # dict lookup per os_family
    state: started
    enabled: true
```

Reference: `lab solution 2.05`.
