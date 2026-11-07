# 2.03 - Unnötige Kernelmodule deaktivieren

## Hinweis 1

`loop: "{{ cis_disabled_modules_l1 }}"` und `{{ item }}` in `dest` und `content` verwenden.

## Hinweis 2

`content:` darf mehrzeilig sein: `content: |` gefolgt von zwei eingerückten Zeilen mit `{{ item }}`.

## Hinweis 3

```yaml
- name: CIS - disable unneeded kernel modules
  hosts: "..."
  become: "..."
  vars:
    cis_disabled_modules_l1: ["..."]   # die sechs Namen aus der README
  tasks:
    - name: Disable kernel module
      ansible.builtin.copy:
        dest: "..."              # eine Datei pro Modul, benannt nach dem Schleifenelement
        content: "..."           # die zwei Zeilen install und blacklist, z. B. als Blockskalar |
        owner: root
        group: root
        mode: "..."
      loop: "..."
```

Kein `modprobe`-Task: In den Lab-Containern würde er auf den Host-Kernel wirken.

Referenz: `lab solution 2.03`.
