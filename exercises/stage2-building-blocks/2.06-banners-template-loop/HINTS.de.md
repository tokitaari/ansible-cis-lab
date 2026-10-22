# 2.06 - Alle Login-Banner aus einem Template

## Hinweis 1

`ansible.builtin.template` mit `src: banner.j2` und `dest: "{{ item }}"`.

## Hinweis 2

Das Template ist reiner Text mit `{{ lab_org_name }}` - hier keine `ansible_managed`-Zeile, Benutzer sehen diesen Text!

## Hinweis 3

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
