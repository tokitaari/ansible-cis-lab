# 4.04 - Ansible Vault: break-glass admin account: Explanation

### What the check verifies
`lab check 4.04` runs `check.yml`, then your playbook once more with `--check` and expects
`changed=0`. The second run needs the vault password, so pass `--vault-password-file` to
`lab check`. `check.yml` has two plays:
- On the control node, `vault.yml` must start with `$ANSIBLE_VAULT`. The content is not read; a
  plain-text file fails.
- On every target except Alpine, it reads `/etc/shadow` and `/etc/sudoers.d/60-cisadmin`. The
  `cisadmin` entry needs a hash starting with `$6$` or `$y$`, a maximum age of 365 and a minimum
  age of at least 1 (only where `chage --help` still lists `--mindays`). The sudoers file needs
  the rule `cisadmin ALL=(ALL) ALL` and no `NOPASSWD`.

The check never logs in as `cisadmin`, so it cannot judge the password. It does not look at
`no_log` either - that requirement is yours to keep.

### How it works

#### Vault basics
```bash
ansible-vault create  --vault-password-file .vault-pass vault.yml
ansible-vault view    --vault-password-file .vault-pass vault.yml
ansible-vault rekey   ...    # new vault password
ansible-playbook playbook.yml --vault-password-file .vault-pass
```
Convention: secrets are named `vault_*` and referenced from normal variables
(`cisadmin_password: "{{ vault_cisadmin_password }}"`) so `grep` finds where secrets
are used without decrypting anything.

#### Why the salt matters
`password_hash('sha512')` without a salt argument draws a random salt on every call: a
different hash each run, `changed` every time, and every run replaces a password a human may
have set. A salt derived from the host name gives the same hash on each run and different
hashes on different hosts, so one cracked hash does not show that a password is reused. The
solution takes 16 characters of the host name's SHA-256, the maximum a SHA-512 salt can hold.

The salt is not the whole input. The filter hands it to a backend on the control node:
libxcrypt (the lab's control node) or passlib. The same salt comes back as a **different**
string from the two - measured: the literal salt `demosalt1234` gave `YJKPjBLMgFLA` from
libxcrypt and was kept verbatim by passlib. Each backend is stable on its own, so nothing
changes between runs. A new control node image, a changed pin or another Python can switch the
backend, though, and then every host reports one `changed` for the new hash string. The
password itself stays the same.

#### no_log
The `user` module masks `password` in its own output (`NOT_LOGGING_PASSWORD`). Measured with
ansible-core 2.21.6: neither `-v`, `-vvv`, `--diff` nor a failing task printed the hash or the
password. `no_log: true` stays a requirement anyway. Other modules do print what they are given
(L12 shows a `copy` task whose `--diff` and a `debug` task print a token), and callback
plugins (AWX/AAP job output) store task data. With `no_log` Ansible shows
`the output has been hidden`. It hides useful error messages too - add it after
the task works.

#### Feature detection: the minimum password age is gone
shadow 4.20 removed the minimum password age without replacement - `chage -m/--mindays`,
`passwd -n`, `PASS_MIN_DAYS` in `login.defs` and the `sp_min` field. Upstream considers it a
vulnerability (it stops a user from replacing a leaked password right away) and makes the
tools fail on purpose, so that scripts relying on it get noticed. Arch ships it first:
`ansible.builtin.user` with `password_expire_min` runs `chage -m` and fails there.

Do not hard-code "Arch has no minimum age" - every distribution follows with its next shadow
update. Ask the tool and drop the option with `omit`:
```yaml
- name: Does chage still support a minimum password age?
  ansible.builtin.command: chage --help
  register: cis_chage_help
  changed_when: false
  check_mode: false
  failed_when: false
- name: Create cisadmin with an aging policy
  vars:
    cis_chage_mindays: "{{ (cis_chage_help.stdout ~ cis_chage_help.stderr) is search('--mindays') }}"
  ansible.builtin.user:
    name: cisadmin
    password_expire_max: 365
    password_expire_min: "{{ 1 if cis_chage_mindays else omit }}"
```
The check accepts an empty or `0` minimum age where `chage` no longer supports it. A leftover
`PASS_MIN_DAYS` line in `login.defs` (3.02) is ignored by shadow 4.20 - `useradd` still works.

### Per-family notes

| os_family | Hosts | Account tools | Minimum password age | Notes |
|---|---|---|---|---|
| Debian | debian, ubuntu | shadow `useradd`, `chage` | supported | `visudo` in `/usr/sbin` |
| RedHat | rocky, alma, fedora | shadow `useradd`, `chage` | supported | `visudo` in `/sbin` (rocky, alma) or `/usr/sbin` (fedora) |
| Suse | opensuse | shadow `useradd`, `chage` | supported | `visudo` in `/usr/sbin` |
| Archlinux | arch | shadow `useradd`, `chage` | removed with shadow 4.20 | `visudo` in `/usr/bin` |
| Alpine | alpine | shadow `useradd`, `usermod`, `chage` in the lab image | supported (`password_expire_max` measured) | left out: no Python before 0.02 |

The `visudo` column is what `command -v` printed (L14 measurement). The solution calls
`/usr/sbin/visudo` and passes on every host of this exercise.

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `changed` on every run, a new hash each time | `password_hash` without a salt draws a random one | derive the salt from `inventory_hostname` |
| one `changed` per host after the control node changed | libxcrypt and passlib turn the same salt into different strings | expected once; keep the control node's packages pinned |
| `user` fails on arch with `chage -m` | shadow 4.20 has no minimum age | ask `chage --help`, `omit` the option |
| the check accepts `$y$`, your hash is `$6$...` | `password_hash` accepts md5, blowfish, sha256 and sha512 only, so it never produces `$y$` | nothing to fix; the check is wider than the filter |
| after rotating the vault password `changed=0` and the old hash stays | `update_password: on_create` sets the password only when the account is created | keep the default `always` for a break-glass account |
| `Attempting to decrypt but no vault secrets found` | no password source for `vault.yml` | pass `--vault-password-file`, also to `lab check` |
| the failing task shows only `the output has been hidden` | `no_log: true` hides errors too | remove it while debugging, add it back afterwards |

### Real-world notes
- Password required for sudo (no `NOPASSWD`), the aging policy applies, and every login of the
  account raises an alert (auditd/SIEM). Rotate the password after every use.
- Store the vault password separately from the repository; in production it comes from a
  script that asks a secret store (`--vault-password-file` may be executable).
- The `no-log-password` rule of ansible-lint is opt-in and did not fire on the solution even when
  enabled by name. A missing `no_log` is found in review, not by lint.

### Further reading
- Lesson [L12 - Secrets with Ansible Vault](../../../docs/lessons/L12-secrets-with-ansible-vault.md): the concepts before this exercise, with demos and self-check questions.
- Lesson [L08 - Accounts and PAM](../../../docs/lessons/L08-accounts-and-pam.md): what the aging fields and the hash prefix mean.

## Reference solution

Show it with `lab solution 4.04`, apply it with `lab solve 4.04`.
