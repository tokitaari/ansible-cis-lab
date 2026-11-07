# 2.06 - All login banners from one template

## Hint 1

`ansible.builtin.template` with `src: banner.j2` and `dest: "{{ item }}"`.

## Hint 2

The template is plain text with `{{ lab_org_name }}` - no `ansible_managed` line here, users see this text! Use no getty escapes at all: the check only spots `\m \r \s \v`, but `\S` or `\n` leak the system just as well.

## Hint 3

The task as a skeleton - fill in every `"..."`. `templates/banner.j2` is two plain lines: the organisation name with "authorized access only", and the monitoring warning.

```yaml
- name: Deploy login banners
  ansible.builtin.template:
    src: "..."                        # one template for all three files
    dest: "..."                       # the loop item
    owner: root
    group: root
    mode: "0644"
  loop: "..."                         # /etc/motd, /etc/issue, /etc/issue.net
```

Reference: `lab solution 2.06`.
