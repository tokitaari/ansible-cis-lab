# 2.05 - Job-Scheduler: cron-Rechte und Zugriff

## Hinweis 1

Bau eine Liste von Dicts: `[{path: /etc/crontab, mode: '0600'}, {path: /etc/cron.d, mode: '0700'}, ...]`, `stat` auf jedes `item.path`, dann über die Ergebnisse iterieren mit `when: item.stat.exists` und `item.item.mode`.

## Hinweis 2

Dienst: `name: "{{ cron_service[ansible_facts.os_family] }}"`. Für `cron.allow` `copy` mit `content: "root\n"` und `when: ansible_facts.os_family != 'Alpine'`. Alpine bekommt einen eigenen Task: `/etc/crontabs` als Verzeichnis, `root:root`, `0700`. Diese eine Ausnahme ist ok - der Rest ist datengetrieben.

## Hinweis 3

Die Tasks des Playbooks als Gerüst - füll jedes `"..."` aus. Das Dienst-Dict und die Liste der `{path, mode}`-Dicts gehören in `vars:` vor `tasks:`.

```yaml
- name: Find existing cron paths
  ansible.builtin.stat:
    path: "..."
  loop: "..."                         # die Liste der Pfad/Modus-Dicts
  register: cron_stat

- name: Restrict cron files and directories
  ansible.builtin.file:
    path: "..."                       # der Pfad aus dem ursprünglichen Loop-Item
    owner: root
    group: root
    mode: "..."
  loop: "..."                         # die stat-Ergebnisse
  loop_control:
    label: "{{ item.item.path }}"
  when: "..."                         # nur vorhandene Pfade

- name: Restrict crontab usage to root (not supported by busybox crontab)
  ansible.builtin.copy:
    dest: /etc/cron.allow
    content: "..."
    owner: root
    group: root
    mode: "0640"
  when: "..."                         # jede Familie außer Alpine

- name: Remove cron.deny (ignored once cron.allow exists)
  ansible.builtin.file:
    path: /etc/cron.deny
    state: "..."
  when: "..."

- name: Alpine - restrict the spool directory instead
  ansible.builtin.file:
    path: "..."
    state: directory
    owner: root
    group: root
    mode: "0700"
  when: "..."

- name: Cron daemon is enabled and running
  ansible.builtin.service:
    name: "..."                       # Dict-Lookup je os_family
    state: started
    enabled: true
```

Referenz: `lab solution 2.05`.
