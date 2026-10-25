# 3.04 - auditd: Regeln und Log-Aufbewahrung (Level 2)

## Hinweis 1

`loop: "{{ cis_audit_rules | dict2items }}"` → `dest: "/etc/audit/rules.d/50-cis-{{ item.key }}.rules"`. Template-Inhalt: `{% for rule in item.value %}{{ rule }}\n{% endfor %}` (in einer Template-Datei ist `item` verfügbar).

## Hinweis 2

`auditd.conf` ist `schlüssel = wert`: `lineinfile` mit `regexp: '^\s*{{ item.key }}\s*='` und `line: "{{ item.key }} = {{ item.value }}"`, Schleife über ein Dict.

## Hinweis 3

Dienst-Task: `ansible.builtin.service: name=auditd state=started enabled=true` mit `when: not (lab_in_container | default(false))`. Referenz: `lab solution 3.04`.
