# 4.06 - Account lockout with pam_faillock (authselect): Explanation

### What the check verifies
`lab check 4.06` runs `check.yml` on the Red Hat family (rocky, alma, fedora) and then your
playbook once more with `--check`, expecting `changed=0` (`meta.yml` says `idempotency: true`).
`check.yml` reads three files and asserts:
- in `/etc/security/faillock.conf` the last active `deny` is between 1 and 5 and the last active
  `unlock_time` is 0 or at least 900 (a missing line fails);
- `pam_faillock` appears in `/etc/pam.d/system-auth` and in `/etc/pam.d/password-auth`.

It does not test: that `authselect` made the change (a hand edit passes - until the next
`authselect` run removes it), the feature in `authselect current`, the `account` line,
`even_deny_root` and `fail_interval`, and that a lockout really happens. `deny = 3` passes as
well; the README asks for 5.

### How it works

#### Wrapping a CLI idempotently
Fresh targets start with the authselect profile `local` and no features. Measured on all three
hosts: a second `authselect enable-feature with-faillock` returned 0, printed nothing and left
`system-auth`, `password-auth` and `faillock.conf` unchanged. The command itself cannot tell you
whether it changed anything, so the pattern is: read the state (`authselect current`, with
`changed_when: false` and `check_mode: false`), decide (`when`), report honestly
(`changed_when: true`). Same pattern as `useradd -D` in 3.02.

After the feature is on, both files carry three lines (measured):
```text
auth        required      pam_faillock.so preauth silent
auth        required      pam_faillock.so authfail
account     required      pam_faillock.so
```

#### Why not edit PAM
`system-auth` and `password-auth` are symbolic links into `/etc/authselect/` (measured), and
after the solution `authselect check` reported `Current configuration is valid.`.
`authselect apply-changes` or a profile switch regenerates both files: a manual `pam_faillock`
line would vanish silently - the worst kind of hardening regression.

#### Commented defaults
`faillock.conf` ships `# deny = 3`, `# fail_interval = 900`, `# unlock_time = 600` and
`# even_deny_root` on all eight targets. The regexp `^\s*#?\s*deny\s*=` matches the comment and
replaces it in place: after the solution, `deny = 5` is line 32 and `unlock_time = 900` line 45 -
where the documentation expects them.

#### Key logins and faillock
sshd checks a public key itself and does not run the PAM *auth* phase for it; it runs PAM
*account* and *session*. In the account phase `pam_faillock` never denies - in the source of
Linux-PAM it always returns success. So a locked account still logs in with a key. Measured on
rocky, alma and fedora: six failed password attempts through the PAM service `sshd` left five
records and locked `ansible`; an Ansible ping with the SSH key (no multiplexing, no `become`)
then succeeded on all three, and the record count dropped to **0** - the account phase cleared
the lock.

Whether a key login clears the records depends on the PAM build. Upstream Linux-PAM 1.7.2 skips
the clearing when the auth phase did not run (RHEL-32294), and an Ubuntu 24.04 host with a
backported fix kept the records after a key login (measured). The lab's fedora runs
`pam-1.7.2-2` and still cleared them. Check your release with `faillock --user <name>` before and
after a key login.

What it means:
- Your automation is safe: a key-based Ansible account is never locked out by faillock, even
  with failed `su` attempts on its name.
- Faillock limits password guessing. It does not stop anyone who has a valid key - disabling an
  account is a different control.
- On hosts that clear the records, any key login of the account resets an attacker's count.

#### Root
`even_deny_root` is off by default: failed attempts never lock root (`faillock.conf(5)`).
Whether to turn it on is bonus 3: with it, repeated password typos at the console can lock out
the last way in.

### Per-family notes
| `os_family` | Hosts (PAM) | At the start | In this exercise |
|---|---|---|---|
| RedHat | rocky, alma (1.6.1), fedora (1.7.2) | profile `local`, no features, no `pam_faillock` in the stack | feature on, three lines per file; key login cleared the records |
| Debian | debian, ubuntu (1.7.0) | module installed, not in `common-auth`/`common-account` | bonus 1 (`pam-auth-update` profile) |
| Archlinux | arch (1.7.3) | `pam_faillock` already in `system-auth` (four lines) | not in scope |
| Suse, Alpine | opensuse, alpine (1.7.1) | module installed, not in the stack | not in scope |

`faillock.conf` starts with all settings commented out on all eight hosts.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| The check fails with `deny=99` | no active `deny` line - only the shipped comment | the regexp that also matches `#` |
| A locked account still logs in | key logins do not run the auth phase | expected; disable the account if that is the goal |
| The correct password is refused | the account is locked | `faillock --user <name> --reset`, or wait for `unlock_time` |
| `faillock --user <name>` shows nothing, yet a file appeared | looking up an existing user creates an empty record file (L08) | harmless; do not read it as a failure |
| The `pam_faillock` lines are gone after an update | a hand edit of an authselect file | enable the feature with `authselect` |

### Real-world notes
- Service accounts should authenticate with keys only; with password authentication off for
  them, lockouts cannot hit them.
- `fail_interval` (default 900 seconds) is the window in which failures are counted. Decide it
  together with `deny` and `unlock_time`, and tell the help desk how to unlock.

### Further reading
- Lesson [L08 - Accounts and PAM: who may log in, how, and with what password](../../../docs/lessons/L08-accounts-and-pam.md): PAM phases, the tools that own the stack, faillock - the concepts before this exercise.
- Exercise [3.03 - Password quality with pam_pwquality](../../stage3-intermediate/3.03-password-quality/README.md): the same authselect ownership for pwquality.
- Exercise [4.04 - Ansible Vault: break-glass admin account](../4.04-vault-break-glass-account/README.md): the account you keep for the day everything else is locked.

## Reference solution

Show it with `lab solution 4.06`, apply it with `lab solve 4.06`.
