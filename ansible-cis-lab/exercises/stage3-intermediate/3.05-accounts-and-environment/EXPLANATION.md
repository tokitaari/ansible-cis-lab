# 3.05 - Account audit: UID 0, empty passwords, umask, TMOUT: Explanation

### Discovery before remediation
```yaml
- name: Find dangerous accounts
  ansible.builtin.set_fact:
    cis_uid0_extra: >-
      {{ (cis_passwd.content | b64decode).splitlines() | map('split', ':')
         | selectattr('2', 'equalto', '0') | map(attribute='0')
         | reject('equalto', 'root') | list }}
```
Jinja turns numeric attribute names into list indexes, so `selectattr('2', ...)`
filters by the UID column. Parsing files beats shelling out to `awk`: it works the
same on all eight systems (busybox, GNU, ...).

### The userdel trap
`userdel` checks whether any process runs with the account's UID - for UID 0 that is
always true. `force: true` (`userdel -f`) skips that check. Never combine it with
`remove: true` here: the home of a UID-0 alias is often `/root`.

### Lock, don't delete, unknown accounts
`guest` might be used by an application. Locking (`!` in front of the hash) is
reversible; deletion is not. Report it and let a human decide on deletion.

### umask and TMOUT
- `umask 027` → new files `0640`, directories `0750`.
- `readonly TMOUT` stops `unset TMOUT`. It only affects interactive shells; it is not
  a replacement for sshd's `ClientAlive*` settings - you need both.
- `/etc/profile.d/*.sh` is read by login shells of bash, dash, busybox ash. Users of
  other shells (zsh, fish) need their own files - document it.

### Real world
In production run the discovery part as a separate audit play first (see stage 4)
and review the findings - automatically deleting accounts on 2,000 servers because of
a parsing bug is a bad day.

## Reference solution

Show it with `lab solution 3.05`, apply it with `lab solve 3.05`.
