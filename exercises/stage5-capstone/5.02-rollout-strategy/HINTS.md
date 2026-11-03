# 5.02 - Rollout strategy: preflight, canary, batches

## Hint 1

Preflight checks: `ansible.builtin.command: /usr/sbin/sshd -t` and `/usr/sbin/visudo -c` (both `changed_when: false`, `check_mode: false`; on openSUSE `visudo -c` exits 1 because of `/usr/etc/sudoers` - see 1.05 - so register it and decide with `failed_when`); free space: `df -Pk /` (also `changed_when: false`, `check_mode: false`), 4th field of the last line in KiB - not from `ansible_facts.mounts`, which has no entry for a container's overlay root (see the explanation).

## Hint 2

Canary play: `hosts: "{{ cis_canary | default('debian,rocky') }}"`. Remaining: `hosts: "targets:!{{ cis_canary | default('debian,rocky') | replace(',', ':!') }}"`. `serial` and `max_fail_percentage` are play keywords.

## Hint 3

Reference: `lab solution 5.02` (expects the 5.01 role in `/lab/work/roles/cis` or uses the reference role next to it).
