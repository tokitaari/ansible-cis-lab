# 3.02 - Password aging and inactive accounts: Explanation

### Key techniques
**Read-then-act for commands**
```yaml
- name: Read useradd defaults
  ansible.builtin.command: useradd -D
  register: cis_useradd_defaults
  changed_when: false
  check_mode: false          # also runs in --check, it only reads
- name: Lock accounts after 45 days of inactivity
  ansible.builtin.command: useradd -D -f 45
  when: "'INACTIVE=45' not in cis_useradd_defaults.stdout_lines"
  changed_when: true
```
A command module cannot know if it changed anything. You make it idempotent by
checking first and reporting honestly.

**Facts from files**
`slurp` returns base64; `b64decode` + `regex_findall` extracts values. `last` mirrors
how login.defs works (later lines override earlier ones).

### Why "do not downgrade" matters
yescrypt is memory-hard and much more expensive to brute-force on GPUs than SHA-512
crypt. A hardening role that silently weakens a system fails its purpose - and a CIS
scanner would not even notice, because both values are accepted.

### The /usr/etc story
Atomic/immutable designs (openSUSE, Fedora's `/usr/etc` work) keep vendor defaults
in `/usr` and only admin overrides in `/etc`. Hardening code that "creates the file
if missing" can wipe all vendor defaults at once. Always check how a component reads
its configuration before you write it.

### Existing users (bonus)
`login.defs` is read by `useradd` - existing accounts keep their aging fields.
CIS audits both: the default and every user with a password. `chage --maxdays 365
<user>` or `ansible.builtin.user` with `password_expire_max: 365` fixes them.

## Reference solution

Show it with `lab solution 3.02`, apply it with `lab solve 3.02`.
