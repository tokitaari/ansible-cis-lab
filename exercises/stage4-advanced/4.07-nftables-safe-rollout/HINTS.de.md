# 4.07 - Host-Firewall mit nftables - sicherer Rollout

## Hinweis 1

Persistenzpfad je Familie: Debian/Arch `/etc/nftables.conf`, RedHat `/etc/sysconfig/nftables.conf`, Alpine `/etc/nftables.nft`. Quellnetz: `{{ ansible_facts.default_ipv4.network }}/{{ ansible_facts.default_ipv4.prefix }}`.

## Hinweis 2

Totmannschalter: `ansible.builtin.shell: "nohup sh -c 'sleep 60; nft delete table inet cis_filter' >/dev/null 2>&1 & echo $!"` → PID registrieren. Dann `command: nft -f /etc/cis/nftables-cis.nft`, `ansible.builtin.meta: reset_connection` (erzwingt eine *neue* SSH-Verbindung - eine bestehende würde ohnehin überleben), `ansible.builtin.wait_for_connection: timeout=20`, `command: kill <pid>`.

## Hinweis 3

Live-Prüfung: `command: nft list table inet cis_filter` mit `failed_when: false`, `changed_when: false`, `check_mode: false` → laden mit `when: cis_fw_file is changed or cis_fw_live.rc != 0`. Dienst nicht neu starten: Debians Unit führt beim Stoppen `nft flush ruleset` aus. Referenz: `lab solution 4.07`.
