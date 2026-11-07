# 3.03 - Password quality with pam_pwquality: Explanation

### What the check verifies
`lab check 3.03` runs `check.yml` on the Debian and Red Hat families (five hosts) and then your
playbook once more with `--check`, expecting `changed=0` (`meta.yml` says `idempotency: true`).
`check.yml` reads `/etc/security/pwquality.conf.d/50-cis.conf` and the PAM file of the family
(`common-password` or `system-auth`) and asserts:
- the last `minlen` is at least 14, the last `minclass` at least 4, the last `maxrepeat` and
  `maxsequence` between 1 and 3;
- a line `dictcheck = 1` and a line that is only `enforce_for_root`;
- the text `pam_pwquality` somewhere in the PAM file.

It does not test: owner and mode of the drop-in, the package, other drop-ins that set lower
values, whether the `pam_pwquality` match is an active line or a comment, and the role file
`section5_pam.yml` with its tag. On the Red Hat family the PAM assertion proves nothing about
your play: `system-auth` and `password-auth` already contain `pam_pwquality` on fresh rocky,
alma and fedora hosts. There only the drop-in values test your work.

### How it works

#### Drop-ins
`pwquality.conf` belongs to the package. `pwquality.conf.d/50-cis.conf` is yours - package updates
never conflict with it, and removing the control means removing one file. libpwquality reads the
drop-ins in name order, a later file wins (`pwquality.conf(5)`). The directory is not always
there: the Red Hat hosts have it at the start, Debian and Ubuntu have no pwquality at all, and
installing `libpam-pwquality` did not create it (measured on Ubuntu 24.04). Create it in the play.

#### PAM ownership
Hand-editing `/etc/pam.d/*` is the most common way to break logins *and* the most common reason
hardening is silently reverted:
- **Debian/Ubuntu**: `pam-auth-update` regenerates `common-*` from profiles in
  `/usr/share/pam-configs`. A manual edit is overwritten on the next package that calls it.
- **RHEL/Fedora**: `system-auth` and `password-auth` are symbolic links into `/etc/authselect/`
  (measured on all three hosts; the profile is `local` with no features). `authselect select
  ... --force` or `authselect apply-changes` overwrites manual edits.
Work *with* the tool: enable profiles and features, never patch generated files.

#### The package already wires PAM on Debian
Installing `libpam-pwquality` runs `pam-auth-update` itself (measured on Ubuntu 24.04): it adds
`password requisite pam_pwquality.so retry=3` before `pam_unix` and gives the `pam_unix` line
`use_authtok try_first_pass`. A second `pam-auth-update --enable pwquality` leaves the file
unchanged. So the solution's conditional `pam-auth-update` normally never runs - it is the safety
net for a host where someone disabled the profile. `lab solve 3.03` on fresh hosts reported
`changed=3` on debian and ubuntu (package, directory, drop-in) and `changed=1` on the Red Hat
hosts (only the drop-in).

#### `enforce_for_root` and the root tools
pwquality judges a password whenever a program changes it through the PAM *password* stack. Which
programs do that differs per family (measured as root, with a test user and the password `abc`):
- **Debian, Ubuntu**: `/etc/pam.d/chpasswd` includes `common-password`. Without
  `enforce_for_root`, `passwd` and `chpasswd` print `BAD PASSWORD: The password is shorter than 14
  characters` and set the password anyway (rc 0). With it, they refuse: `chpasswd` exits with 1
  and `password not changed`.
- **Red Hat (rocky, alma, fedora)**: there is no `/etc/pam.d/chpasswd`. `chpasswd` set `abc`
  without a word, `enforce_for_root` included.
- **Any family**: a ready-made hash bypasses the check - `chpasswd -e` and `usermod -p` set it
  (rc 0).
Quality rules protect interactive changes. Bulk tools and provisioning with hashes are outside
their reach - which is fine, if you know it.

#### Containers
The lab images run real PAM stacks, so the configuration is identical to a VM. What you cannot
test here is a console login.

### Per-family notes
| `os_family` | Hosts | At the start | Root `chpasswd` with `abc` after the solution |
|---|---|---|---|
| Debian | debian, ubuntu | no pwquality module, no `pwquality.conf.d`; `common-password` without `pam_pwquality` | refused (rc 1) |
| RedHat | rocky, alma, fedora | `pam_pwquality` in `system-auth` and `password-auth`, `pwquality.conf.d` present; authselect profile `local` | accepted (rc 0), no `/etc/pam.d/chpasswd` |

Outside the scope (bonus 1 and 2): opensuse, arch and alpine have no `pam_pwquality` at the start.
`chpasswd` uses PAM on arch (`system-auth`) and alpine (`base-password`); opensuse has no
`/etc/pam.d/chpasswd`.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `No package matching 'libpam-pwquality' is available` | the image ships an empty index and `cache_valid_time` judges its directory fresh | `update_cache: true` without `cache_valid_time`, or look for `*_Packages*` first like the solution |
| Debian/Ubuntu: `Destination directory /etc/security/pwquality.conf.d does not exist` | the package does not create it | a `file` task with `state: directory` first |
| The check is green on Red Hat before you start | `pam_pwquality` is already in `system-auth` | judge your work by the drop-in |
| A weak root password is accepted with a warning | `enforce_for_root` missing | add the bare `enforce_for_root` line |
| Your values are ignored | a drop-in later in name order sets other ones | one drop-in per setting, a clear prefix |

### Real-world notes
- Accounts created by automation usually get a hash, not a password - quality rules never see
  it. Generate those passwords with enough length, or use keys only.
- Central identity systems have their own password policy; pwquality protects local accounts.

### Further reading
- Lesson [L08 - Accounts and PAM: who may log in, how, and with what password](../../../docs/lessons/L08-accounts-and-pam.md): PAM stacks, the tools that own them, pwquality and faillock - the concepts before this exercise.
- Exercise [3.02 - Password aging and inactive accounts](../3.02-password-aging/README.md): the other half of the password policy.
- Exercise [4.06 - Account lockout with pam_faillock (authselect)](../../stage4-advanced/4.06-faillock-authselect/README.md): the next PAM module, managed the same way.

## Reference solution

Show it with `lab solution 3.03`, apply it with `lab solve 3.03`.
