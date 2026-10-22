# 2.05 - Job schedulers: cron permissions and access

## Hint 1

Make one list of dicts: `[{path: /etc/crontab, mode: '0600'}, {path: /etc/cron.d, mode: '0700'}, ...]`, stat each `item.path`, then loop over the results with `when: item.stat.exists` and use `item.item.mode`.

## Hint 2

Service: `name: "{{ cron_service[ansible_facts.os_family] }}"`. For `cron.allow` use `copy` with `content: "root\n"` and `when: ansible_facts.os_family != 'Alpine'`.

## Hint 3

Alpine task: `ansible.builtin.file: path=/etc/crontabs state=directory owner=root group=root mode="0700"` with `when: ansible_facts.os_family == 'Alpine'`. That single exception is fine - the rest is data-driven.
