# 2.01 - /etc/shadow: richtige Rechte je OS-Familie

## Hinweis 1

Für `os_family` brauchst du Facts - `gather_facts` eingeschaltet lassen. Zugriff: `shadow_perms[ansible_facts.os_family].mode`.

## Hinweis 2

Task 1: `ansible.builtin.stat` mit `loop: [/etc/shadow, /etc/gshadow]` und `register: shadow_files`. Task 2: `ansible.builtin.file` mit `loop: "{{ shadow_files.results }}"` und `when: item.stat.exists`. Der Pfad steht in `item.item`.

## Hinweis 3

```yaml
- name: Protect password hashes
  hosts: "..."
  become: "..."
  vars:
    shadow_perms:                # ein Eintrag pro os_family-Wert
      Debian: {group: "...", mode: "..."}
      Suse: {group: "...", mode: "..."}
      Alpine: {group: "...", mode: "..."}
      RedHat: {group: "...", mode: "..."}
      Archlinux: {group: "...", mode: "..."}
  tasks:
    - name: Find which shadow files exist
      ansible.builtin.stat:
        path: "..."              # das Schleifenelement
      loop: "..."                # die Pfade, gern auch die Sicherungen
      register: "..."
    - name: Set owner, group and mode per OS family
      ansible.builtin.file:
        path: "..."              # das ursprüngliche Element des stat-Ergebnisses
        owner: root
        group: "..."             # Lookup über ansible_facts.os_family
        mode: "..."
      loop: "..."                # die registrierten Ergebnisse
      when: "..."                # nur vorhandene Dateien
```

Referenz: `lab solution 2.01`.
