# 2.03 - Unnötige Kernelmodule deaktivieren

## Hinweis 1

`loop: "{{ cis_disabled_modules_l1 }}"` und `{{ item }}` in `dest` und `content` verwenden.

## Hinweis 2

`content:` darf mehrzeilig sein: `content: |` gefolgt von zwei eingerückten Zeilen mit `{{ item }}`.

## Hinweis 3

```yaml
- name: Disable kernel module
  ansible.builtin.copy:
    dest: "/etc/modprobe.d/cis-{{ item }}.conf"
    content: |
      install {{ item }} /bin/false
      blacklist {{ item }}
    owner: root
    group: root
    mode: "0644"
  loop: "{{ cis_disabled_modules_l1 }}"
```
