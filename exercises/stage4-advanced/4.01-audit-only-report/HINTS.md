# 4.01 - Audit-only compliance report

## Hint 1

Collect raw data first (one task per source, all read-only, `check_mode: false` on `command` tasks so they also run under `--check`). Then build the result list in **one** `set_fact` using inline conditionals: `status: "{{ 'pass' if 'telnet' not in ansible_facts.packages else 'fail' }}"`.

## Hint 2

For effective sshd values reuse the parsing trick from the checks: `sshd -T` → `pairs = lines | map('regex_replace', '^(\\S+)\\s+(.*)$', '\\1\\t\\2') | map('split', '\\t') | list`, then `dict(pairs | map('first') | map('lower') | zip(pairs | map('last')))` - lower-case the keywords, OpenSSH 10.6 prints `PermitRootLogin`. Aggregation: second play on `localhost`, iterate `groups['targets']`, read `hostvars[h].cis_results`.

## Hint 3

The playbook, two plays:

```yaml
- name: CIS audit (read-only)
  hosts: targets
  become: true                    # sshd -T needs root
  gather_facts: true
  tasks:
    - name: Collect package facts
      ansible.builtin.package_facts:

    - name: Collect service facts
      ansible.builtin.service_facts:

    - name: Stat account files and cron.allow
      ansible.builtin.stat:
        path: "{{ item }}"
      loop: ["...", "...", "..."]
      register: cis_stat

    - name: Read files
      ansible.builtin.slurp:
        src: "{{ item }}"
      loop: ["...", "..."]
      register: cis_files
      failed_when: "..."          # the sudo drop-in may be missing

    - name: Effective sshd configuration
      ansible.builtin.command: "..."
      register: cis_sshd_t
      changed_when: false
      check_mode: false           # a reader must also run under --check
    # ... the same for sysctl -n net.ipv4.ip_forward

    - name: Evaluate controls
      vars:
        sshd: "..."               # dict of the sshd -T lines, keywords lower-cased
        uid0: "..."               # names of all UID 0 accounts in /etc/passwd
      ansible.builtin.set_fact:
        cis_results:
          - id: "2.2"
            title: telnet client is not installed
            status: "..."         # 'pass' if ... else 'fail'
          # ... nine more; 'n/a' where a control does not apply

- name: Write the compliance report
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Build the report structure
      ansible.builtin.set_fact:
        cis_report: "..."         # {host: {score, results}} for every host of groups['targets']

    - name: Write JSON
      ansible.builtin.copy:
        dest: "..."
        content: "{{ cis_report | to_nice_json }}\n"
        mode: "0644"
    # ... and report.md with ansible.builtin.template
```

Score: `pass / (pass + fail) * 100`, rounded to one decimal; `n/a` counts nowhere, and a host with
only `n/a` must not divide by zero. The full reference: `lab solution 4.01`.
