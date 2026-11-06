# 4.04 - Ansible Vault: break-glass admin account

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★☆ | ~60 min | 5.4.1 / 5.2 (L1) | `targets:!alpine_family` |

**Concepts:** `ansible-vault`, `password_hash with stable salt`, `no_log`, `user aging fields`

## Goal

Create an emergency admin account `cisadmin` on all targets except Alpine. Its password lives encrypted in Git, its hash is stable (idempotent), and the account obeys the password aging policy.

## Background

When SSO or the automation account breaks, you need a "break-glass" account. Its
password must never be in plain text - not in Git, not in logs, not in `-v` output.

Three classic mistakes this exercise avoids:
1. plaintext secret in `group_vars` → **Ansible Vault**,
2. `password_hash('sha512')` without salt → a new random salt each run → `changed`
   every time (and every run changes the password hash!) → **stable salt**,
3. secrets in task output → **`no_log: true`**.

Alpine is left out because it has no Python before 0.02 and this exercise has no
prerequisites. The account tools are not the reason: the lab image has shadow's `useradd`,
`usermod` and `chage`, and the `user` module accepted `password_expire_max` there.

## Requirements

- [ ] `/lab/work/4.04/vault.yml` is encrypted with `ansible-vault` and defines `vault_cisadmin_password`. Keep the vault password in `/lab/work/4.04/.vault-pass` (lab only - never commit it).
- [ ] User `cisadmin`: password from the vault, hashed with SHA-512 and a **per-host stable salt**, `password_expire_max: 365`, `password_expire_min: 1` (only where `chage` still supports it - shadow 4.20 removed the minimum age, see the explanation).
- [ ] `/etc/sudoers.d/60-cisadmin`: `cisadmin ALL=(ALL) ALL` (password required - no `NOPASSWD`), `0440`, validated.
- [ ] The user task uses `no_log: true`.
- [ ] Second run: `changed=0`. Run the check with the vault password: `lab check 4.04 --vault-password-file /lab/work/4.04/.vault-pass`.

## How to work

```bash
lab start 4.04            # creates /lab/work/4.04/
cd /lab/work/4.04
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 4.04            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.04 1` (gentle) ... `lab hint 4.04 3` (almost the answer).  
Passed? Read `lab explain 4.04` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Rotate the password: `ansible-vault edit vault.yml`, re-run. Exactly one change per host?
- Use `ansible-vault encrypt_string` for a single variable inside an otherwise plain file. When is which approach better?
- In real environments the vault password comes from a script (`--vault-password-file` can be executable) that asks a secret store. Sketch one for Azure Key Vault or HashiCorp Vault.
- Add `update_password: on_create` to the `user` task, rotate the password in the vault and re-run. What changes on the hosts, and when would you want that behaviour?
- Run the play on Alpine too (finish 0.02 first and widen `hosts` in your copy). Does `password_expire_min` work there, and what does `chage --help` list?
