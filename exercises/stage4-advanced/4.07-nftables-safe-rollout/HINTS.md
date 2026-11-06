# 4.07 - Host firewall with nftables - safe rollout

## Hint 1

Per-family persistence path: Debian/Arch `/etc/nftables.conf`, RedHat `/etc/sysconfig/nftables.conf`, Alpine `/etc/nftables.nft`. Source network: `{{ ansible_facts.default_ipv4.network }}/{{ ansible_facts.default_ipv4.prefix }}`. That fact is part of the network facts: with `gather_subset: min` it is missing (`has no attribute 'default_ipv4'`).

## Hint 2

Dead-man switch: `ansible.builtin.shell: "nohup sh -c 'sleep 60; nft delete table inet cis_filter' >/dev/null 2>&1 & echo $!"` → register the PID (`nohup` and the redirects are hygiene: a plain `&` survived in tests too). Then `command: nft -f /etc/cis/nftables-cis.nft`, `ansible.builtin.meta: reset_connection` (the tasks after it open a new SSH connection; `wait_for_connection` opens its own on every attempt), `ansible.builtin.wait_for_connection: timeout=20` (keep the timeout well below the 60 s delay), `command: kill <pid>`.

## Hint 3

The activation as a skeleton - fill in every `"..."`:

```yaml
- name: Is our table loaded?
  ansible.builtin.command: nft list table inet cis_filter
  register: cis_fw_live
  changed_when: false
  failed_when: false
  check_mode: false

- name: Activate with a dead-man switch
  when: cis_fw_file is changed or cis_fw_live.rc != 0
  block:
    - name: Arm rollback (deletes our table unless cancelled)
      ansible.builtin.shell: "..."       # hint 2
      register: cis_fw_rollback
      changed_when: false

    - name: Load the ruleset
      ansible.builtin.command: "..."
      changed_when: true

    - name: Drop the persistent SSH connection
      ansible.builtin.meta: reset_connection

    - name: A new connection must still work
      ansible.builtin.wait_for_connection:
        timeout: "..."                   # well below the rollback delay

    - name: Disarm rollback
      ansible.builtin.command: "..."
      changed_when: false
```

`cis_fw_file` is the registered result of the template task. Persist the include and enable the service, but do not restart it: the unit of Debian, Ubuntu and the RedHat family runs `nft flush ruleset` on stop. Reference: `lab solution 4.07`.
