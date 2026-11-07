# 4.05 - Custom facts: hosts that describe their own hardening

## Hint 1

Static: `copy` with `content: "{{ {'baseline': 'lab-cis', 'version': '1.0.0', 'level': 1, 'managed_by': 'ansible'} | to_nice_json }}"`. Directory `/etc/ansible/facts.d` must exist first.

## Hint 2

Executable fact script: `uid0=$(awk -F: '$3 == 0' /etc/passwd | wc -l)`, `prl=$(/usr/sbin/sshd -T 2>/dev/null | awk 'tolower($1)=="permitrootlogin"{print $2}')`, then `printf '{"uid0_accounts": %d, "permit_root_login": "%s"}\n' "$uid0" "${prl:-unknown}"`.

## Hint 3

The playbook as a skeleton - fill in every `"..."`. In the report template, read `hostvars[h].ansible_local` with a `default` so a host without facts shows `-` instead of failing.

```yaml
- name: Deploy hardening facts
  hosts: targets
  become: true                        # facts gathered as root - sshd -T needs it
  vars:
    cis_fact: "..."                   # baseline, version, level, managed_by
  tasks:
    - name: Facts directory
      ansible.builtin.file:
        path: "..."
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Static fact - what was applied
      ansible.builtin.copy:
        dest: "..."                   # cis.fact
        content: "..."                # the dict as JSON, no timestamp
        owner: root
        group: root
        mode: "0644"

    - name: Executable fact - what is true now
      ansible.builtin.copy:
        src: "..."                    # your POSIX sh script from files/
        dest: "..."                   # cis_live.fact
        owner: root
        group: root
        mode: "0755"

    - name: Re-read local facts
      ansible.builtin.setup:
        filter: "..."

- name: Hardening inventory on the control node
  hosts: localhost
  gather_facts: false
  vars:
    report_dir: "..."                 # LAB_WORK_DIR from the environment, default /lab/work, plus /4.05
  tasks:
    - name: Ensure the work directory exists
      ansible.builtin.file:
        path: "{{ report_dir }}"
        state: directory
        mode: "0755"

    - name: Write inventory.md
      ansible.builtin.template:
        src: "..."                    # one row per host of groups['targets'], values from hostvars
        dest: "{{ report_dir }}/inventory.md"
        mode: "0644"
```

Reference: `lab solution 4.05`.
