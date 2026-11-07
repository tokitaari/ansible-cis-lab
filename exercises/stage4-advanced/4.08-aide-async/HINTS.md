# 4.08 - File integrity with AIDE - long-running tasks

## Hint 1

Init task: `ansible.builtin.command:` with `cmd: "{{ cis_aide.init_cmd }}"` and `creates: "{{ cis_aide.db }}"`, `async: 1800`, `poll: 0`, `register: cis_aide_job`. With `poll: 0` the task reports `changed` as soon as the job starts - `creates:` only acts inside the job - so add a `stat` on the database before it and `when: not cis_aide_db.stat.exists`. RedHat init needs a shell (`aide --init && mv ...`) → use `ansible.builtin.shell` there or `sh -c` in the command.

## Hint 2

Wait: `ansible.builtin.async_status: jid: "{{ cis_aide_job.ansible_job_id }}"`, `register: job`, `until: job.finished`, `retries: 120`, `delay: 15` (120 × 15 s = the 1800 s of `async`) and `when: cis_aide_job.ansible_job_id is defined` (a skipped task has no job id).

## Hint 3

The tasks as a skeleton - fill in every `"..."`. The per-family values (packages, binary, config, database, init command) belong in a dict before `tasks:`, selected with `ansible_facts.os_family`.

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
  check_mode: false
  when: "..."

- name: Install AIDE
  ansible.builtin.package:
    name: "..."                       # packages per family
    state: present

- name: Look for an existing database
  ansible.builtin.stat:
    path: "..."
  register: cis_aide_db

- name: Build the initial database in the background
  ansible.builtin.command:
    cmd: "..."                        # per family, see the table in the README
    creates: "..."
  async: "..."
  poll: "..."
  register: cis_aide_job
  when: "..."                         # only without a database

- name: Wait for the database
  ansible.builtin.async_status:
    jid: "..."
  register: cis_aide_result
  until: "..."
  retries: "..."                      # retries * delay should cover async
  delay: "..."
  when: "..."                         # a skipped task has no job id

- name: Integrity check units
  ansible.builtin.template:
    src: "{{ item }}.j2"
    dest: "..."                       # /etc/systemd/system/<unit>
    owner: root
    group: root
    mode: "0644"
  loop: [cis-aidecheck.service, cis-aidecheck.timer]
  register: cis_aide_units

- name: Enable and start the daily timer
  ansible.builtin.systemd_service:
    name: cis-aidecheck.timer
    enabled: true
    state: started
    daemon_reload: "..."              # only when a unit file changed
```

The two unit files are templates: the timer has `OnCalendar=*-*-* 05:00:00` and `Persistent=true`, the service `Type=oneshot` and `ExecStart=<aide binary> --check --config <conf>`. Reference: `lab solution 4.08`.
