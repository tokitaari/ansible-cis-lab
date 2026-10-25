# 4.07 - Host firewall with nftables - safe rollout

## Hint 1

Per-family persistence path: Debian/Arch `/etc/nftables.conf`, RedHat `/etc/sysconfig/nftables.conf`, Alpine `/etc/nftables.nft`. Source network: `{{ ansible_facts.default_ipv4.network }}/{{ ansible_facts.default_ipv4.prefix }}`.

## Hint 2

Dead-man switch: `ansible.builtin.shell: "nohup sh -c 'sleep 60; nft delete table inet cis_filter' >/dev/null 2>&1 & echo $!"` → register the PID. Then `command: nft -f /etc/cis/nftables-cis.nft`, `ansible.builtin.meta: reset_connection` (forces a *new* SSH connection - an existing one would survive anyway), `ansible.builtin.wait_for_connection: timeout=20`, `command: kill <pid>`.

## Hint 3

Live check: `command: nft list table inet cis_filter` with `failed_when: false`, `changed_when: false`, `check_mode: false` → load `when: cis_fw_file is changed or cis_fw_live.rc != 0`. Do not restart the service: Debian's unit runs `nft flush ruleset` on stop. Reference: `lab solution 4.07`.
