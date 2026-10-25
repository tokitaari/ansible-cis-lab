# 1.04 - FTP-Server stoppen und deaktivieren

## Hinweis 1

`ansible.builtin.package_facts:` (ohne Optionen) füllt `ansible_facts.packages` - ein Dict mit dem Paketnamen als Schlüssel.

## Hinweis 2

`when: "'vsftpd' in ansible_facts.packages"`

## Hinweis 3

```yaml
- name: Collect package facts
  ansible.builtin.package_facts:
- name: Stop and disable vsftpd
  ansible.builtin.service:
    name: vsftpd
    state: stopped
    enabled: false
  when: "'vsftpd' in ansible_facts.packages"
```
