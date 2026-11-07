# 2.01 - /etc/shadow: correct permissions per OS family: Explanation

### What the check verifies
`lab check 2.01` runs `check.yml` on `targets`: it runs `stat` on `/etc/shadow` and
`/etc/gshadow` and, for each file that exists, asserts owner `root`, group `root` or `shadow`, no
execute bit for anyone, no group write and no access at all for others. Then it runs your
playbook once more with `--check` and expects `changed=0`.

- It tests a **bound**, not the family convention: `root:root 0600` or `0000` on every host
  passes, also on the hosts where a helper needs the group `shadow` (see *Who needs the group*).
- It does not look at the backups `/etc/shadow-` and `/etc/gshadow-`. On four hosts they start
  world-readable (table below), so a passed check can leave readable hash copies behind.
- Missing files are skipped, and setuid, setgid and sticky bits are not tested.
- It does not test how you got there (dictionary, `stat`, loop), only the resulting state.

### How it works

#### Data instead of conditions
Five tasks with `when: ansible_facts.os_family == '...'` would work, but every new distribution
touches every task. A dictionary keyed by the fact keeps *what differs* (group, mode) apart from
*what to do* (one `file` task): `shadow_perms[ansible_facts.os_family].mode`. The keys must be the
fact values `Debian`, `RedHat`, `Suse`, `Alpine` and `Archlinux`. A missing key stops the task
with `object of type 'dict' has no attribute 'RedHat'` (measured). For a security value that is
the right reaction: a new family is noticed instead of receiving a guess. `| default({...})`
would hide the gap; lesson L04 explains why that is wrong here.

#### What a looped `register` holds
A `stat` task with `loop` registers one entry per item in `shadow_files.results`. Each entry has
the input under `item` and the module result under `stat`, so the follow-up loop uses `item.item`
for the path and `item.stat.exists` for the decision. `when: item.stat.exists` lists the missing
files as `skipping`; `shadow_files.results | selectattr('stat.exists') | list` removes them from
the loop. Without `loop_control.label` Ansible prints the whole item - for a registered result
that is everything `stat` returned, including the SHA1 checksum of the file (measured).
`get_checksum: false` on the `stat` task skips the hash and keeps it out of logs.

#### Why `0000` works
Root bypasses the read and write bits of a regular file (`CAP_DAC_OVERRIDE`), so `0000` costs root
nothing and denies everybody else. The owner stays `root`, so only root can change the mode.

#### Who needs the group
Programs that check a password without running as root (for example a screen locker in your
session) call the PAM helper `unix_chkpwd`. Whether that helper reads the file through the group
depends on how the distribution installs it (measured):

- Debian, Ubuntu, Alpine: setgid `shadow` (`rwxr-sr-x root:shadow`). It needs group read, so
  `root:root` breaks those password checks there, although the lab check passes.
- openSUSE: setuid root, group `shadow` (`rwsr-xr-x`). The group is convention, not a requirement.
- Rocky, Alma, Fedora, Arch: setuid root, and no group `shadow` exists. `group: shadow` fails there
  with `chgrp failed: failed to look up group shadow`.

On the six hosts that have `getcap`, the helper has no file capabilities.

### Per-family notes
Measured on fresh targets: `/etc/shadow` starts as `0644` everywhere (planted by the lab) with the
family's own group. The reference solution reports `changed=1` per host (one looped task) and
`changed=0` in the second run.

| os_family | Group `shadow` | `unix_chkpwd` | Backups at the start (`shadow-` / `gshadow-`) | After the solution |
|---|---|---|---|---|
| Debian | yes (gid 42) | setgid `shadow` | debian `644` / `640`, ubuntu `644` / `644` | all four `0640 root:shadow` |
| RedHat | no | setuid root | rocky `644` / `0`, alma `0` / `0`, fedora `644` / `644` | all four `0000 root:root` |
| Suse | yes (gid 15) | setuid root, group `shadow` | `640` / no gshadow files | `shadow`, `shadow-` `0640 root:shadow` |
| Alpine | yes (gid 42) | setgid `shadow` | `640` / no gshadow files | `shadow`, `shadow-` `0640 root:shadow` |
| Archlinux | no | setuid and setgid, `root:root` | `600` / `600` | all four `0600 root:root` |

The world-readable backups are on exactly the four hosts where the lab's build adds an account
*after* planting `0644` (debian and rocky: `toor`; ubuntu and fedora: `guest`): the account tools
copy the file, mode included, before they change it. `/etc/gshadow` does not exist on opensuse
and alpine, which is why the task needs `stat` first: `file` on a missing path fails with
`file (/etc/gshadow) is absent, cannot continue`.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `object of type 'dict' has no attribute 'Arch'` | key spelled differently from the fact | keys `Debian`, `RedHat`, `Suse`, `Alpine`, `Archlinux` |
| `chgrp failed: failed to look up group shadow` | the group does not exist on RedHat and Arch hosts | take the group from the dictionary |
| `file (/etc/gshadow) is absent, cannot continue` | `file` without `stat` on opensuse or alpine | loop over the `stat` results, act only where `stat.exists` |
| `has no attribute 'stat'`, or a path that looks like a dictionary | `item` in the second loop is a result, not a path | path `item.item`, data `item.stat` |
| `lab check` passes, `shadow-` is still `0644` | the check ignores the backups | add them to the list (bonus 1) |
| The output shows a checksum of `/etc/shadow` | `stat` computes SHA1 by default, no label | `get_checksum: false`, `loop_control.label` |

### Real-world notes
- CIS has separate recommendations for `/etc/shadow-` and `/etc/gshadow-`. Fix the main file
  first: the next `useradd` or `passwd` copies its mode into the backup again.
- Keep the convention of the distribution. A uniform `0000` passes most scanners and breaks the
  setgid helper on the Debian and Alpine families.
- In a role, the dictionary becomes a variable file per family (exercise 4.03, lesson L11).

### Further reading
- Lesson [L03 - Base hardening](../../../docs/lessons/L03-base-hardening.md): modes as a bound, why root ignores the bits.
- Lesson [L04 - Platform differences as data](../../../docs/lessons/L04-platform-differences-as-data.md): dictionaries keyed by a fact, registered loop results.
- Exercise [1.02 - Permissions on /etc/passwd and /etc/group](../../stage1-beginner/1.02-passwd-group-permissions/README.md)
- Exercise [4.03 - Data-driven role for all platforms (incl. Alpine)](../../stage4-advanced/4.03-data-driven-multi-platform-role/README.md)

## Reference solution

Show it with `lab solution 2.01`, apply it with `lab solve 2.01`.
