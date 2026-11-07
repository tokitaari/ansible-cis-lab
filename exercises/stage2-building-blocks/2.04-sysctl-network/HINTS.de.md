# 2.04 - Kernelparameter: Netzwerk-Härtung per sysctl

## Hinweis 1

`loop: "{{ cis_sysctl_network | dict2items }}"` liefert `item.key` und `item.value`. Übergib `value: "{{ item.value }}"` - das Modul nimmt den Wert ohnehin als Text, `0` und `"0"` landen also gleich.

## Hinweis 2

Netzwerk: `sysctl_file: /etc/sysctl.d/60-cis-network.conf`, `sysctl_set: true`, `reload: false` (Setzen reicht). Kernel: `sysctl_set: false` **und** `reload: false` - der Default `reload: true` würde die Datei laden und deinen Host ändern. Vor beiden: ein `file`-Task für `/etc/sysctl.d` - auf rocky und alma fehlt es, und das Modul scheitert mit `[Errno 2] No such file or directory`.

## Hinweis 3

Die Tasks des Playbooks als Gerüst - füll jedes `"..."` aus. Die beiden Dicts (`cis_sysctl_network`, `cis_sysctl_kernel`) gehören in `vars:` vor `tasks:`.

```yaml
- name: Ensure /etc/sysctl.d exists
  ansible.builtin.file:
    path: "..."
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Set and persist network parameters (namespaced - safe to apply)
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: "..."                # 60-cis-network.conf
    sysctl_set: "..."                 # live anwenden
    reload: "..."                     # Setzen reicht
  loop: "..."                         # das Netzwerk-Dict als Schlüssel/Wert-Paare

- name: Persist global kernel parameters (applied only on real hosts)
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: "..."                # 60-cis-kernel.conf
    sysctl_set: "..."                 # im Container nie live: lab_in_container
    reload: "..."                     # der Default true würde die ganze Datei laden
  loop: "..."
```

Referenz: `lab solution 2.04`.
