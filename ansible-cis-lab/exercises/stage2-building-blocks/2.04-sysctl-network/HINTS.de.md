# 2.04 - Kernelparameter: Netzwerk-Härtung per sysctl

## Hinweis 1

`loop: "{{ cis_sysctl_network | dict2items }}"` liefert `item.key` und `item.value`. Übergib `value: "{{ item.value }}"` (Strings sind am sichersten).

## Hinweis 2

Netzwerk: `sysctl_file: /etc/sysctl.d/60-cis-network.conf`, `sysctl_set: true`, `reload: false` (Setzen reicht). Kernel: `sysctl_set: false` **und** `reload: false` - der Default `reload: true` würde die Datei laden und deinen Host ändern.

## Hinweis 3

```yaml
- name: Persist global kernel parameters (no live change in the lab)
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: /etc/sysctl.d/60-cis-kernel.conf
    sysctl_set: false
    reload: false
  loop: "{{ cis_sysctl_kernel | dict2items }}"
```
