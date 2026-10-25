# 4.05 - Custom facts: hosts that describe their own hardening

## Hint 1

Static: `copy` with `content: "{{ {'baseline': 'lab-cis', 'version': '1.0.0', 'level': 1, 'managed_by': 'ansible'} | to_nice_json }}"`. Directory `/etc/ansible/facts.d` must exist first.

## Hint 2

Executable fact script: `uid0=$(awk -F: '$3 == 0' /etc/passwd | wc -l)`, `prl=$(/usr/sbin/sshd -T 2>/dev/null | awk '$1=="permitrootlogin"{print $2}')`, then `printf '{"uid0_accounts": %d, "permit_root_login": "%s"}\n' "$uid0" "${prl:-unknown}"`.

## Hint 3

Refresh: `ansible.builtin.setup: filter: ansible_local`. Report: iterate `groups['targets']`, read `hostvars[h].ansible_local.cis.version` etc. Reference: `lab solution 4.05`.
