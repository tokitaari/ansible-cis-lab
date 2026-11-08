# 4.03 - Data-driven role for all platforms (incl. Alpine): Explanation

### What the check verifies
`lab check 4.03` runs `check.sh`, then your playbook once more with `--check` and expects
`changed=0` (`idempotency: true` in `meta.yml`). `check.sh` asserts:
- `4.03/site.yml` exists, and the role has `section5_password_policy.yml`, `section5_pam.yml`,
  `section5_accounts.yml` and `section6_logging.yml`;
- no line under `tasks/` matches a fact comparison: a `grep` for `os_family` or `distribution`
  followed by `==`, `!=` or ` in `, ignoring comments, lines with `first_found` and lines that
  end in `.yml`; and `tasks/main.yml` contains the word `distribution_major_version`;
- `ansible-lint --offline --profile moderate` passes on the role;
- the state checks of 15 earlier exercises pass (0.04, 1.01-1.05, 2.01-2.06, 3.02, 3.03, 3.05),
  16 with `-e cis_level=2` (3.04 added). Without it the check prints a note that 3.04 was not
  checked; variables given as `-e @file` are not inspected.

Its limits (the `grep` was tried on sample lines): it misses a filter before the comparison
(`os_family | lower == 'debian'`), a comparison without `==`, `!=` or ` in `
(`distribution_major_version | int >= 10`, `is match(...)`) and a condition split over two
lines. A comment that mentions `distribution_major_version` satisfies the loader test. The check cannot tell whether the lookup
list is in the right order or the files hold the right flags; the earlier checks show that only
indirectly, and only on the lab's eight hosts.

### How it works

#### Data beats branches
Compare:
```yaml
# branchy
- when: ansible_facts.os_family in ['Debian', 'RedHat']
# data-driven
- when: cis_pwquality_supported
```
The second version says *why* the task runs. Supporting a new platform becomes a vars file and
a review of the flags - no edits in task logic, no risk for existing platforms. In the reference
solution the tasks ask four platform flags: `cis_pwquality_supported`, `cis_pam_tool`,
`cis_cron_allow_supported` and `cis_apt_cache_refresh`. Names, paths and modes
(`cis_sshd_service`, `cis_pam_password_stack`, `cis_shadow_mode`) are data too, but they need no
`when`.

#### The variable hierarchy
The loader tries `<distribution>-<major>.yml`, `<distribution>.yml`, `<os_family>.yml` and
`default.yml` and loads the first file that exists: **one** file. What the lab's targets make
of that is in the table below. Three consequences:
- Ubuntu belongs to the Debian family and the solution has no `Ubuntu.yml`, so `Debian.yml`
  serves both. Arch is rolling: its "major version" is the image date, so
  `Archlinux-20261101.yml` would never match again. openSUSE reports `openSUSE Leap` with a
  space; a file of that name would work in `first_found`, the lab uses `Suse.yml`.
- A value loaded with `include_vars` beats `group_vars` and play variables; only `-e` wins
  (measured in L11). Flags in `vars/` are facts of the platform; anything an operator should
  set per host belongs in `defaults/`.
- Because the file is the only one, it has to be complete. Measured with the solution role
  and a `vars/Ubuntu.yml` that sets only `cis_cron_allow_supported: false`, on an Ubuntu host:
  the first task stops with `'cis_apt_cache_refresh' is undefined`; with that flag set on the
  command line, `cis_audit_package`, `cis_pam_tool` and `cis_sshd_service` are undefined.
  Layering fixes it: load `default.yml`, then the family file, then the distribution files that
  exist, general first. With that loader the same host got `cis_cron_allow_supported` from
  `Ubuntu.yml` and everything else from `Debian.yml`; without `Ubuntu.yml` all values came
  from `Debian.yml`.

#### Alpine as a first-class citizen
Alpine forces the honest questions. Measured in L08: `/etc/pam.d` exists and the `faillock`
module is shipped, but no `pam_unix` password line is found there and pwquality is not
installed, so "no PAM" would be too strong; the role says `cis_pam_tool: none` and
`cis_pwquality_supported: false`. BusyBox crontab ignores `cron.allow` (L06), hence
`cis_cron_allow_supported: false` and a restricted cron spool instead. There is no Python until
it is bootstrapped, which is why `site.yml` starts with a play for `alpine_family` that installs it
with `raw`. Each question becomes a flag with a comment explaining the compensating control or the
documented gap.

