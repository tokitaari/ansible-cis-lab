# 3.02 - Password aging and inactive accounts: Explanation

### What the check verifies
`lab check 3.02` runs `check.yml` on `targets`. It reads `/etc/login.defs` (or
`/usr/etc/login.defs` when the first is missing) followed by every `/usr/etc/login.defs.d/*.defs`
and `/etc/login.defs.d/*.defs`, takes the **last** value of each key, and reads `INACTIVE` from
`useradd -D`. It asserts `PASS_MAX_DAYS` 1-365, `PASS_MIN_DAYS` ≥ 1, `PASS_WARN_AGE` ≥ 7,
`ENCRYPT_METHOD` `SHA512` or `YESCRYPT`, `INACTIVE` 1-45. Then your playbook runs once more with
`--check` and must report `changed=0`.

What it does not verify:

- Whether the host **reads** the drop-ins. Measured: only rocky, alma, fedora and opensuse do;
  debian, ubuntu, arch and alpine ignore `/etc/login.defs.d` (details below). A drop-in-only
  solution passes the check there and changes nothing.
- A downgrade: `YESCRYPT` replaced by `SHA512` passes, both values are accepted.
- Whether the values reach accounts. On arch `PASS_MIN_DAYS` is required, but shadow 4.20 ignores
  it.
- Existing accounts (bonus 1) - only the defaults for new ones.

### How it works

#### `login.defs` is a template for new accounts
`useradd` copies `PASS_*` into the `shadow` entry of an account it creates; `useradd -D` keeps the
inactivity default in `/etc/default/useradd`. Measured with an account created by `useradd`
(fields min:max:warn:inactive of `/etc/shadow`):

- before the exercise: `0:99999:7:` on debian, ubuntu, the Red Hat family and opensuse; `:::` on
  arch and alpine, whose `login.defs` has no `PASS_*` lines - such accounts never age;
- after the reference solution: `1:365:7:45` everywhere except arch, `:365:7:45`.

#### `lineinfile` with an anchored `regexp`
`regexp: '^\s*{{ item.key }}\s'` matches the active line, not a commented one; without a match
the line is appended at the end. Measured in run 1: `PASS_MAX_DAYS` and `PASS_MIN_DAYS` changed on
the seven hosts with `/etc/login.defs`, `PASS_WARN_AGE` only on arch and alpine (appended; the
others already had `7`). Run 2: `changed=0`.

#### Vendor split and drop-ins
opensuse has no `/etc/login.defs`, only `/usr/etc/login.defs`; creating the file in `/etc` would
replace the vendor file, not extend it. The solution writes `/etc/login.defs.d/50-cis.defs`
instead. Whether a drop-in counts depends on how `shadow` was built: the four hosts whose
`useradd` links `libeconf` used a test drop-in (`PASS_WARN_AGE 11` → new account `11`), the four
without it did not (measured). The rule is general: find out how a program reads its
configuration before you write it.

#### `ENCRYPT_METHOD`: read, compare, then write
`slurp` + `regex_findall(...) | last | default('none')` reads the current method; the task writes
`SHA512` only when it is neither `SHA512` nor `YESCRYPT`. Measured: the line changed only on
alpine, whose `login.defs` had none. yescrypt is memory-hard and costs an attacker more than
SHA-512 crypt; overwriting it would weaken the host without any scanner noticing.

`login.defs` is not the only place that picks a hash. The prefix of a hash set with `chpasswd`
did not change with this exercise on any host: `$y$` on debian, ubuntu, the Red Hat family and
arch, `$6$` on opensuse and alpine. On alpine it was `$6$` already before any `ENCRYPT_METHOD`
line existed, so something else chooses there; its `/etc/pam.d/chpasswd` includes
`base-password` (not traced further). L08 shows that a `pam_unix` line can name the hash itself.

#### Commands: read first, then act
`useradd -D` runs with `changed_when: false` and `check_mode: false`, so it also runs under
`--check`; `useradd -D -f 45` runs only when `INACTIVE=45` is missing and reports `changed`
honestly. Measured: changed on all eight in run 1, skipped in run 2. On opensuse it created
`/etc/default/useradd` (none existed, also not in `/usr/etc`).

#### shadow 4.20 and the minimum age
arch runs shadow 4.20.0, which removed the minimum password age: `PASS_MIN_DAYS` is still a
known key (no "unknown item" warning, shadow source), but `useradd` ignores it and clears the
field. The line this exercise writes is therefore required by the check and has no effect on
arch (new account: empty min field). `chage --mindays` does not exist there; 4.04 shows how to
detect that.

### Per-family notes
| os_family | shadow | `login.defs` at start | Reads `login.defs.d` | `ENCRYPT_METHOD` at start | New account after the solution | `chpasswd` hash |
|---|---|---|---|---|---|---|
| Debian | 4.17.4 | `/etc`, `PASS_*` present | no | `YESCRYPT` | `1:365:7:45` | `$y$` |
| RedHat | 4.15.0 (rocky, alma), 4.19.0 (fedora) | `/etc`, `PASS_*` present | yes | `YESCRYPT` | `1:365:7:45` | `$y$` |
| Suse | 4.17.2 | only `/usr/etc` | yes | `SHA512` | `1:365:7:45` | `$6$` |
| Alpine | 4.18.0 | `/etc`, no `PASS_*`, no method | no | none → `SHA512` written | `1:365:7:45` | `$6$` (before too) |
| Archlinux | 4.20.0 | `/etc`, no `PASS_*` | no | `YESCRYPT` | `:365:7:45` | `$y$` |

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| Check passes, new accounts still get `99999` | values only in a drop-in on a host without `libeconf` | edit `/etc/login.defs` where it exists |
| opensuse loses its vendor defaults | `/etc/login.defs` created next to `/usr/etc/login.defs` | drop-in in `/etc/login.defs.d` |
| `YESCRYPT` became `SHA512` | unconditional `lineinfile` | read the method first |
| `useradd -D -f 45` reports `changed` on every run | no read step | `useradd -D` first, `when` on its output |
| Min field empty on arch although `PASS_MIN_DAYS 1` | shadow 4.20 ignores the key | expected; detect the capability (4.04) |
| Existing accounts keep `99999` | `login.defs` applies to new accounts only | `chage --maxdays` / `user: password_expire_max` |

### Real-world notes
- Fix existing accounts too (bonus 1): CIS audits the default and every account with a password.
  Skip locked (`!`) and passwordless (`*`) entries.
- Verify the effect, not the file: create a test account, read its `shadow` fields, delete it.
- Keep hash choice in one place per host family and check both `login.defs` and the PAM stack.

### Further reading
- Lesson [L08 - Accounts and PAM](../../../docs/lessons/L08-accounts-and-pam.md): `shadow` fields, hash prefixes, vendor split.
- Exercise [3.03 - Password quality with pam_pwquality](../3.03-password-quality/README.md)
- Exercise [4.04 - Ansible Vault: break-glass admin account](../../stage4-advanced/4.04-vault-break-glass-account/README.md): detecting `--mindays`.
- [`login.defs(5)`](https://man.archlinux.org/man/login.defs.5), [`shadow(5)`](https://man.archlinux.org/man/shadow.5), [`chage(1)`](https://man.archlinux.org/man/chage.1), [`useradd(8)`](https://man.archlinux.org/man/useradd.8)

## Reference solution

Show it with `lab solution 3.02`, apply it with `lab solve 3.02`.
