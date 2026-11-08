# 4.01 - Reiner Audit-Lauf mit Compliance-Bericht

## Hinweis 1

Sammle zuerst die Rohdaten (ein Task pro Quelle, alle lesend, `check_mode: false` an `command`-Tasks, damit sie auch unter `--check` laufen). Baue dann die Ergebnisliste in **einem** `set_fact` mit Inline-Bedingungen: `status: "{{ 'pass' if 'telnet' not in ansible_facts.packages else 'fail' }}"`.

## Hinweis 2

Für wirksame sshd-Werte den Parse-Trick aus den Checks wiederverwenden: `sshd -T` → `pairs = lines | map('regex_replace', '^(\\S+)\\s+(.*)$', '\\1\\t\\2') | map('split', '\\t') | list`, dann `dict(pairs | map('first') | map('lower') | zip(pairs | map('last')))` - Schlüsselwörter kleinschreiben, OpenSSH 10.6 gibt `PermitRootLogin` aus. Aggregation: zweites Play auf `localhost`, über `groups['targets']` iterieren, `hostvars[h].cis_results` lesen.

## Hinweis 3

Das Playbook, zwei Plays:

```yaml
- name: CIS audit (read-only)
  hosts: targets
  become: true                    # sshd -T braucht root
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
      failed_when: "..."          # das sudo-Drop-in kann fehlen

    - name: Effective sshd configuration
      ansible.builtin.command: "..."
      register: cis_sshd_t
      changed_when: false
      check_mode: false           # ein Leser muss auch unter --check laufen
    # ... dasselbe für sysctl -n net.ipv4.ip_forward

    - name: Evaluate controls
      vars:
        sshd: "..."               # Dict aus den Zeilen von sshd -T, Schlüsselwörter klein
        uid0: "..."               # Namen aller UID-0-Konten in /etc/passwd
      ansible.builtin.set_fact:
        cis_results:
          - id: "2.2"
            title: telnet client is not installed
            status: "..."         # 'pass' if ... else 'fail'
          # ... neun weitere; 'n/a', wo eine Kontrolle nicht passt

- name: Write the compliance report
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Build the report structure
      ansible.builtin.set_fact:
        cis_report: "..."         # {host: {score, results}} für jeden Host von groups['targets']

    - name: Write JSON
      ansible.builtin.copy:
        dest: "..."
        content: "{{ cis_report | to_nice_json }}\n"
        mode: "0644"
    # ... und report.md mit ansible.builtin.template
```

Score: `pass / (pass + fail) * 100`, auf eine Nachkommastelle gerundet; `n/a` zählt nirgends mit,
und ein Host mit nur `n/a` darf nicht durch null teilen. Die vollständige Referenz:
`lab solution 4.01`.
