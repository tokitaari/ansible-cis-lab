# 1.03 - SSH: forbid root login and empty passwords: Explanation

### What the check verifies
`lab check 1.03` runs `check.yml` on `targets`. It reads the effective configuration
(`sshd -T`, keywords compared in lower case) and asserts `permitrootlogin == 'no'` and
`permitemptypasswords == 'no'`. It also stats `/etc/ssh/sshd_config.d/00-cis-hardening.conf`:
the file must exist, with mode `0600` and owner `root`. Then it runs your playbook again with
`--check` and expects `changed=0`.

Not tested:

- The file group (requirement says `root:root`, the check looks at the owner only).
- `validate` and the handler: a solution without them passes.
- That the legacy file is untouched. Deleting `10-lab-legacy.conf` would pass too.

### How it works

#### First match wins
For most keywords sshd uses the **first** value it reads. `Include /etc/ssh/sshd_config.d/*.conf`
sits at line 2 (arch) to 24 (ubuntu) of the main file, and the files are read in lexical order, so
`00-cis-hardening.conf` is read before `10-lab-legacy.conf`. Measured before the solution, all
eight hosts report `permitrootlogin yes` and `permitemptypasswords yes`, defined in the legacy
file (lines 2 and 3). On alma `25-permitrootlogin.conf` (`PermitRootLogin yes`) comes in
between; where that file comes from was not investigated. A `99-` name loses against both. Red
Hat hosts also ship `40-redhat-crypto-policies.conf` and `50-redhat.conf`, arch ships
`20-systemd-userdb.conf` and `99-archlinux.conf`.

#### `validate`
Ansible writes the content to a temporary file, runs `sshd -t -f <tempfile>` and moves it into
place only if the exit code is 0. Measured with a typo (`PermitRootLogn`) on debian and alpine:
the task fails with `failed to validate`, exit status 255, stderr
`Bad configuration option: PermitRootLogn`, and the existing file keeps its content. The
fragment is checked on its own as the main configuration, not together with the other drop-ins.

#### Handlers
Handlers run once at the end of the play and only if notified. The first run shows
`changed` for the copy and for `Reload sshd`; the second run shows neither.

#### `reloaded` or `restarted`
Measured on all eight hosts: an open SSH session survived both a reload and a restart. On the
seven systemd hosts the unit has `KillMode=process`, so the restart does not kill existing
session processes (on arch the unit type is `notify-reload`, elsewhere `notify`). On alpine
(OpenRC) the session survived as well. Reload is still the gentler habit.

#### Why not `lineinfile` on `sshd_config`?
It works, but distributions ship different main files and updates may replace them. A drop-in you
own is easier to reason about and to remove.

#### Reading `sshd -T`
Keywords are case-insensitive and their spelling differs: debian, ubuntu, Red Hat, SUSE and alpine
print `permitrootlogin no`, arch (OpenSSH 10.6) prints `PermitRootLogin no`. Compare in lower
case.

### Per-family notes
| Host | OpenSSH | Service | Drop-ins besides the legacy file |
|---|---|---|---|
| debian | 10.0p2 | `ssh` | none |
| ubuntu | 10.2p1 | `ssh` | none |
| rocky | 9.9p1 | `sshd` | `40-redhat-crypto-policies`, `50-redhat` |
| alma | 9.9p1 | `sshd` | `25-permitrootlogin`, `40-...`, `50-redhat` |
| fedora | 10.2p1 | `sshd` | `40-redhat-crypto-policies`, `50-redhat` |
| opensuse | 10.0p2 | `sshd` | none; also includes `/usr/etc/ssh/sshd_config.d/*.conf` |
| arch | 10.6p1 | `sshd` | `20-systemd-userdb`, `99-archlinux` |
| alpine | 10.3p1 | `sshd` (OpenRC) | none |

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `sshd -T` still says `yes` | your file sorts after the legacy file | use a low prefix such as `00-` |
| `failed to validate` | typo in the fragment | read stderr; the old file is untouched |
| Handler does not run | name differs from `notify` | the name must match exactly |
| Guests with empty passwords could log in | `PermitEmptyPasswords yes` | the solution closes it: `Permission denied` on ubuntu and fedora afterwards |

### Real-world notes
Before touching sshd in production keep a second session open, use `validate`, and roll out in
batches (`serial`, stage 5).

### Further reading
- Lesson [L02 - Safe changes](../../../docs/lessons/L02-safe-changes.md): `validate`, handlers and `--check --diff`.
- Lesson [L03 - Base hardening](../../../docs/lessons/L03-base-hardening.md): packages, services, files, SSH and sudo in one place.
- Exercise [2.02 - SSH server hardening with a Jinja2 template](../../stage2-building-blocks/2.02-sshd-template/README.md)

## Reference solution

Show it with `lab solution 1.03`, apply it with `lab solve 1.03`.
