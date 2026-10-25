# 1.04 - Stop and disable the FTP server

## Hint 1

`ansible.builtin.package_facts:` (no options) fills `ansible_facts.packages` - a dict keyed by package name.

## Hint 2

`when: "'vsftpd' in ansible_facts.packages"`

## Hint 3

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
