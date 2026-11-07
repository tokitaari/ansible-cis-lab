# 1.04 - Stop and disable the FTP server: Explanation

### What the check verifies
`lab check 1.04` runs `check.yml` on `targets`: it collects `service_facts`, picks the `vsftpd`
entry (`vsftpd.service` on systemd, `vsftpd` on OpenRC) and asserts that the state is not
`running`/`started` and that the service is not enabled. Systemd and SysV hosts report
`status: enabled`; OpenRC (Alpine) reports the runlevels, and `default` means enabled. Then it
runs your playbook once more with `--check` and expects `changed=0`.

The check looks at the result only:

- A host without a `vsftpd` entry passes ("not present"). Removing the package therefore passes,
  and so does a masked unit.
- It does not test requirement 3: a solution without `package_facts` and `when` passes on
  all eight lab hosts, because all of them have `vsftpd`.

### How it works

#### One module, two init systems
`service` reads the fact `service_mgr`. On systemd it hands over to the `systemd` module, on
everything else to the legacy service module, which also drives OpenRC (`rc-service`,
`rc-update`). Measured: the same task runs on all eight hosts; the second run is `changed=0`
everywhere. For systemd-only features (`masked`, `daemon_reload`) use
`ansible.builtin.systemd_service`.

#### `package_facts` and `when`, not `ignore_errors`
`package_facts` fills `ansible_facts.packages`, a dict keyed by package name. The condition
`'vsftpd' in ansible_facts.packages` skips the task on hosts without the package. `ignore_errors`
would hide every error, including a typo in the service name.

A missing service does not fail everywhere. Measured after removing `vsftpd` with the
`service` task still running on the old facts: it failed on rocky, alma, fedora, opensuse and
arch with `Could not find the requested service vsftpd: host`, but reported `ok` on debian and
ubuntu. On alpine the `service` module reported `SUCCESS` for a name that does not exist. Why
Debian and Ubuntu differ was not investigated. A condition that works on all families is the
safe choice.

#### Disable, mask, remove
Measured on the seven systemd hosts:

- `enabled: false` gives `is-enabled=disabled`, `is-active=inactive`. `systemctl start vsftpd`
  still works (rc=0) and the service is `active` afterwards.
- `systemctl mask` links the unit to `/dev/null` (`/etc/systemd/system/vsftpd.service`);
  `is-enabled=masked`, and a start fails with `Unit vsftpd.service is masked.` (rc=1).
  `service_facts` then reports `status: masked`.
- Removing the package removes the binary. CIS prefers this; stop/mask is the fallback when
  another package needs it.

#### Order (bonus)
Facts are a snapshot. If you remove the package first and then stop the service with the old
`package_facts` result, the `when` is still true. Measured: 5 of 7 systemd hosts fail as shown
above. With a second `package_facts` call after the removal the task is skipped
(`lab check` then shows `skipped=1` on rocky and ubuntu). On alpine the same order experiment
ended with `ok` for the stop task.

### Per-family notes
| Host | Init | State at lab start |
|---|---|---|
| debian, ubuntu | systemd | `vsftpd` enabled and active |
| rocky, alma, fedora, opensuse, arch | systemd | `vsftpd.service` enabled and active |
| alpine | OpenRC | `status: started`, runlevel `default` |

In `service_facts` on alpine the entry after the solution is `name: vsftpd`, `source: openrc`,
`state: stopped`, `runlevels: null`.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `Could not find the requested service vsftpd: host` | package removed, old facts | refresh with `package_facts`, or fix the order |
| Service starts again by hand | `enabled: false` is not `masked` | `masked: true` with `systemd_service` (systemd only) |
| Alpine fails with no Python | `0.02` not applied | run exercise 0.02 first |

### Real-world notes
- The lab has `vsftpd` everywhere, so the skip branch never runs on a fresh lab. It matters on a
  mixed fleet.
- The check accepts a removed package, a masked unit and a stopped service alike; pick the one your policy asks for.

### Further reading
- Lesson [L02 - Safe changes](../../../docs/lessons/L02-safe-changes.md): conditionals and `--check`.
- Lesson [L03 - Base hardening](../../../docs/lessons/L03-base-hardening.md): packages, services, files, SSH and sudo in one place.
- Exercise [1.01 - Remove insecure client packages](../1.01-remove-telnet/README.md): `package` and `package_facts`.

## Reference solution

Show it with `lab solution 1.04`, apply it with `lab solve 1.04`.
