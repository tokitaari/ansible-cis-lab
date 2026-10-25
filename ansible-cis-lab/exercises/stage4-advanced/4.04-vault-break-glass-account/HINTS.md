# 4.04 - Ansible Vault: break-glass admin account

## Hint 1

`printf 'choose-a-pass\n' > .vault-pass; chmod 600 .vault-pass`, then `ansible-vault create --vault-password-file .vault-pass vault.yml` and add `vault_cisadmin_password: ...`. Load it in the play with `vars_files: [vault.yml]`.

## Hint 2

Stable salt: `(inventory_hostname | hash('sha256'))[:16]` - deterministic per host, different between hosts. Hash: `vault_cisadmin_password | password_hash('sha512', cis_salt)`.

## Hint 3

`ansible.builtin.user` options: `password`, `password_expire_max`, `password_expire_min`, `shell`, `no_log: true` on the task. Reference: `lab solution 4.04` (its vault password is in `solution/.vault-pass`).
