# 4.04 - Ansible Vault: Notfall-Admin-Konto

## Hinweis 1

`printf 'eigenes-passwort\n' > .vault-pass; chmod 600 .vault-pass`, dann `ansible-vault create --vault-password-file .vault-pass vault.yml` und `vault_cisadmin_password: ...` eintragen. Im Play laden mit `vars_files: [vault.yml]`.

## Hinweis 2

Stabiles Salt: `(inventory_hostname | hash('sha256'))[:16]` - pro Host deterministisch, zwischen Hosts verschieden. Hash: `vault_cisadmin_password | password_hash('sha512', cis_salt)`.

## Hinweis 3

`ansible.builtin.user`-Optionen: `password`, `password_expire_max`, `password_expire_min`, `shell`, `no_log: true` am Task. Referenz: `lab solution 4.04` (das Vault-Passwort steht in `solution/.vault-pass`).
