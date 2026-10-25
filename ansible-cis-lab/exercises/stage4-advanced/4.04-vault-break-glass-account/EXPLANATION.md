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

### Break-glass hygiene
Password required for sudo (no NOPASSWD), aging policy applies, alert on every login of
this account (auditd/SIEM), store the vault password separately from the repository.

## Reference solution

Show it with `lab solution 4.04`, apply it with `lab solve 4.04`.
