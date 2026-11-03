# 4.04 - Ansible Vault: break-glass admin account: Explanation

### Vault basics
```bash
ansible-vault create  --vault-password-file .vault-pass vault.yml
ansible-vault view    --vault-password-file .vault-pass vault.yml
ansible-vault rekey   ...    # new vault password
ansible-playbook playbook.yml --vault-password-file .vault-pass
```
Convention: secrets are named `vault_*` and referenced from normal variables
(`cisadmin_password: "{{ vault_cisadmin_password }}"`) so `grep` finds where secrets
are used without decrypting anything.

### Why the salt matters
`password_hash('sha512')` generates a random salt → a different hash each run →
`changed` every time, and every run invalidates any password a human might have set.
A deterministic salt derived from the host name gives the same hash on each run but
different hashes across hosts (so one cracked hash does not reveal reuse).

### no_log
Without it, `-v` prints the hash, and callback plugins (logs, AWX/AAP job output) store
it. With it, Ansible shows `the output has been hidden`. It also hides useful error
messages - add it after the task works.

### Feature detection: the minimum password age is gone
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

### Break-glass hygiene
Password required for sudo (no NOPASSWD), aging policy applies, alert on every login of
this account (auditd/SIEM), store the vault password separately from the repository.

## Reference solution

Show it with `lab solution 4.04`, apply it with `lab solve 4.04`.
