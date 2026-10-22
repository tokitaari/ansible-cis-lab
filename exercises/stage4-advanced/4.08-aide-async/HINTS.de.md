# 4.08 - Dateiintegrität mit AIDE - lang laufende Tasks

## Hinweis 1

Init-Task: `ansible.builtin.command:` mit `cmd: "{{ cis_aide.init_cmd }}"` und `creates: "{{ cis_aide.db }}"`, `async: 1800`, `poll: 0`, `register: cis_aide_job`. Die RedHat-Initialisierung braucht eine Shell (`aide --init && mv ...`) → dort `ansible.builtin.shell` oder `sh -c` im command nutzen.

## Hinweis 2

Warten: `ansible.builtin.async_status: jid: "{{ cis_aide_job.ansible_job_id }}"`, `register: job`, `until: job.finished`, `retries: 120`, `delay: 15` und `when: cis_aide_job.ansible_job_id is defined` (ein übersprungener Task hat keine Job-ID).

## Hinweis 3

Timer: `OnCalendar=*-*-* 05:00:00`, `Persistent=true`; Service: `Type=oneshot`, `ExecStart=<aide-binary> --check --config <conf>`. Nutze `ansible.builtin.systemd_service` mit `daemon_reload: true`. Referenz: `lab solution 4.08`.
