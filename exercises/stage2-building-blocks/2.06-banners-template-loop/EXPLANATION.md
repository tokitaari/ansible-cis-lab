# 2.06 - All login banners from one template: Explanation

### Solution
```yaml
- name: CIS 1.6 - warning banners
  hosts: targets
  become: true
  tasks:
    - name: Deploy login banners
      ansible.builtin.template:
        src: banner.j2
        dest: "{{ item }}"
        owner: root
        group: root
        mode: "0644"
      loop: [/etc/motd, /etc/issue, /etc/issue.net]
```
`templates/banner.j2`:
```
{{ lab_org_name }} - authorized access only.
Activity on this system is monitored and logged. Disconnect now if you are not an authorized user.
```

### Where variables come from
`lab_org_name` lives in `/lab/ansible/inventory/group_vars/all.yml`. Variable
precedence (low → high, simplified): role defaults → inventory group_vars (all → child
groups) → host_vars → play vars → `-e` extra vars. `ansible-inventory --host alpine`
shows the result.

### No `ansible_managed` here
In config files the comment is helpful; in a banner every user would read
"Ansible managed". Choose deliberately.

### Dynamic MOTD (bonus)
Ubuntu builds the login message from scripts in `/etc/update-motd.d/` - some print
the kernel and distribution version. CIS cares about what the user *sees*; disable
those scripts (remove the execute bit) or the `pam_motd` dynamic part.

## Reference solution

Show it with `lab solution 2.06`, apply it with `lab solve 2.06`.
