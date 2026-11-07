# 1.05 - sudo: use a PTY and log to a file: Explanation

### What the check verifies
`lab check 1.05` runs `check.yml` on `targets`: `/etc/sudoers.d/50-cis` must exist with mode
`0440` and owner `root`, and its content must contain the lines `Defaults use_pty` and
`Defaults logfile="/var/log/sudo.log"` (quotes optional). `visudo -c` must succeed. On openSUSE
the check tolerates exactly one complaint, `/usr/etc/sudoers: bad permissions`, because the
vendor file is not yours (see below). Then it runs your playbook again with `--check` and expects
`changed=0`.

Not tested:

- `validate`: a solution without it passes.
- The file group, and any mode stricter or looser than exactly `0440`.
- That sudo really uses a PTY or writes the log; the check reads the file.

### How it works

#### Why drop-in files
`/etc/sudoers` belongs to the distribution package. `/etc/sudoers.d/` is read through
`@includedir`, so your file can be added and removed cleanly. Measured: a file whose name contains
a dot (`99-dot.conf`) is **ignored**. `visudo -c` does not list it and a `logfile` set in it has
no effect on all tested hosts. `50-cis.conf` would silently do nothing.

#### `validate` saves you
Without validation a typo disables sudo, and Ansible needs sudo to become root. Measured with a
typo in the content: the `copy` task fails with `failed to validate` on all seven hosts that ran
it (alpine failed the same way in a separate run), and all seven hosts are
still reachable with `become`. Recovery without validation would need console access, here
`./lab.sh reset <host>`.

#### The file mode matters
Measured: with mode `0644` `visudo -c` exits 1 with `/etc/sudoers.d/50-cis: bad permissions,
should be mode 0440`. `sudo -n true` still worked (rc=0) in that state. This is why the check
reads the mode and `visudo -c`. After restoring `0440` the file was fine again.

#### No handler
sudo reads its configuration on every call, so no handler is needed.

### Per-family notes
- sudo versions: 1.9.16p2 on debian, 1.9.17p1 on opensuse, 1.9.17p2 on the others.
- Ubuntu 26.04 offers a Rust reimplementation (sudo-rs). On the lab image `sudo` is the
  original sudo: `/usr/bin/sudo` is an alternatives link to `/usr/bin/sudo.ws`, `visudo` is
  `/usr/sbin/visudo.ws`, version 1.9.17p2.
- openSUSE Leap 16 moves vendor defaults to `/usr/etc` (`/usr/etc/sudoers`, `/usr/etc/login.defs`);
  files in `/etc` override them. The package ships `/usr/etc/sudoers` with mode 0444, so
  `visudo -c` exits 1 on an untouched host. That file is not yours.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `failed to validate` | typo in the content | fix the content and run again |
| Setting has no effect | file name contains `.` or ends in `~` | `50-cis`, no extension |
| `visudo -c`: `bad permissions` | mode `0644` | `0440` |
| Log shows Ansible's own commands | Ansible runs its modules through sudo | expected; e.g. `COMMAND=/usr/bin/true` |

### Real-world notes
- `logfile` is in addition to syslog/journal, not instead.
- `use_pty` has been the sudo default since 1.9.14 (from the sudo release notes, not measured
  here); setting it explicitly documents the intent and covers older versions.
- The log contains lines like `ansible : PWD=/home/ansible ; USER=root ; COMMAND=/bin/sh`, ;
  long entries wrap at 80 characters, so a command can continue on the next line.

### Further reading
- Lesson [L02 - Safe changes](../../../docs/lessons/L02-safe-changes.md): `validate` and `--check --diff`.
- Lesson [L03 - Base hardening](../../../docs/lessons/L03-base-hardening.md): packages, services, files, SSH and sudo in one place.
- Exercise [1.03 - SSH: forbid root login and empty passwords](../1.03-ssh-root-login/README.md): the same `copy` + `validate` pattern.

## Reference solution

Show it with `lab solution 1.05`, apply it with `lab solve 1.05`.
