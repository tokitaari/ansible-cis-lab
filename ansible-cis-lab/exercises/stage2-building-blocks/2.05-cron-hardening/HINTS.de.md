# 2.05 - Job-Scheduler: cron-Rechte und Zugriff

## Hinweis 1

Bau eine Liste von Dicts: `[{path: /etc/crontab, mode: '0600'}, {path: /etc/cron.d, mode: '0700'}, ...]`, `stat` auf jedes `item.path`, dann über die Ergebnisse iterieren mit `when: item.stat.exists` und `item.item.mode`.

## Hinweis 2

Dienst: `name: "{{ cron_service[ansible_facts.os_family] }}"`. Für `cron.allow` `copy` mit `content: "root\n"` und `when: ansible_facts.os_family != 'Alpine'`.

## Hinweis 3

Alpine-Task: `ansible.builtin.file: path=/etc/crontabs state=directory owner=root group=root mode="0700"` mit `when: ansible_facts.os_family == 'Alpine'`. Diese eine Ausnahme ist ok - der Rest ist datengetrieben.
