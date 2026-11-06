# 4.04 - Ansible Vault: Notfall-Admin-Konto

## Hinweis 1

`printf 'eigenes-passwort\n' > .vault-pass; chmod 600 .vault-pass`, dann `ansible-vault create --vault-password-file .vault-pass vault.yml` und `vault_cisadmin_password: ...` eintragen. Im Play laden mit `vars_files: [vault.yml]`.

## Hinweis 2

Stabiles Salt: `(inventory_hostname | hash('sha256'))[:16]` - pro Host deterministisch, zwischen Hosts verschieden. Hash: `vault_cisadmin_password | password_hash('sha512', cis_salt)`.

## Hinweis 3

Das Gerüst - fülle jedes `"..."` aus:

```yaml
- name: Break-glass admin account
  hosts: targets:!alpine_family
  become: true
  vars_files:
    - vault.yml
  vars:
    cis_salt: "..."                  # Hinweis 2
  tasks:
    - name: Does chage still support a minimum password age?
      ansible.builtin.command: chage --help
      register: cis_chage_help
      changed_when: false
      check_mode: false
      failed_when: false

    - name: Create cisadmin with an aging policy
      vars:
        cis_chage_mindays: "..."     # nennt der Hilfetext --mindays?
      ansible.builtin.user:
        name: cisadmin
        shell: /bin/sh
        password: "..."              # Hinweis 2: Vault-Passwort, sha512, stabiles Salt
        password_expire_max: "..."
        password_expire_min: "..."   # weglassen, wo es kein Mindestalter gibt
      no_log: true

    - name: Allow cisadmin to use sudo with password
      ansible.builtin.copy:
        dest: /etc/sudoers.d/60-cisadmin
        content: "..."
        owner: root
        group: root
        mode: "..."
        validate: "..."              # eine Syntaxprüfung, die die Datei als %s bekommt
```

Referenz: `lab solution 4.04` (das Vault-Passwort steht in `solution/.vault-pass`).
