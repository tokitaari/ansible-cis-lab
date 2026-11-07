# 4.05 - Custom Facts: Hosts beschreiben ihre eigene Härtung

## Hinweis 1

Statisch: `copy` mit `content: "{{ {'baseline': 'lab-cis', 'version': '1.0.0', 'level': 1, 'managed_by': 'ansible'} | to_nice_json }}"`. Das Verzeichnis `/etc/ansible/facts.d` muss vorher existieren.

## Hinweis 2

Skript für den ausführbaren Fact: `uid0=$(awk -F: '$3 == 0' /etc/passwd | wc -l)`, `prl=$(/usr/sbin/sshd -T 2>/dev/null | awk 'tolower($1)=="permitrootlogin"{print $2}')`, dann `printf '{"uid0_accounts": %d, "permit_root_login": "%s"}\n' "$uid0" "${prl:-unknown}"`.

## Hinweis 3

Das Playbook als Gerüst - füll jedes `"..."` aus. Lies im Bericht-Template `hostvars[h].ansible_local` mit einem `default`, damit ein Host ohne Facts `-` zeigt, statt zu scheitern.

```yaml
- name: Deploy hardening facts
  hosts: targets
  become: true                        # Facts als root sammeln - sshd -T braucht das
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
        content: "..."                # das Dict als JSON, kein Zeitstempel
        owner: root
        group: root
        mode: "0644"

    - name: Executable fact - what is true now
      ansible.builtin.copy:
        src: "..."                    # dein POSIX-sh-Skript aus files/
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
    report_dir: "..."                 # LAB_WORK_DIR aus der Umgebung, Default /lab/work, plus /4.05
  tasks:
    - name: Ensure the work directory exists
      ansible.builtin.file:
        path: "{{ report_dir }}"
        state: directory
        mode: "0755"

    - name: Write inventory.md
      ansible.builtin.template:
        src: "..."                    # eine Zeile je Host aus groups['targets'], Werte aus hostvars
        dest: "{{ report_dir }}/inventory.md"
        mode: "0644"
```

Referenz: `lab solution 4.05`.
