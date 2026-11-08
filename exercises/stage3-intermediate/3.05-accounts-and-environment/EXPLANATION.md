# 3.05 - Account audit: UID 0, empty passwords, umask, TMOUT: Explanation

### What the check verifies
`lab check 3.05` runs `check.yml` on `targets`: it parses `/etc/passwd` and `/etc/shadow` and
asserts that `root` is the only UID 0 account and that no password field is empty. In
`/etc/profile.d/50-cis-umask.sh` it wants a line matching `umask 0?27`; in `50-cis-tmout.sh` a
`TMOUT=<n>` with n ≤ 900 and a line starting with `readonly TMOUT`. Then your playbook runs once
more with `--check` and must report `changed=0`.

What it does not verify:

- `TMOUT=0` passes, but 0 switches the timeout off. `umask 0027` **fails** (the regex allows only
  `027` or `27`).
- Owner and mode of the two files, `export TMOUT`, and whether any shell reads them.
- Locked or deleted: a deleted `guest` passes as well.

### How it works

#### Discovery before remediation
```yaml
- name: Find dangerous accounts
  ansible.builtin.set_fact:
    cis_uid0_extra: >-
      {{ (cis_account_files.results[0].content | b64decode).splitlines() | map('split', ':')
         | selectattr('2', 'equalto', '0') | map(attribute='0')
         | reject('equalto', 'root') | list }}
```
Jinja turns numeric attribute names into list indexes, so `selectattr('2', ...)` filters by the
UID column. Parsing the files works the same on all eight systems (no `awk` dialects). Measured
in run 1: `toor` found on debian and rocky, `guest` on ubuntu and fedora; run 2 finds empty
lists, the loops do nothing (`changed=0`).

#### The `userdel` trap
`userdel` refuses to delete an account whose UID owns a running process; for UID 0 that is always
true. Measured on debian and rocky: `userdel toor` exits with 8, `user toor is currently used by
process 1`. `force: true` (`userdel -f`) prints the same line but deletes (session test).
`remove: true` must stay off: `userdel -r -f` on a UID 0 alias removed its home directory
although root owned it (session test with a scratch directory). The lab's `toor` has
`/nonexistent` as home, a real alias may have `/root`; after the solution `/root` is untouched
(measured).

#### Lock, don't delete
`password_lock: true` puts `!` into the password field (measured: `guest:!`). Locking is
reversible, deletion is not; report the account and let a human decide.

#### umask
`umask 027` gives new files `0640` and directories `0750`. The file in `/etc/profile.d` reaches
**login shells**. Measured as a new account (`su -`, and `<shell> -l -i -c`), bash and `sh`:

- before: `0002` on debian and ubuntu, `0022` elsewhere;
- after: `0027` everywhere, with one exception: on alpine `su - -s /bin/bash -c` still showed
  `0022` (BusyBox `su`; `sh` through the same `su -` and `bash -l -i -c` gave `0027`; not
  investigated).

Commands that Ansible runs are not login shells: with `become` they kept `0022` on five hosts, but
on rocky, alma and fedora they showed `0027` after the exercise (`0022` before). Their
`/etc/bashrc` runs the `profile.d` loop for non-login shells; the path from Ansible's SSH command
to it was not traced. There, tasks without an explicit `mode:` create stricter files.

#### TMOUT and `readonly`
`TMOUT` is a shell feature. Measured with an idle shell in a pseudo-terminal and `TMOUT=2`
before the exercise: bash exited after 2 s on all eight hosts, BusyBox `ash` (alpine) too, **dash
did not** - and dash is `/bin/sh` on debian and ubuntu, where `useradd -D` also gives new accounts
`/bin/sh`. There the file sets a variable that nobody honours.

`readonly` stops `TMOUT=0` and `unset TMOUT` in that shell only: the attribute is not inherited,
a child `bash` can unset the exported value (session test). Sourcing the file twice in one shell
prints `TMOUT: readonly variable` (session test); none of the login shells measured did that. On
opensuse an interactive non-login bash read the file too: with `TMOUT=2` in its environment it
kept running after the exercise (exited after 2 s before).

### Per-family notes
| os_family | `/bin/sh` | Shell for `useradd` | Login umask before → after | `TMOUT` in `/bin/sh` | Ansible's umask after (with `become`) |
|---|---|---|---|---|---|
| Debian | dash | `/bin/sh` | `0002` → `0027` | no | `0022` |
| RedHat | bash | `/bin/bash` | `0022` → `0027` | yes | `0027` |
| Suse | bash | `/bin/bash` | `0022` → `0027` | yes | `0022` |
| Alpine | BusyBox | `/bin/ash` | `0022` → `0027` (not via `su -` with bash) | yes | `0022` |
| Archlinux | bash | `/usr/bin/bash` | `0022` → `0027` | yes | `0022` |

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `user toor is currently used by process 1`, rc 8 | root's processes have UID 0 too | `force: true`, never with `remove: true` |
| The check rejects `umask 0027` | the regex accepts `027` or `27` only | write `umask 027` |
| `TMOUT` is set, the shell never times out | dash (`/bin/sh` on Debian/Ubuntu) ignores it | give users bash, or rely on sshd's `ClientAlive*` |
| `TMOUT: readonly variable` at login | the file is sourced twice | source it once, or guard it |
| A user unsets `TMOUT` in a sub-shell | `readonly` is not inherited | expected; it is a deterrent, not a control |
| Files made by Ansible are `0640` on Red Hat hosts | `/etc/bashrc` applies `profile.d` to non-login shells | set `mode:` on every file task |

### Real-world notes
- Run discovery as a separate audit play first (4.01) and review the findings before a play
  deletes accounts on many servers.
- An idle shell timeout does not close an idle SSH connection: keep sshd's `ClientAlive*` (2.02).
- Users of zsh or fish need their own files; `/etc/profile.d/*.sh` is read by sh-compatible login
  shells.

### Further reading
- Lesson [L08 - Accounts and PAM](../../../docs/lessons/L08-accounts-and-pam.md): password field, UID 0, NSS, login shells, `readonly`.
- Exercise [2.02 - SSH server hardening with a Jinja2 template](../../stage2-building-blocks/2.02-sshd-template/README.md)
- Exercise [4.01 - Audit-only compliance report](../../stage4-advanced/4.01-audit-only-report/README.md)
- [`shadow(5)`](https://man.archlinux.org/man/shadow.5), [`useradd(8)`](https://man.archlinux.org/man/useradd.8)

## Reference solution

Show it with `lab solution 3.05`, apply it with `lab solve 3.05`.
