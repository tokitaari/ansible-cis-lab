# 2.01 - /etc/shadow: richtige Rechte je OS-Familie

## Hinweis 1

Für `os_family` brauchst du Facts - `gather_facts` eingeschaltet lassen. Zugriff: `shadow_perms[ansible_facts.os_family].mode`.

## Hinweis 2

Task 1: `ansible.builtin.stat` mit `loop: [/etc/shadow, /etc/gshadow]` und `register: shadow_files`. Task 2: `ansible.builtin.file` mit `loop: "{{ shadow_files.results }}"` und `when: item.stat.exists`. Der Pfad steht in `item.item`.

## Hinweis 3

```yaml
vars:
  shadow_perms:
    Debian: {group: shadow, mode: "0640"}
    Suse: {group: shadow, mode: "0640"}
    Alpine: {group: shadow, mode: "0640"}
    RedHat: {group: root, mode: "0000"}
    Archlinux: {group: root, mode: "0600"}
...
- ansible.builtin.file:
    path: "{{ item.item }}"
    owner: root
    group: "{{ shadow_perms[ansible_facts.os_family].group }}"
    mode: "{{ shadow_perms[ansible_facts.os_family].mode }}"
  loop: "{{ shadow_files.results }}"
  when: item.stat.exists
```
