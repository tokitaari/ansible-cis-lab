# 4.08 - Dateiintegrität mit AIDE - lang laufende Tasks

## Hinweis 1

Init-Task: `ansible.builtin.command:` mit `cmd: "{{ cis_aide.init_cmd }}"` und `creates: "{{ cis_aide.db }}"`, `async: 1800`, `poll: 0`, `register: cis_aide_job`. Mit `poll: 0` meldet der Task `changed`, sobald der Job startet - `creates:` wirkt erst im Job - also davor ein `stat` auf die Datenbank und `when: not cis_aide_db.stat.exists`. Die RedHat-Initialisierung braucht eine Shell (`aide --init && mv ...`) → dort `ansible.builtin.shell` oder `sh -c` im command nutzen.

## Hinweis 2

Warten: `ansible.builtin.async_status: jid: "{{ cis_aide_job.ansible_job_id }}"`, `register: job`, `until: job.finished`, `retries: 120`, `delay: 15` (120 × 15 s = die 1800 s von `async`) und `when: cis_aide_job.ansible_job_id is defined` (ein übersprungener Task hat keine Job-ID).

## Hinweis 3

Die Tasks als Gerüst - fülle jedes `"..."` aus. Die Werte je Familie (Pakete, Binary, Konfiguration, Datenbank, Init-Befehl) gehören vor `tasks:` in ein Dict, das über `ansible_facts.os_family` gewählt wird.

```yaml
- name: Look for an apt package index
  ansible.builtin.find:
    paths: "..."
    patterns: "..."                   # die Index-Dateien, *_Packages*
  register: cis_apt_lists
  check_mode: false
  when: "..."                         # nur Debian-Familie

- name: Refresh the apt package index
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: "..."           # 0, solange keine Index-Datei existiert, sonst ein Tag
  changed_when: false
  check_mode: false
  when: "..."

- name: Install AIDE
  ansible.builtin.package:
    name: "..."                       # Pakete je Familie
    state: present

- name: Look for an existing database
  ansible.builtin.stat:
    path: "..."
  register: cis_aide_db

- name: Build the initial database in the background
  ansible.builtin.command:
    cmd: "..."                        # je Familie, siehe Tabelle in der README
    creates: "..."
  async: "..."
  poll: "..."
  register: cis_aide_job
  when: "..."                         # nur ohne Datenbank

- name: Wait for the database
  ansible.builtin.async_status:
    jid: "..."
  register: cis_aide_result
  until: "..."
  retries: "..."                      # retries * delay sollte async abdecken
  delay: "..."
  when: "..."                         # ein übersprungener Task hat keine Job-ID

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
    daemon_reload: "..."              # nur wenn sich eine Unit-Datei geändert hat
```

Die beiden Unit-Dateien sind Templates: der Timer hat `OnCalendar=*-*-* 05:00:00` und `Persistent=true`, der Service `Type=oneshot` und `ExecStart=<aide-binary> --check --config <conf>`. Referenz: `lab solution 4.08`.