#### Regression testing
You just changed a role that hardens eight platforms. The earlier checks are your safety net: 15
of them (16 at level 2) must pass after **one** run on freshly reset hosts, and the second run
in `--check` must change nothing. `lab check 4.03` does both. A level 2 run needs
`-e cis_level=2` for the playbook and for `lab check`.

### Per-family notes

| os_family | Hosts | `distribution` / major | File loaded | `cis_pam_tool` | `cis_pwquality_supported` | `cis_cron_allow_supported` |
|---|---|---|---|---|---|---|
| Debian | debian, ubuntu | Debian 13, Ubuntu 26 | `Debian.yml` for both | `pam-auth-update` | true | true |
| RedHat | rocky, alma, fedora | Rocky 10, AlmaLinux 10, Fedora 44 | `RedHat.yml` | `authselect` | true | true |
| Suse | opensuse | `openSUSE Leap` 16 | `Suse.yml` | `manual` | false | true |
| Archlinux | arch | Archlinux 20261101 | `Archlinux.yml` | `manual` | false | true |
| Alpine | alpine | Alpine 3 | `Alpine.yml` | `none` | false | false |

| os_family | sshd / cron service | Shadow group, mode | Audit package | apt index refresh |
|---|---|---|---|---|
| Debian | `ssh` / `cron` | `shadow`, `0640` | `auditd` | true |
| RedHat | `sshd` / `crond` | `root`, `0000` | `audit` | false |
| Suse | `sshd` / `cron` | `shadow`, `0640` | `audit` | false |
| Archlinux | `sshd` / `cronie` | `root`, `0600` | `audit` | false |
| Alpine | `sshd` / `crond` | `shadow`, `0640` | `audit` | false |

Distribution, major version and loaded file were measured with the solution's loader on all eight
targets (they change when an image is rebuilt); the flags and values are read from the
solution's `vars/` files. Suse and Arch carry `manual` and a false pwquality flag as documented
gaps: the role installs and configures no pwquality there (for Suse, the comment in `Suse.yml`
leaves the pam-config work to the 3.03 bonus).

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `'cis_apt_cache_refresh' is undefined` (or another flag) | a partial `Ubuntu.yml` in the one-file loader | complete the file, or layer the loads, general first |
| `Conditional result (True) was derived from value of type 'str' at "<CLI option '-e'>"` | `-e cis_apt_cache_refresh=false` is the string `"false"` | `-e '{"cis_apt_cache_refresh": false}'` |
| `can only concatenate list (not "CapturedExceptionMarker") to list` | a layered loader whose optional-file lookup got no `skip` (passed beside the dict it had no effect in the test) | put `'skip': true` inside the parameter dict |
| a version file for arch is never used twice | rolling release, the "major version" is the image date | use the distribution or family file |
| the check is green although a task compares `os_family \| lower == ...` | the `grep` stops at a pipe | use a flag; the check only supports your review |
| `interpreter /usr/bin/python3 not found` on alpine | no Python before the bootstrap | the pre-play of `site.yml`, or `lab solve 0.02 -y` |
| `--check -e cis_level=2` on a fresh host fails in 6.3: `Destination /etc/audit/auditd.conf does not exist` (7 of 8, not arch) | `lineinfile` edits a file that only the package install creates, and a dry run installs nothing | apply once, then `--check`; the 5.01 role guards this case |

### Real-world notes
- Where a capability can be probed on the host (a command exists or not), probing beats a
  table of versions. Keep flags for what cannot be probed: policy decisions such as which PAM
  tool the role manages.
- `default.yml` decides what an unknown platform gets. Fall back to values that enable nothing
  the role cannot be sure of, and let the report (5.01) show the skipped controls as not
  applicable: a silent skip is a hole, a default that enables everything breaks the first host
  nobody tested.

### Further reading
- Lesson [L11 - Profiles, exceptions and data-driven roles](../../../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.md): flags, one file or layers, testing from the outside.
- Lesson [L04 - Platform differences as data](../../../docs/lessons/L04-platform-differences-as-data.md): dictionaries, loops and templates behind the vars files.

## Reference solution

Show it with `lab solution 4.03`, apply it with `lab solve 4.03`.
