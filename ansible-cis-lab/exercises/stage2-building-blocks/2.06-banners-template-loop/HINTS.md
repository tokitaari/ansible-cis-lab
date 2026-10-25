# 2.06 - All login banners from one template

## Hint 1

`ansible.builtin.template` with `src: banner.j2` and `dest: "{{ item }}"`.

## Hint 2

The template is plain text with `{{ lab_org_name }}` - no `ansible_managed` line here, users see this text!

## Hint 3

```yaml
- name: Deploy login banners
  ansible.builtin.template:
    src: banner.j2
    dest: "{{ item }}"
    owner: root
    group: root
    mode: "0644"
  loop: [/etc/motd, /etc/issue, /etc/issue.net]
```
