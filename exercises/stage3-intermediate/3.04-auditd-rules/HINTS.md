# 3.04 - auditd: rules and log retention (Level 2)

## Hint 1

`loop: "{{ cis_audit_rules | dict2items }}"` → `dest: "/etc/audit/rules.d/50-cis-{{ item.key }}.rules"`. Template body: a `{% for rule in item.value %}` loop with `{{ rule }}` on a line of its own and `{% endfor %}` on the next (in a template file, `item` is available). Use real line breaks: a literal `\n` in a template stays two characters, so all rules of a topic would end up on one line - the check does not notice, `augenrules` would.

## Hint 2

`auditd.conf` is `key = value`: `lineinfile` with `regexp: '^\s*{{ item.key }}\s*='` and `line: "{{ item.key }} = {{ item.value }}"`, looping over a dict. Write the values in lower case (`keep_logs`): the check compares case-sensitively.

## Hint 3

The playbook's tasks as a skeleton - fill in every `"..."`. The variables (package per family, the rule dict, the `auditd.conf` values) belong before `tasks:`; copy the rule list from `lab solution 3.04` if you do not want to type it.

```yaml
- name: Look for an apt package index
  ansible.builtin.find:
    paths: "..."
    patterns: "..."                   # the index files, *_Packages*
  register: cis_apt_lists
  check_mode: false
  when: "..."                         # Debian family only

- name: Refresh the apt package index
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: "..."           # 0 while no index file exists, else one day
  changed_when: false
  check_mode: false                   # apt skips the refresh in check mode
  when: "..."

- name: Install the audit framework
  ansible.builtin.package:
    name: "..."                       # dict lookup per os_family
    state: present

- name: Ensure the rules directory exists
  ansible.builtin.file:
    path: /etc/audit/rules.d
    state: directory
    owner: root
    group: root
    mode: "0750"

- name: Deploy one rule file per topic
  ansible.builtin.template:
    src: "..."                        # template with a for loop over item.value
    dest: "..."                       # 50-cis-<topic>.rules
    owner: root
    group: root
    mode: "0640"
  loop: "..."                         # the dict as a list of key/value pairs
  loop_control:
    label: "{{ item.key }}"

- name: Lock the rule set
  ansible.builtin.copy:
    dest: "..."                       # 99-cis-finalize.rules
    content: "..."
    owner: root
    group: root
    mode: "0640"

- name: Configure log retention and space actions
  ansible.builtin.lineinfile:
    path: /etc/audit/auditd.conf
    regexp: "..."                     # the key, blanks allowed before the equals sign
    line: "..."
  loop: "..."

- name: Enable and start auditd (real hosts only)
  ansible.builtin.service:
    name: auditd
    state: started
    enabled: true
  when: "..."                         # not inside a lab container
```

Reference: `lab solution 3.04`.
