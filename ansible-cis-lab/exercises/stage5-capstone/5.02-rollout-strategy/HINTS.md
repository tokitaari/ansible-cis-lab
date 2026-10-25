# 5.02 - Rollout strategy: preflight, canary, batches

## Hint 1

Preflight checks: `ansible.builtin.command: /usr/sbin/sshd -t` and `/usr/sbin/visudo -c` (both `changed_when: false`, `check_mode: false`); free space from facts: `ansible_facts.mounts | selectattr('mount', 'equalto', '/') | map(attribute='size_available') | first`.

## Hint 2

Canary play: `hosts: "{{ cis_canary | default('debian,rocky') }}"`. Remaining: `hosts: "targets:!{{ cis_canary | default('debian,rocky') | replace(',', ':!') }}"`. `serial` and `max_fail_percentage` are play keywords.

## Hint 3

Reference: `lab solution 5.02` (expects the 5.01 role in `/lab/work/roles/cis` or uses the reference role next to it).
