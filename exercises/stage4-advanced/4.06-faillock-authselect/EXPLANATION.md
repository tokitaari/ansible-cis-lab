# 4.06 - Account lockout with pam_faillock (authselect): Explanation

### Wrapping a CLI idempotently
`authselect enable-feature` has no "already enabled → no change" output you can rely on,
so: read state (`authselect current`), decide (`when`), report honestly
(`changed_when: true`). Same pattern as `useradd -D` in 3.02.

### Key logins and faillock
sshd with public-key authentication does **not** run the PAM *auth* phase - the key is
checked by sshd itself. It runs PAM *account* and *session*. `pam_faillock` in the
account phase only denies if the account is already locked. Failed *password* attempts
via SSH, console, `su` or `sudo` count. So your automation is safe - unless someone
locks the `ansible` account with failed `su` attempts... which is why some sites
exclude service accounts.

### Why not edit PAM
`authselect apply-changes` or a profile switch regenerates `system-auth` and
`password-auth`. A manual `pam_faillock` line would vanish silently - the worst kind of
hardening regression.

### Commented defaults
`faillock.conf` ships with `# deny = 3`. The regexp `^\s*#?\s*deny\s*=` matches the
comment and replaces it in place - your setting appears where documentation expects it.

## Reference solution

Show it with `lab solution 4.06`, apply it with `lab solve 4.06`.
