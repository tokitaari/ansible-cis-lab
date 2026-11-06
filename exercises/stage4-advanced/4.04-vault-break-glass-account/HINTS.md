# 4.04 - Ansible Vault: break-glass admin account

## Hint 1

`printf 'choose-a-pass\n' > .vault-pass; chmod 600 .vault-pass`, then `ansible-vault create --vault-password-file .vault-pass vault.yml` and add `vault_cisadmin_password: ...`. Load it in the play with `vars_files: [vault.yml]`.

## Hint 2

Stable salt: `(inventory_hostname | hash('sha256'))[:16]` - deterministic per host, different between hosts. Hash: `vault_cisadmin_password | password_hash('sha512', cis_salt)`.

## Hint 3

The skeleton - fill in every `"..."`:

```yaml
- name: Break-glass admin account
  hosts: targets:!alpine_family
  become: true
  vars_files:
    - vault.yml
  vars:
    cis_salt: "..."                  # hint 2
  tasks:
    - name: Does chage still support a minimum password age?
      ansible.builtin.command: chage --help
      register: cis_chage_help
      changed_when: false
      check_mode: false
      failed_when: false

    - name: Create cisadmin with an aging policy
      vars:
        cis_chage_mindays: "..."     # does the help text list --mindays?
      ansible.builtin.user:
        name: cisadmin
        shell: /bin/sh
        password: "..."              # hint 2: vault password, sha512, stable salt
        password_expire_max: "..."
        password_expire_min: "..."   # omit it where there is no minimum age
      no_log: true

    - name: Allow cisadmin to use sudo with password
      ansible.builtin.copy:
        dest: /etc/sudoers.d/60-cisadmin
        content: "..."
        owner: root
        group: root
        mode: "..."
        validate: "..."              # a syntax check that gets the file as %s
```

Reference: `lab solution 4.04` (its vault password is in `solution/.vault-pass`).
