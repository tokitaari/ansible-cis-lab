# 2.03 - Disable unneeded kernel modules

## Hint 1

`loop: "{{ cis_disabled_modules_l1 }}"` and use `{{ item }}` in `dest` and `content`.

## Hint 2

`content:` can be a multi-line string: `content: |` followed by two indented lines that use `{{ item }}`.

## Hint 3

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
