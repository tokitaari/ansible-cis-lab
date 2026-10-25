# 4.05 - Custom Facts: Hosts beschreiben ihre eigene Härtung

## Hinweis 1

Statisch: `copy` mit `content: "{{ {'baseline': 'lab-cis', 'version': '1.0.0', 'level': 1, 'managed_by': 'ansible'} | to_nice_json }}"`. Das Verzeichnis `/etc/ansible/facts.d` muss vorher existieren.

## Hinweis 2

Skript für den ausführbaren Fact: `uid0=$(awk -F: '$3 == 0' /etc/passwd | wc -l)`, `prl=$(/usr/sbin/sshd -T 2>/dev/null | awk '$1=="permitrootlogin"{print $2}')`, dann `printf '{"uid0_accounts": %d, "permit_root_login": "%s"}\n' "$uid0" "${prl:-unknown}"`.

## Hinweis 3

Auffrischen: `ansible.builtin.setup: filter: ansible_local`. Bericht: über `groups['targets']` iterieren, `hostvars[h].ansible_local.cis.version` usw. lesen. Referenz: `lab solution 4.05`.
