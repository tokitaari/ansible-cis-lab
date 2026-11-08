# L12 - Secrets with Ansible Vault: keeping a password out of Git and out of the log

*[Deutsch](L12-secrets-with-ansible-vault.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 4.04 | 5.2, 5.4.1 | ~30 min | L02, L04, L08 |

Automation needs secrets: the password of an emergency account, an API token, a key. A playbook
lives in Git and its output lives in terminals, job logs and tickets, so a secret written
plainly in either place is already lost. Ansible Vault encrypts what is stored; `no_log` and a
few habits keep it out of what is printed; and a password that ends up on a host has to be
turned into a hash in a way that does not make every run a change. This lesson covers those
three pieces and the places where each one stops helping.

## Learning goals

After this lesson you can ...

- [ ] say what Vault protects (data at rest in the repository) and name places where the plaintext still appears
- [ ] create, view, change and re-key vault files without an editor, and name the ways to supply the vault password
- [ ] choose between a vaulted file and a single encrypted value, and keep variable names searchable
- [ ] explain why a hash with a random salt makes a password task report `changed` on every run
- [ ] say what a fixed salt changes, which rules a salt must follow, and why the control node matters
- [ ] predict which output shows a secret (`-v`, `--diff`, a registered result, `debug`) with and without `no_log`
- [ ] switch `no_log` off for debugging without editing the task
- [ ] recognise the common vault errors and the `ansible-lint` pitfall

## Theory

### Where a secret leaks, and what Vault covers

A secret has three places to live: in the repository, in memory while a play runs, and in the
output. Vault protects the first. A password written in `group_vars` is in
every clone and every old commit for good, because deleting the line does not delete history.
Vault encrypts the file before it is committed; the repository then holds ciphertext, and
whoever can read it but does not know the vault password learns nothing about the content.

It does not protect the other two. While a play runs, the control node holds the decrypted value
and hands it to modules, and a module that is given a plaintext password does whatever it does
with it. The output is a separate problem: a task result, a `--diff`, a `debug` message or an
error text can print the value in a terminal, a CI log or an AWX job record. The third concept
of this lesson is about that. First the mechanics.

### Vault: files, passwords, ids

A vault file is a text file whose first line is a header and whose body is hex. In the lab
(ansible-core 2.21.6) the header reads `$ANSIBLE_VAULT;1.1;AES256`. The cipher is AES-256 in
counter mode with an HMAC-SHA256 over the result, and the key is derived from the vault password
with PBKDF2 (read from `ansible/parsing/vault/__init__.py` of that version). Two consequences
matter in practice. The file can be attacked offline by anyone who has it, so the strength of the
secret is the strength of the vault password. And every encryption uses fresh random values, so
the same plaintext gives a different file each time.

`ansible-vault create` and `edit` open `$EDITOR`, which is fine at a desk but no use in a script.
`encrypt` takes a file you prepared; `view` and `decrypt` read it back; `rekey` changes the vault
password. Set up a demo directory and try it (the passwords here are made up and only for this
lesson):

```bash
mkdir -p /tmp/lesson12 && cd /tmp/lesson12
printf 'lesson-only-password\n' > .vault-pass
chmod 600 .vault-pass
printf 'vault_lesson12_token: tok-4711\n' > secrets.yml
ansible-vault encrypt --vault-password-file .vault-pass secrets.yml
head -n 1 secrets.yml
ansible-vault view --vault-password-file .vault-pass secrets.yml
```

The vault password can come from three places: `--vault-password-file` (or the environment
variable `ANSIBLE_VAULT_PASSWORD_FILE`, which `ansible-lint` also needs, see the pitfalls), a prompt (`--ask-vault-pass`), or a program. If the file given to
`--vault-password-file` is executable, Ansible runs it and takes its standard output as the
password - tested with a two-line shell script. That is the hook for a secret store: the script
asks it and prints the answer, and no password file exists on disk. A trailing newline or CRLF in
a password file is ignored (tested), and Ansible does not warn if the file is readable by
others (tested with mode 0644), so `chmod` it yourself and keep it out of the repository with an
entry in `.gitignore`. The lab already does that for the whole `work/` directory.

Encrypting the same content twice proves the second property:

```bash
printf 'x: 1\n' > a.yml && cp a.yml b.yml
ansible-vault encrypt --vault-password-file .vault-pass a.yml b.yml
cmp a.yml b.yml || echo "different files for the same content"
```

For Git this means: re-encrypting an unchanged secret rewrites the whole body and the diff shows
a change that is not one. `ansible-vault edit` is gentler than it sounds - leaving the editor
without a change left the file byte for byte identical (tested with `EDITOR=true`) - but
`encrypt`, `decrypt` followed by `encrypt`, and `rekey` always write new content.

**Vault ids.** Different secrets can have different passwords: one for development, one for
production. `--vault-id dev@.dev-pass` encrypts with that password and writes the label into the
header (`$ANSIBLE_VAULT;1.2;AES256;dev`). A play that loads files with two labels needs both
`--vault-id` options. With only one of them it stops at the first file it cannot open with
`Decryption failed (no vault secrets were found that could decrypt)`. The same message appears for
a wrong password; without any password source it is `Attempting to decrypt but no vault secrets
found`.

**A whole file, or one value.** `ansible-vault encrypt_string` encrypts a single value and prints
it as a `!vault |` block that can sit in an otherwise plain variables file. That keeps the
variable name readable in diffs and in `grep`, but the block is awkward to review and to rotate
by hand. A fully encrypted file hides every name inside it, which makes the question "where is
this secret used?" hard to answer. The common convention solves that: keep the secrets in a
vaulted file under names that start with `vault_`, and give the rest of the project plain
variables that point at them. `group_vars` can be a directory, and Ansible loads every file in
it, decrypting the vaulted ones as it goes (tested):

```bash
mkdir -p group_vars/all
printf 'lesson12_token: "{{ vault_lesson12_token }}"\n' > group_vars/all/vars.yml
cp secrets.yml group_vars/all/vault.yml
grep -rn vault_lesson12_token group_vars
```

The `grep` finds the one place that connects the two names without decrypting anything. A play
then uses only the plain name:

```yaml
- name: Use the indirection
  hosts: targets
  gather_facts: false
  tasks:
    - name: Show that the value arrived without printing it
      ansible.builtin.debug:
        msg: "the token has {{ lesson12_token | length }} characters"
```

Save it as `/tmp/lesson12/gv.yml` and run `ansible-playbook gv.yml --vault-password-file
.vault-pass`: the group variables next to the playbook are loaded, and the play prints
`8 characters`. Without a password source the same play stops before its first task with
`Attempting to decrypt but no vault secrets found`. Vaulted files are also decrypted when a play
loads them with `vars_files` or `-e @file` (both tested).

### Hashing a password: salt and idempotency

Most modules that set a password on a host expect a hash, not the password (the `$id$salt$hash`
format of L08). The `password_hash` filter turns a plaintext into one on the control node, and
the module compares the *string* with what is stored. That is the source of a classic problem.
A salt is an input to the hash; when none is given, a new random one is made on every call, so
the filter returns a different string every time for the same password. The module sees a
difference on every run, reports `changed`, and writes a new hash, which is a change in
`/etc/shadow` for no reason. Two runs with the demo account below show it:

```yaml
- name: Salt and idempotency
  hosts: targets
  gather_facts: false
  become: true
  vars_files:
    - secrets.yml
  vars:
    lesson12_salt: null
  tasks:
    - name: Create a demo account with a hashed password
      ansible.builtin.user:
        name: lesson12
        shell: /bin/sh
        create_home: false
        password: "{{ vault_lesson12_token | password_hash('sha512', lesson12_salt) }}"
```

Save it as `/tmp/lesson12/hash.yml` and run it:

```bash
ansible-playbook hash.yml --vault-password-file .vault-pass          # changed
ansible-playbook hash.yml --vault-password-file .vault-pass          # changed again
ansible-playbook hash.yml --vault-password-file .vault-pass -e lesson12_salt=demosalt1234
ansible-playbook hash.yml --vault-password-file .vault-pass -e lesson12_salt=demosalt1234
```

On the session host three runs without a salt in a row each reported `changed=1`. With the salt
fixed, the first run changes the hash once, the next reports `changed=0`, and so does `--check`
after it. The demo account stays behind: remove it with
`userdel lesson12` (the `user` module with `state: absent` does the same) or `./lab.sh reset
<host>`.

So a stable hash needs a salt that you control. Four points come with that:

- **The rules.** For SHA-512 the salt has at most 16 characters from `./0-9A-Za-z`. A longer
  one fails with `invalid salt size supplied (20), expected at most 16`, one with another
  character with `invalid characters in salt` (both tested).
- **The algorithm.** The filter accepts `md5`, `blowfish`, `sha256` and `sha512`; `yescrypt`, the
  default of several lab hosts (L08), is rejected with `yescrypt is not in the list of supported
  passlib algorithms: md5, blowfish, sha256, sha512`. The result starts with `$6$rounds=656000$`:
  the number of rounds is part of the string (with `rounds=5000` the field was left out).
- **The decision.** Where does the salt come from? One constant for the whole inventory means two
  hosts with the same password have the same hash, which shows the reuse to anyone who reads both
  `shadow` files and lets one precomputed table serve all hosts. A salt that differs per host
  but is derived from something stable stays repeatable and avoids that. How you derive it is
  your design; it must produce a valid salt and must not change between runs.
- **The control node.** In ansible-core 2.21.6 `password_hash` uses the libxcrypt library of the
  control node when it is there (`-vv` prints `Using CryptHash to hash input with
  'sha512_crypt'`) and passlib only as a fallback. With libxcrypt the salt you pass is only
  seed material that the library turns into the salt it writes: the input `demosalt1234` ended up
  as `YJKPjBLMgFLA` in the hash. The passlib path puts the input into the hash unchanged, so the
  same call gives a different string there (tested by switching the path off in a Python
  session). Within one control node the hash is stable; the lab's control container and the
  session host gave the same string for the demo input. If you move the playbook to another
  control node, expect one `changed` per host the first time.

A second way to stop the changes is `update_password: on_create`, which tells the `user` module
to set the password only when the account is created. It works (tested: `changed=1`, then `0`
with a random salt), but it also stops everything else: when the secret in the vault is rotated,
the run reports `changed=0` and the old hash stays on the host. A password task that cannot
notice a rotation hides drift, which is the opposite of what a hardening run is for.

### no_log: what it hides and what it does not

Many tasks print their result. A task that handles a secret has to make sure the secret is not in
it, and there are two layers. The first is the module: a module declares which of its arguments
are sensitive and masks them in the result. Of the modules tested, `user` masks `password`
(the result shows `"password": "NOT_LOGGING_PASSWORD"`, and neither the hash nor the plaintext
showed up in `-v`, `-vvv`, `--diff` or in the output of a failing task), and `copy` masks
`content`. The second layer is the task keyword `no_log: true`, which hides the whole result.
It matters wherever a secret is not an argument the module knows about: on a command line, in a
`copy` that is shown with `--diff`, in a variable that a later task prints. The play below puts a
secret in four of those places, after a set-up task for the directory (the targets are separate
hosts, and `copy` does not create parents). The read-back is skipped in check mode because the
file does not exist yet:

```yaml
- name: Where does a secret show up?
  hosts: targets
  gather_facts: false
  vars_files:
    - secrets.yml
  tasks:
    - name: Make sure the demo directory exists
      ansible.builtin.file:
        path: /tmp/lesson12
        state: directory
        mode: "0755"
      # set-up of the demo, not part of the lesson
      check_mode: false

    - name: Write a config file with the secret
      ansible.builtin.copy:
        dest: /tmp/lesson12/plain.conf
        content: "token={{ vault_lesson12_token }}\n"
        mode: "0600"

    - name: Write the same file with no_log
      ansible.builtin.copy:
        dest: /tmp/lesson12/hidden.conf
        content: "token={{ vault_lesson12_token }}\n"
        mode: "0600"
      no_log: true

    - name: Read the hidden file back
      ansible.builtin.command: cat /tmp/lesson12/hidden.conf
      register: lesson12_read
      changed_when: false
      no_log: true
      when: not ansible_check_mode

    - name: Print what the registered result holds
      ansible.builtin.debug:
        msg: "{{ lesson12_read.stdout }}"
      when: not ansible_check_mode
```

Save it as `/tmp/lesson12/leak.yml` and run it with `--diff` (a second run reports
`changed=0`):

```bash
ansible-playbook leak.yml --vault-password-file .vault-pass --diff
```

The first task shows the secret in its diff, as `+token=tok-4711`, although the `copy` module
masks the content in the result: at `-v` and `-vvv` the secret did not appear. The second task
prints neither a diff nor a result (`no_log` suppresses the diff too; `diff: false` on the task
does the same for the diff alone). The last task prints the secret, and that is the lesson's
point: `no_log` stops *that* task from printing, but the registered variable still holds the
value, and whatever reads it later is free to show it. The same goes for `ansible-inventory
--list` (it printed the decrypted value of a vaulted group variable) and for `debug` with `var:`.
Do not print what you registered from a secret-bearing task, and do not register it unless the
next task needs it.

Three more details. In a loop, `no_log` also hides the item: the label becomes
`(censored due to no_log)`. A failure inside a `no_log` task is reported without its cause, only
`Module failed: The command exited with a non-zero return code.`, so a broken task is hard to
debug. And a command line is printed by modules that echo it back: a `command` with the secret in
its argument showed it at `-v` and in its failure message. The usual compromise is a variable
that decides:

```yaml
- name: no_log that can be switched off
  hosts: targets
  gather_facts: false
  vars_files:
    - secrets.yml
  vars:
    lesson12_show: false
  tasks:
    - name: Run a command that fails, with the secret on its command line
      ansible.builtin.command: "false {{ vault_lesson12_token }}"
      changed_when: false
      ignore_errors: true
      no_log: "{{ not (lesson12_show | bool) }}"
```

Save it as `/tmp/lesson12/nolog.yml`. The default run prints a `censored` message for the
failure; `-e lesson12_show=true` prints the command, including `tok-4711`. Use the second form
on a throwaway host only, and never in CI. A global switch exists (`ANSIBLE_NO_LOG=true`; the
diff of `leak.yml` showed no secret with it), but it hides the details of every task, the ones
you want to read included; the keyword with a variable decides per task. All of these results are
from ansible-core 2.21.6;
which module arguments are masked is decided per module and can differ for others or in other
versions, so look at the output of a test run before relying on it.

## CIS background

A break-glass account exists for the day when SSO or the automation account does not work, and it
is therefore the account that must work without anything else. That makes it both useful and
dangerous: it is a standing local administrator. The lab's catalogue has no recommendation that asks for such an
account; the recommendations ask that every account that exists follows the same rules. Password aging and strong hashing
for local accounts are 5.4.1 of [the control catalogue](../../cis/controls.yml) (L08 covers what
the values mean and where they come from). Privilege escalation through sudo, with its logging and
with re-authentication left on, is 5.2 (L03 explains the sudoers files).

The secret handling is not a benchmark topic, but it decides whether the benchmark settings mean
anything. A scanner reads the `shadow` entry and sees an algorithm prefix and some numbers; it
cannot tell that the password behind the hash is in a public repository. The practices in this
lesson close that gap: the secret in an encrypted file, the vault password stored separately from
the repository, a log that does not contain it, and a stable hash so that the run that enforces the
setting does not itself change the host every time. For a break-glass account add what automation
cannot do for you: monitor every login of it, and rotate its password after use.

## Platform differences

The platform differences of this topic sit on the control node and on the account tools. The
rows use the hosts' own facts; the *hash default* column repeats the L08 measurements.

| os_family | Hosts | Account tools | Minimum password age | Default hash for new passwords |
|---|---|---|---|---|
| Debian | debian, ubuntu | shadow `useradd`, `chage` | supported | YESCRYPT in `login.defs` |
| RedHat | rocky, alma, fedora | shadow `useradd`, `chage` | supported | YESCRYPT in `login.defs` |
| Suse | opensuse | shadow `useradd`, `chage` | supported | SHA512 in `/usr/etc/login.defs` |
| Alpine | alpine | shadow `useradd`, `usermod`, `chage` in the lab image; `adduser` is BusyBox | supported | no `ENCRYPT_METHOD` line |
| Archlinux | arch | shadow `useradd`, `chage` | removed with shadow 4.20 (`chage --help` lists no `--mindays`) | YESCRYPT in `login.defs` |

On alpine the `user` module accepted `password_expire_max` and `chage -l` showed it (measured
with the lab image after 0.02). Exercise 4.04 still leaves Alpine out; the exercise text gives its
own reason.

### In the lab containers

- The control container is built on `python:3.13-slim-trixie`; `password_hash` there uses
  libxcrypt, so its salt handling is the first of the two described above.
- The vault password of an exercise lives in `work/`, which Git ignores. In your own repository
  add the file name to `.gitignore` before the first commit; adding it afterwards leaves it in the
  history.
- The demo accounts and files of this lesson sit on the targets or in `/tmp/lesson12` on the
  control node. `./lab.sh reset <host>` removes the accounts (`.\lab.ps1 reset <host>` on Windows).
- Nothing here needs a kernel feature the containers lack (see
  [container limits](../CONTAINER_LIMITS.md)).

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| A password task is `changed` on every run | the hash is made with a random salt each time | give the filter a salt that is valid and repeatable; see the salt rules |
| `Attempting to decrypt but no vault secrets found` | the play loads an encrypted file and no password source was given | `--vault-password-file`, `ANSIBLE_VAULT_PASSWORD_FILE` or `--ask-vault-pass` |
| `Decryption failed (no vault secrets were found that could decrypt)` | wrong password, or a file with a label whose `--vault-id` is missing | use the password the file was encrypted with; pass every `--vault-id` the play needs |
| `ansible-lint` reports `internal-error` for `ansible-playbook --syntax-check` | the syntax check loads the vaulted file and has no password | export `ANSIBLE_VAULT_PASSWORD_FILE` before linting (with it set, a lint run passed) |
| The secret appears in `--diff` output | a file module shows the new content | `no_log: true`, or `diff: false` for the diff only |
| A later task prints a secret that the earlier task hid | the registered variable still holds the value | do not print it; do not register it unless needed |
| `invalid salt size supplied (20), expected at most 16` or `invalid characters in salt` | the salt breaks the rules of the algorithm | at most 16 characters from `./0-9A-Za-z` for SHA-512 |
| `yescrypt is not in the list of supported passlib algorithms` | the filter does not offer that algorithm | use `sha512` |
| Every host is `changed` once after the playbook moved to another machine | the other control node hashes the same salt differently | accept one change, and keep the control node uniform |
| The diff of a vault file changes although the secret did not | each encryption uses new random values | encrypt only when the content changes |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [4.04](../../exercises/stage4-advanced/4.04-vault-break-glass-account/README.md) | a vaulted variable file, a repeatable password hash, keeping secrets out of the output |

Start it with `lab start 4.04`; `lab show 4.04` prints its README.

## Self-check

1. What does Ansible Vault protect, and where does a vaulted secret appear in plaintext anyway?

   <details><summary>Answer</summary>

   It protects the file in the repository: whoever has the ciphertext but not the vault password
   learns nothing. The plaintext exists in the memory of the control node during a play, is
   passed to modules, and can be printed by task results, `--diff`, `debug` and error messages.

   </details>

2. You encrypt the same file twice and the two results differ. What follows for Git, and does a
   changed ciphertext mean the secret changed?

   <details><summary>Answer</summary>

   Every encryption uses fresh random values, so the body changes even when the content does not,
   and a diff of the file proves nothing about the secret. Only re-encrypt when the content really
   changes, and read the change with `ansible-vault view` or by comparing the decrypted values.

   </details>

3. A task that sets a password reports `changed` on every run. What is the cause, and what does
   `update_password: on_create` cost compared with fixing the cause?

   <details><summary>Answer</summary>

   `password_hash` without a salt invents a new one each call, so the string differs each time
   although the password is the same. `on_create` makes the task report `changed=0`, but it also
   never changes an existing password: a rotation in the vault is ignored and the old hash stays.
   A repeatable salt keeps both idempotency and rotation.

   </details>

4. A salt with 20 characters fails. After the playbook runs from another machine every host
   reports one change. Explain both.

   <details><summary>Answer</summary>

   A SHA-512 salt has at most 16 characters from `./0-9A-Za-z`. The second case comes from the
   control node: with libxcrypt the passed salt is only seed material, with the passlib fallback
   it is written into the hash unchanged, so the same call gives another string. Within one
   control node the hash is stable; across control nodes it is not guaranteed.

   </details>

5. A `copy` task puts a secret in a file. Does `-v` print it? Does `--diff`? What changes with
   `no_log: true`, and what can still show it afterwards?

   <details><summary>Answer</summary>

   `copy` masks `content` in the result, so `-v` does not show it, but `--diff` prints the new
   content. `no_log: true` suppresses the diff and the result of that task. A variable registered
   from a task that read the secret still holds it, and a later `debug` can print it.

   </details>

6. Why is `no_log` set through a variable in some projects, and why not simply left off in a
   development run?

   <details><summary>Answer</summary>

   A `no_log` task hides the reason for its own failure, which makes debugging hard. A variable
   lets a developer turn it off on a throwaway host with `-e` without editing the task. Leaving
   it off by default would put secrets in logs, so the safe value is the default.

   </details>

7. `ansible-lint` fails on a playbook with a vaulted `vars_files` although the playbook runs.
   What is missing, and which two ways are there to organise names so that `grep` still finds
   where a secret is used?

   <details><summary>Answer</summary>

   The syntax check of the linter loads the vaulted file and has no vault password; setting
   `ANSIBLE_VAULT_PASSWORD_FILE` fixes it. To keep names searchable, either keep the variable
   names plain and encrypt only the values with `encrypt_string`, or keep the secrets in a
   vaulted file named `vault_*` and reference them from plain variables in a second file.

   </details>

## Further reading

- [Protecting sensitive data with Ansible vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html) - the vault guide: ids, `encrypt_string`, password sources
- [ansible-vault](https://docs.ansible.com/projects/ansible/latest/cli/ansible-vault.html) - every subcommand and option
- [password_hash filter](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/password_hash_filter.html) - algorithms, `salt`, `rounds`
- [Protecting sensitive data with no_log](https://docs.ansible.com/projects/ansible/latest/reference_appendices/logging.html#protecting-sensitive-data-with-no-log) - what the keyword hides and what it does not
- [`crypt(5)`](https://man.archlinux.org/man/crypt.5) - the hash formats and the meaning of `$id$`, salt and rounds
- [Glossary](../GLOSSARY.md) - terms of this lesson: `no_log`, salt, Vault
