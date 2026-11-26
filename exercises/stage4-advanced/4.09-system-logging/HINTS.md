# 4.09 - System logging: one logger per host, chosen by data

## Hint 1

Look first: `ansible 'targets:!alpine' -m ansible.builtin.command -a "systemd-analyze cat-config systemd/journald.conf"` lists every file in the order journald reads it, and the last value of a key wins. Compare debian with rocky, and look for `/var/log/journal` on both. The choice itself is one line: `cis_logger: "{{ cis_logger_by_family[ansible_facts.os_family] }}"`, checked by an `ansible.builtin.assert` before the first change; every block of the play then has `when:` on `cis_logger`.

## Hint 2

- debian and ubuntu ship a drop-in in `/usr/lib/systemd/journald.conf.d/` that sets `ForwardToSyslog=yes`. Drop-ins are sorted by file name across directories, so it is read after `60-cis.conf`. A file of the same name in `/etc/systemd/journald.conf.d/` replaces it; a symlink to `/dev/null` removes it. Find such files with `ansible.builtin.find` and `contains:` instead of hard-coding a name - and only on the journald-only hosts.
- rocky and alma have no `/var/log/journal`. After a restart with `Storage=persistent`, journald still writes to `/run/log/journal` until `journalctl --flush` asks it to move. Two handlers that `listen:` to the same name run one after the other, in the order of the `handlers:` section.
- `validate: rsyslogd -N1 -f %s` rejects a valid drop-in (a drop-in has no actions). Run `rsyslogd -N1` (the whole configuration) as a task after the drop-in: a failed task stops the host, and its pending handlers do not run.
- On Alpine, `ansible.builtin.service` with `enabled: true` adds the service to the runlevel `default`.

## Hint 3

The tasks as a skeleton - fill in every `"..."`. The data (`cis_logger_by_family`, `cis_logger`, the journald keys as a dict, the syslogd options) belongs in `vars:`.

```yaml
- name: The logger of this host is a known one
  ansible.builtin.assert:
    that: "..."                       # cis_logger is one of the three names
    fail_msg: "..."

- name: Configure journald (every systemd host)
  when: "..."                         # journald or rsyslog
  block:
    - name: Drop-in directory
      ansible.builtin.file:
        path: "..."
        state: directory
        mode: "0755"

    - name: CIS drop-in
      ansible.builtin.template:
        src: "..."                    # [Journal] + one Key=value per dict item;
        dest: "..."                   # ForwardToSyslog=no only for journald
        mode: "0644"
      notify: "..."                   # the name both journald handlers listen to

    - name: Vendor drop-in directory
      ansible.builtin.stat:
        path: "..."
      register: cis_vendor_dir

    - name: Vendor drop-ins that set ForwardToSyslog
      ansible.builtin.find:
        paths: "..."
        patterns: "*.conf"
        contains: "..."
      register: cis_vendor_forward
      when: "..."                     # only if the directory exists

    - name: Mask them on journald-only hosts
      ansible.builtin.file:
        src: "..."
        dest: "..."                   # same file name, under /etc
        state: link
      loop: "..."                     # the files found, [] when skipped
      when: "..."
      notify: "..."

- name: Configure rsyslog
  when: "..."
  block:
    - name: Package
      ansible.builtin.package:
        name: "..."
        state: present

    - name: CIS drop-in
      ansible.builtin.copy:
        dest: "..."
        content: "..."
        mode: "0644"
      notify: "..."

    - name: Whole configuration is valid
      ansible.builtin.command: "..."
      changed_when: "..."

    - name: Service
      ansible.builtin.service:
        name: "..."
        enabled: "..."
        state: "..."

- name: Configure busybox syslogd
  when: "..."
  block:
    - name: Rotation options
      ansible.builtin.lineinfile:
        path: "..."
        regexp: "..."
        line: "..."
      notify: "..."

    - name: Service in the default runlevel
      ansible.builtin.service:
        name: "..."
        enabled: "..."
        state: "..."
```

The handlers: `ansible.builtin.systemd_service` restarts `systemd-journald` and `ansible.builtin.command: journalctl --flush` (with `changed_when: true`) moves the journal, both with the same `listen:`; one `ansible.builtin.service` handler each restarts `rsyslog` and `syslog`. Reference: `lab solution 4.09`.
