# 3.04 - auditd: rules and log retention (Level 2)

## Hint 1

`loop: "{{ cis_audit_rules | dict2items }}"` → `dest: "/etc/audit/rules.d/50-cis-{{ item.key }}.rules"`. Template body: `{% for rule in item.value %}{{ rule }}\n{% endfor %}` (in a template file, `item` is available).

## Hint 2

`auditd.conf` is `key = value`: `lineinfile` with `regexp: '^\s*{{ item.key }}\s*='` and `line: "{{ item.key }} = {{ item.value }}"`, looping over a dict.

## Hint 3

Service task: `ansible.builtin.service: name=auditd state=started enabled=true` with `when: not (lab_in_container | default(false))`. Reference: `lab solution 3.04`.
