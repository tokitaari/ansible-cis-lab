# 4.07 - Host-Firewall mit nftables - sicherer Rollout

## Hinweis 1

Persistenzpfad je Familie: Debian/Arch `/etc/nftables.conf`, RedHat `/etc/sysconfig/nftables.conf`, Alpine `/etc/nftables.nft`. Quellnetz: `{{ ansible_facts.default_ipv4.network }}/{{ ansible_facts.default_ipv4.prefix }}`. Dieses Fact gehört zu den Netzwerk-Facts: mit `gather_subset: min` fehlt es (`has no attribute 'default_ipv4'`).

## Hinweis 2

Totmannschalter: `ansible.builtin.shell: "nohup sh -c 'sleep 60; nft delete table inet cis_filter' >/dev/null 2>&1 & echo $!"` → PID registrieren (`nohup` und die Umleitungen sind Hygiene: ein einfaches `&` überlebte in Tests ebenfalls). Dann `command: nft -f /etc/cis/nftables-cis.nft`, `ansible.builtin.meta: reset_connection` (die Tasks danach öffnen eine neue SSH-Verbindung; `wait_for_connection` öffnet bei jedem Versuch eine eigene), `ansible.builtin.wait_for_connection: timeout=20` (das Timeout deutlich unter der 60-s-Verzögerung halten), `command: kill <pid>`.

## Hinweis 3

Die Aktivierung als Gerüst - fülle jedes `"..."` aus:

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
      ansible.builtin.shell: "..."       # Hinweis 2
      register: cis_fw_rollback
      changed_when: false

    - name: Load the ruleset
      ansible.builtin.command: "..."
      changed_when: true

    - name: Drop the persistent SSH connection
      ansible.builtin.meta: reset_connection

    - name: A new connection must still work
      ansible.builtin.wait_for_connection:
        timeout: "..."                   # deutlich unter der Rollback-Verzögerung

    - name: Disarm rollback
      ansible.builtin.command: "..."
      changed_when: false
```

`cis_fw_file` ist das registrierte Ergebnis des Template-Tasks. Das Include persistieren und den Dienst aktivieren, aber nicht neu starten: Die Unit von Debian, Ubuntu und der RedHat-Familie führt beim Stoppen `nft flush ruleset` aus. Referenz: `lab solution 4.07`.
