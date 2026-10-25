# 1.03 - SSH: forbid root login and empty passwords: Explanation

### Solution
```yaml
- name: Harden sshd authentication
  hosts: targets
  become: true
  tasks:
    - name: Deploy sshd hardening drop-in
      ansible.builtin.copy:
        dest: /etc/ssh/sshd_config.d/00-cis-hardening.conf
        content: |
          PermitRootLogin no
          PermitEmptyPasswords no
        owner: root
        group: root
        mode: "0600"
        validate: /usr/sbin/sshd -t -f %s
      notify: Reload sshd
  handlers:
    - name: Reload sshd
      ansible.builtin.service:
        name: "{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"
        state: reloaded
```

### First match wins
sshd uses the **first** value it reads for most keywords. With
`Include /etc/ssh/sshd_config.d/*.conf` at the top, `00-cis-hardening.conf` is read
before `10-lab-legacy.conf`, so your values win. Name it `99-...` and the legacy file
wins. Distribution files also live there (`50-redhat.conf` on EL, cloud-init files on
Ubuntu) - another reason for a low prefix.

### validate
Ansible writes the new content to a temp file, runs `sshd -t -f <tempfile>`, and only
moves it into place if the exit code is 0. Note: this validates the fragment *alone*.
A fragment that is only invalid in combination with others still passes - stage 2
adds a full-config check.

### Handlers
Handlers run once at the end of the play, only if notified. Five tasks changing sshd
settings → one reload. `reloaded` (SIGHUP) keeps existing connections - including the
one Ansible is using; `restarted` would also work for sshd, but reloading is the
gentler habit.

### Why not `lineinfile` on sshd_config?
You can - but distributions ship different main files, and package updates may
replace them. A drop-in you own completely is easier to reason about and to remove.

### Real world
Before touching sshd in production: keep a second session open, use `validate`,
and roll out in batches (`serial`, stage 5).

## Reference solution

Show it with `lab solution 1.03`, apply it with `lab solve 1.03`.
