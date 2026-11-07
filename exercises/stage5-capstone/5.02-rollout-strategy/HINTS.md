# 5.02 - Rollout strategy: preflight, canary, batches

## Hint 1

Preflight checks: `ansible.builtin.command: /usr/sbin/sshd -t` and `/usr/sbin/visudo -c` (both `changed_when: false`, `check_mode: false`; on openSUSE `visudo -c` exits 1 because of `/usr/etc/sudoers` - see 1.05 - so register it and decide with `failed_when`); free space: `df -Pk /` (also `changed_when: false`, `check_mode: false`), 4th field of the last line in KiB - not from `ansible_facts.mounts`, which has no entry for a container's overlay root (see the explanation).

## Hint 2

Canary play: `hosts: "{{ cis_canary | default('debian,rocky') }}"`. Remaining: `hosts: "targets:!{{ cis_canary | default('debian,rocky') | replace(',', ':!') }}"`. `serial` and `max_fail_percentage` are play keywords. A percentage in `serial` is a share of the hosts of the play (rounded down, at least one), not of the hosts that remain.

## Hint 3

The skeleton - fill in every `"..."`:

```yaml
- name: Preflight - every host must be healthy, otherwise nothing happens
  hosts: targets
  become: true
  any_errors_fatal: true
  vars:
    cis_min_free_bytes: "..."        # 200 MB in bytes
  tasks:
    - name: Operator confirmed the rollout
      ansible.builtin.assert:
        that: "..."                  # the extra var; without it the play must fail
      run_once: true

    - name: Current sshd configuration is valid
      ansible.builtin.command: "..."
      changed_when: false
      check_mode: false

    - name: Current sudo configuration is valid
      ansible.builtin.command: "..."
      register: cis_visudo
      changed_when: false
      check_mode: false
      failed_when: "..."             # openSUSE: tolerate only the /usr/etc permission complaint

    - name: Read free space on /
      ansible.builtin.command: "..."
      register: cis_df_root
      changed_when: false
      check_mode: false

    - name: Enough free space on /
      ansible.builtin.assert:
        that: "..."                  # 4th field of the last line, KiB to bytes

- name: Canary
  hosts: "..."                       # hint 2
  become: true
  roles:
    - role: cis
      vars:
        cis_mode: enforce
  post_tasks:
    - name: Post-check | drop the persistent SSH connection
      ansible.builtin.meta: "..."

    - name: Post-check | a fresh login still works
      ansible.builtin.wait_for_connection:
        timeout: "..."

    - name: Post-check | read effective sshd settings
      ansible.builtin.command: "..."
      register: cis_post_sshd
      changed_when: false
      check_mode: false

    - name: Post-check | root login is still disabled
      ansible.builtin.assert:
        that: "..."                  # the keyword's case differs between hosts

- name: Remaining hosts in growing batches
  hosts: "..."                       # hint 2
  become: true
  serial: "..."                      # one host, then a share, then the rest
  max_fail_percentage: "..."         # stop at the first failure
  roles:
    - role: cis
      vars:
        cis_mode: enforce
  post_tasks: []                     # the same four post-check tasks; put them in one file and include it from both plays
```

Reference: `lab solution 5.02` (expects the 5.01 role in `/lab/work/roles/cis` or uses the reference role next to it).
