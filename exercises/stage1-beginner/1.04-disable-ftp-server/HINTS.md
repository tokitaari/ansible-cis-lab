# 1.04 - Stop and disable the FTP server

## Hint 1

`ansible.builtin.package_facts:` (no options) fills `ansible_facts.packages` - a dict keyed by package name.

## Hint 2

`when: "'vsftpd' in ansible_facts.packages"`

## Hint 3

```yaml
- name: Disable the FTP server
  hosts: "..."                   # every target
  become: "..."                  # stopping services needs root
  tasks:
    - name: Collect package facts
      ansible.builtin.package_facts:
    - name: Stop and disable vsftpd
      ansible.builtin.service:
        name: "..."              # the service
        state: "..."             # not running
        enabled: "..."           # not started at boot
      when: "..."                # only if the package is installed
```

Reference: `lab solution 1.04`.
