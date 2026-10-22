# 4.08 - File integrity with AIDE - long-running tasks

## Hint 1

Init task: `ansible.builtin.command:` with `cmd: "{{ cis_aide.init_cmd }}"` and `creates: "{{ cis_aide.db }}"`, `async: 1800`, `poll: 0`, `register: cis_aide_job`. RedHat init needs a shell (`aide --init && mv ...`) → use `ansible.builtin.shell` there or `sh -c` in the command.

## Hint 2

Wait: `ansible.builtin.async_status: jid: "{{ cis_aide_job.ansible_job_id }}"`, `register: job`, `until: job.finished`, `retries: 120`, `delay: 15`, and `when: cis_aide_job.ansible_job_id is defined` (a skipped task has no job id).

## Hint 3

Timer: `OnCalendar=*-*-* 05:00:00`, `Persistent=true`; service: `Type=oneshot`, `ExecStart=<aide binary> --check --config <conf>`. Use `ansible.builtin.systemd_service` with `daemon_reload: true`. Reference: `lab solution 4.08`.
