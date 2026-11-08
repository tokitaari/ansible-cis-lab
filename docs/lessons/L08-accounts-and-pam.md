# L08 - Accounts and PAM: who may log in, how, and with what password

*[Deutsch](L08-accounts-and-pam.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 3.02, 3.03, 3.05, 4.06 | 5.3.2, 5.3.3, 5.4.1, 5.4.2, 5.4.3 | ~30 min | L02, L03, L04 |

Every login ends in two questions: which account is this, and may it come in? Linux answers them
with a few text files and a stack of small modules called PAM. Hardening the answers means
reading those files correctly, knowing which defaults reach which accounts, and changing a stack
that a tool often writes for you. This lesson covers the account databases, aging and hashing,
how PAM stacks are built, the two modules the exercises configure, and why none of it shows up
in the shell Ansible uses.

## Learning goals

After this lesson you can ...

- [ ] read a `passwd` and a `shadow` entry and say what `x`, `*`, `!` and an empty field mean
- [ ] explain why the UID matters more than the name `root`, and why `getent` and a file can disagree
- [ ] say which aging values a default in `login.defs` reaches and which it does not
- [ ] tell the hash algorithm from the prefix of a hash and find the two places that choose it
- [ ] read a PAM rule (type, control, module) and predict what `required`, `requisite` and `sufficient` do
- [ ] explain why hand-edited PAM files get lost and name the generator of each family
- [ ] describe what `pam_pwquality` and `pam_faillock` check, when, and what they leave alone
- [ ] say why `umask` and `TMOUT` set in a profile script are invisible to an Ansible task

## Theory

### Account databases: passwd, shadow and what the password field says

A Linux account is a line in a text file. `/etc/passwd` has seven colon-separated fields: name,
password placeholder, UID, GID, comment, home directory, shell. It is world-readable, so the
password does not live there: the second field is `x`, a pointer to `/etc/shadow`. That file is
readable by root only and holds, per account: name, password field, day of the last change
(days since 1970-01-01), minimum age, maximum age, warning period, inactivity period, expiry
day, and a reserved field.

The password field is what audits care about:

| Value | Meaning |
|---|---|
| `$id$salt$hash` | a password hash; the `id` names the algorithm (next concept) |
| starts with `!` | locked: the hash is kept but no password matches; a lone `!` is locked without a hash |
| `*` | no password can ever match - typical for system accounts |
| empty | **no password at all**; the account is not locked |

An empty field is dangerous because of `pam_unix`: its manual says a blank password is refused
unless the option `nullok` is set, and the `password` lines of `pam_unix` carry `nullok` on
opensuse, fedora, rocky, alma and arch (measured with `grep`). The audit question is "is the
field empty?", not "does the stack currently forgive it?".

The name `root` is a convention. The kernel decides on the **UID**: every account with UID 0 has
root's privileges, whatever its name. "Who is root here?" is answered by the third field of
`passwd`, not by the first.

Reading accounts has two sources that can disagree. A file parser sees the file on that host.
`getent` asks the Name Service Switch (NSS), which consults the files *and* whatever else the
host is configured for (LDAP, SSSD, ...). For an audit of the local databases read the files;
for "who can log in here at all" ask `getent`. The module `ansible.builtin.getent` stores the
answer as a fact:

```yaml
- name: Which accounts have a real login shell?
  hosts: targets
  gather_facts: false
  tasks:
    - name: Read the passwd database through NSS
      ansible.builtin.getent:
        database: passwd
    - name: Accounts whose shell is not a no-login shell
      vars:
        no_login: [/sbin/nologin, /usr/sbin/nologin, /usr/bin/nologin, /bin/false, /bin/sync, /sbin/halt, /sbin/shutdown]
        rows: "{{ ansible_facts.getent_passwd | dict2items | rejectattr('value.5', 'in', no_login) | list }}"
      ansible.builtin.debug:
        msg: "{{ rows | map(attribute='key') | zip(rows | map(attribute='value.1'), rows | map(attribute='value.5')) | map('join', ' ') | list }}"
```

`getent_passwd` maps each name to the list `[x, UID, GID, comment, home, shell]`, so `value.1` is
the UID and `value.5` the shell. On the Ubuntu 24.04 host where I tested, the play lists four
accounts (root, ubuntu, postgres, claude), each with `/bin/bash`. The path of a no-login shell
differs per distribution, which is why the play names all of them.

### Aging, hashing and where defaults come from

**Aging** is the set of numbers in the `shadow` entry: minimum and maximum password age, the
warning period, and the inactivity period after which an expired account is locked. `chage -l
<user>` prints them. New accounts get them from `/etc/login.defs` (`PASS_MAX_DAYS`,
`PASS_MIN_DAYS`, `PASS_WARN_AGE`); the inactivity default comes from `useradd -D`. The key word
is *new*: the values are copied into the account when it is created. Tested with `useradd` on the
session host: after `PASS_MAX_DAYS` was set to 365, an account created afterwards had 365 and the
account created before kept 99999. A changed default secures future accounts only; existing ones
keep what they have until `chage` (or the `user` module) changes them.

```yaml
- name: Where do a new account's aging values come from?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Create a demo account without a password
      ansible.builtin.user:
        name: lesson08
        shell: /bin/sh
        create_home: false
    - name: Read its aging values
      ansible.builtin.command: chage -l lesson08
      register: aging
      changed_when: false
      when: not ansible_check_mode
    - name: Read the defaults of the shadow tools
      ansible.builtin.command: grep -h -E '^[[:space:]]*PASS_(MAX|MIN|WARN)' /etc/login.defs /usr/etc/login.defs
      register: defs
      changed_when: false
      failed_when: defs.rc > 2
      check_mode: false
    - name: Compare both
      ansible.builtin.debug:
        msg:
          account: "{{ aging.stdout_lines | default([]) | select('match', '(Minimum|Maximum|Number of days)') | list }}"
          login_defs: "{{ defs.stdout_lines }}"
      when: not ansible_check_mode
```

The demo account stays behind: remove it with `userdel lesson08` or `./lab.sh reset <host>`
(`.\lab.ps1 reset <host>` on Windows). `grep` exits with 2 when one of its files is missing but
still prints matches from the other, so the play accepts return codes up to 2. On the Ubuntu
host both sections show 99999, 0 and 7. Run it on all eight hosts and watch which of the two
files holds the values, and what `chage -l` prints on arch.

**Hashing.** A hash in `shadow` starts with `$id$`; the id names the algorithm (checked with
`crypt(3)` on the session host):

| Prefix | Algorithm | Note |
|---|---|---|
| `$1$` | MD5 | obsolete |
| `$5$` | SHA-256 | |
| `$6$` | SHA-512 | the long-time default |
| `$y$` | yescrypt | newer; designed to be expensive in memory, so bulk guessing on GPUs costs more than against SHA-512 |

The prefix lets you audit an existing database without knowing any password. A hash is only
rewritten when its owner changes the password, so a stronger method protects *future* passwords;
old hashes keep their prefix.

Two places choose the method for a new password. `ENCRYPT_METHOD` in `login.defs` is read by the
shadow tools, and `pam_unix`'s manual says its default hash is taken from it. The `pam_unix` line
of the `password` stack may also name an algorithm itself. The lab hosts differ (table below):
debian, ubuntu and the Red Hat family name `yescrypt` on the line, arch and opensuse name
nothing; `login.defs` says YESCRYPT everywhere except opensuse (SHA512) and alpine (no
`ENCRYPT_METHOD` line). A method set in only one place, or set to something weaker than what the
host already uses, is easy to get wrong, and a scanner that accepts both values will not say so.

**Vendor split.** Some distributions keep their defaults below `/usr/etc` and read only the
administrator's overrides from `/etc`, so updates can replace vendor files without touching your
changes. On opensuse in the lab `/etc/login.defs` does not exist: the values are in
`/usr/etc/login.defs` and a directory `/etc/login.defs.d` exists. The rule is general: before you
create a file in `/etc`, check how the program finds its configuration - a "create it if
missing" task can replace the whole vendor default with the few lines you wrote.

**Features that go away.** `shadow` 4.20 removed the *minimum* password age as a security problem.
On the arch host `chage --help` lists no `--mindays` (`grep -c`: 0 matches, against 1 on the
other seven), so a task that sets the minimum age has nothing to call there. The robust habit is
L04's: ask what the host can do instead of testing the distribution's name.

### PAM: types, controls and who writes the stack

PAM (Pluggable Authentication Modules) separates *programs* that authenticate from the *rules*
that say how. When `sshd`, `su` or `passwd` needs a decision it calls the PAM library with its
**service name**, and the library reads `/etc/pam.d/<service>`. Each non-comment line is a rule
`type control module arguments`.

The **type** names the question:

- `auth` - is this user who they claim to be? (checks the password, hands out credentials)
- `account` - may this account use the service now? (expired, locked, wrong time)
- `password` - the user changes the secret: check it and store it
- `session` - set up and tear down what the session needs (logging, limits, mounts)

The **control** says what the module's result means for the whole stack (`pam.conf(5)`):

| Control | A failure of the module | A success |
|---|---|---|
| `required` | fails the stack, but the remaining modules still run | necessary, not enough |
| `requisite` | fails the stack at once and returns to the application | necessary, not enough |
| `sufficient` | is ignored | ends the stack with success if no earlier `required` module failed |
| `optional` | only matters if it is the only module of this type | likewise |
| `include` / `substack` | - | pull in the rules of that type from another file; a `substack` counts as one unit |

The bracket form `[success=1 default=ignore]` states the same per return value; this one means
"on success skip the next rule". Rules run top to bottom, so **order is part of the meaning**: a
`sufficient` module in front of a check can make the check unreachable.

Where do these files come from? Often not from you. Most families keep a generator that builds
the files every service includes from small profiles: `pam-auth-update` (Debian family),
`authselect` (Red Hat family), `pam-config` (SUSE). The commands exist on exactly those hosts
(`command -v` on all eight; none of the three on alpine and arch). A generated file says so: on
Ubuntu 24.04 the five `common-*` files all name `pam-auth-update` in their text, and the next
package that runs the tool rewrites them. A hand-edited line in such a file is not a
configuration, it is a countdown. Use the generator's mechanism (a profile, a feature) and let it
regenerate. This play lists, per host, the PAM files that are symbolic links and those that name
a generator:

```yaml
- name: Who maintains the PAM files of this host?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: PAM files that are symbolic links
      ansible.builtin.find:
        paths: /etc/pam.d
        file_type: link
      register: pam_links
    - name: PAM files that name a generator in their text
      ansible.builtin.find:
        paths: /etc/pam.d
        file_type: file
        contains: '.*(authselect|pam-auth-update|pam-config)'
      register: pam_generated
    - name: Show both lists
      ansible.builtin.debug:
        msg:
          links: "{{ pam_links.files | map(attribute='path') | map('basename') | sort }}"
          generated: "{{ pam_generated.files | map(attribute='path') | map('basename') | sort }}"
```

`find` matches `contains` from the start of each line, hence the leading `.*`. On Ubuntu the
result is the five `common-*` files and no links; I ran it there only, so run it on the other
hosts and compare with the generators above.

PAM differs from other hardening in one respect: **a mistake locks everybody out, your automation
included.** The habits of L02 apply (small steps, `--limit`, a backup of what you change), plus
one of their own: keep a second root session open while you change a stack and make the first
test a login from another terminal.

### Two modules on the stack: pwquality and faillock

**`pam_pwquality`** is a `password`-type module (the only type it provides): it runs when
somebody changes a password through a program that uses the PAM stack and judges the *new*
password; existing ones are never re-checked. Its settings live in `/etc/security/pwquality.conf`
and in the `*.conf` files of `/etc/security/pwquality.conf.d`, read in ASCII order with the later
value winning (`pwquality.conf(5)` of libpwquality 1.4.5) - the reason for the numeric prefix in
drop-in names: `50-site.conf` beats `10-vendor.conf`.

It checks, with the manual's defaults: a minimum length (`minlen`, 8), character classes
(`minclass` counts how many of digits, uppercase, lowercase and others must appear, default 0; or
per class with `dcredit`, `ucredit`, `lcredit`, `ocredit`, where a *negative* number means "at
least this many" and a positive one is a bonus toward the length), repeated characters
(`maxrepeat`), monotonic sequences (`maxsequence`) - both off at 0 - and a dictionary check
(`dictcheck`, on). One default matters most for hardening: **`enforce_for_root` is off**. When
root sets a password that fails the checks, root only gets a message and the change goes
through; a policy that ignores root has a hole where the most valuable password lives.

**`pam_faillock`** counts failed logins per account and locks the account after too many. The
module sits in the `auth` stack in up to three positions - `preauth` before the password is
asked, `authfail` and `authsucc` after the verdict - and once in `account` (`pam_faillock(8)`).
The counters are one file per user in a tally directory, by default `/var/run/faillock`, which a
reboot normally clears. Settings live in `/etc/security/faillock.conf` (`faillock.conf(5)` of
Linux-PAM 1.5.3): `deny` (default 3), `fail_interval` (900 s, the window in which failures count),
`unlock_time` (600 s; **0 means never** - locked until somebody resets it) and `even_deny_root`
(off, so root is not locked by default). The manual also warns that permanent locking turns known
user names into a denial-of-service target. The tool `faillock --user <name>` shows a tally and
`--reset` clears it:

```yaml
- name: What has pam_faillock counted so far?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Read the tally of root
      ansible.builtin.command: faillock --user root
      register: tally
      changed_when: false
      check_mode: false
    - name: List the tally files
      ansible.builtin.find:
        paths: /var/run/faillock
        file_type: file
      register: tally_files
      check_mode: false
    - name: Show the result
      ansible.builtin.debug:
        msg:
          faillock: "{{ tally.stdout_lines }}"
          tally_files: "{{ tally_files.files | map(attribute='path') | list }}"
```

On the Ubuntu host the output is the header (`When Type Source Valid`) and nothing counted.
"Read" has a side effect: `faillock --user root` creates an empty tally file for that account
(a name that does not exist creates nothing; tested) - harmless, but not a pure read. The module
and the tool are installed on all eight hosts, alpine included, but before any exercise a stack
references the module only on arch (`system-auth`).

**Lock-out analysis** belongs before any change that can reject logins. The question is not
"which logins count as failed" but "which of *my* logins pass through the PAM types the module
sits in". That depends on how the service uses PAM: read the service's stack, read what the
service's own configuration says about PAM (`UsePAM yes` on the seven systemd hosts; on alpine I
found no `UsePAM` line in `sshd_config` and did not verify what its `sshd` does without one), and
test with a spare account while a second session is open.

### Login shells: where umask and TMOUT live

Two shell settings appear in hardening guides: the `umask` (which permission bits new files
*lose*; a umask of 022 turns the default file mode 666 into 644) and `TMOUT` (an idle interactive
`bash` exits after that many seconds). They are shell built-ins and variables, not kernel or PAM
settings, so they apply where a shell sets them up. The conventional place is a script in
`/etc/profile.d`, sourced by `/etc/profile` for **login shells**. On Ubuntu `/etc/profile` loops
over `/etc/profile.d/*.sh`, so the name must end in `.sh`; on all eight hosts `/etc/profile`
mentions `profile.d` (`grep -c`; I did not read how each loop selects files).

For Ansible this means: a task runs in a shell nobody logged into, so what a profile script sets
is **not there**. A hardening play can be correct and every task that checks the environment
through `command` or `shell` still shows the old value. Ask a login shell on purpose:

```yaml
- name: Does a login shell see something that Ansible does not?
  hosts: targets
  gather_facts: false
  tasks:
    - name: Ask a login shell
      ansible.builtin.command: bash -lc 'echo "umask=$(umask) TMOUT=${TMOUT-unset}"'
      register: login_shell
      changed_when: false
      check_mode: false
    - name: Ask the shell Ansible uses for its own commands
      ansible.builtin.shell: echo "umask=$(umask) TMOUT=${TMOUT-unset}"
      register: plain_shell
      changed_when: false
      check_mode: false
    - name: Compare
      ansible.builtin.debug:
        msg:
          login_shell: "{{ login_shell.stdout }}"
          ansible_shell: "{{ plain_shell.stdout }}"
```

On the Ubuntu host both lines read `umask=0022 TMOUT=unset`: nothing sets the values there. Run
the play again after 3.05: the first line changes. Do not rely on the second staying as it was: on
rocky, alma and fedora, commands that Ansible ran with `become` showed `umask=0027` after 3.05 as
well (the EXPLANATION of 3.05 has the measurement).

`readonly` is what stops a user from switching the timeout off. A read-only variable refuses
assignment and `unset`:

```bash
bash -c 'readonly TMOUT=900; (TMOUT=1); echo "assign rc=$?"; unset TMOUT; echo "unset rc=$?"; echo "TMOUT=$TMOUT"'
```

Bash prints `TMOUT: readonly variable` and `cannot unset: readonly variable`, both return codes
are 1 and the value stays 900. Two limits: these settings reach only shells that read the
profile, and an idle timeout in a shell does nothing against a connection that is simply left
open - that is a job for the SSH daemon's own settings.

## CIS background

The five sections of [the control catalogue](../../cis/controls.yml) behind this lesson are all
Level 1:

- **5.4.1** (shadow password suite): how long a password lives, the hash that protects it, when
  an unused account locks itself - it shrinks the window in which a stolen hash or an abandoned
  account is useful.
- **5.4.2 and 5.4.3** (root, system accounts, environment): exactly one UID 0, no account with an
  empty password, safe shell defaults. The first two are *audits first*: find out what is there,
  then change it.
- **5.3.2 and 5.3.3** (PAM): lock accounts after repeated failures and enforce a password policy
  that includes root. Both change the PAM stack, where a wrong step ends in a lock-out.

Benchmarks number these differently (L01); the catalogue ids are the lab's own. The catalogue
marks all five `container: full`: the PAM stacks, `shadow` tools and shells in the lab are the
real ones.

The trade-offs are operational. Locking accounts is itself an attack - whoever knows a user name
can lock it - which is why root is exempt by default, why `unlock_time` is a decision and why
service accounts need thought. A policy that is too strict gets passwords written on notes.
Neither argument removes the control; they decide the numbers and the exceptions, and an
exception is documented, not omitted (L01).

## Platform differences

| os_family | Hosts | PAM generator | `login.defs` | `ENCRYPT_METHOD` | `pam_unix` password line | `pam_pwquality` | `pam_faillock` module / in a stack |
|---|---|---|---|---|---|---|---|
| Debian | debian (13), ubuntu (26.04) | `pam-auth-update` | `/etc/login.defs` | YESCRYPT | names `yescrypt` | not installed | present / not in a stack |
| RedHat | rocky (10.2), alma (10.2), fedora (44) | `authselect` | `/etc/login.defs` | YESCRYPT | names `yescrypt`, `nullok` | installed, in `system-auth` and `password-auth` | present / not in a stack |
| Suse | opensuse (Leap 16.0) | `pam-config` | `/usr/etc/login.defs`; none in `/etc`, but `/etc/login.defs.d` exists | SHA512 | names no algorithm, `nullok` | not installed | present / not in a stack |
| Alpine | alpine (3.24) | none found | `/etc/login.defs`, no `ENCRYPT_METHOD` line | - | no such line found in `/etc/pam.d` | not installed | present / not in a stack |
| Archlinux | arch | none found | `/etc/login.defs` | YESCRYPT | names no algorithm, `nullok` | not installed | present / in `system-auth` |

All values were measured on the lab's targets (`grep`, `command -v`, `find`). `chage --help`
lists `--mindays` on every host except arch. Alpine has `/etc/pam.d` and ships the PAM
`faillock` module, so "Alpine has no PAM" is too strong; which of its services actually use PAM
I did not check, and neither whether its `/etc/login.defs` has any `PASS_*` line.

### In the lab containers

- PAM, the `shadow` tools and the shells are real; the account and PAM exercises behave as on a
  VM (see [the container limits](../CONTAINER_LIMITS.md)). The lab cannot show a console login,
  so test a lock with `su` or `ssh` from another terminal.
- The tally directory is inside the container: `./lab.sh reset <host>` returns it to its start
  state together with every demo account and file.
- The examples assume 0.02 is done (alpine needs Python). `chage` and `faillock` exist on all
  eight hosts; the first and the last example also need `getent` and `bash` - if one of them is
  missing on alpine, that tool is the reason for a failure, not your play.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| New accounts have the new aging values, old ones do not | `login.defs` is copied when an account is created | change existing accounts with `chage` or the `user` module |
| You changed `ENCRYPT_METHOD` and new passwords still use another hash | the `pam_unix` line of the `password` stack names an algorithm itself; `login.defs` is only the default | look at both places |
| A task that sets the minimum password age fails on arch | `shadow` 4.20 removed the feature | detect the capability, never test the distro name |
| A new `/etc/login.defs` appears and the vendor values are gone | a vendor-split host reads its defaults from `/usr/etc` | check where the program looks before creating the file |
| Your edit of `/etc/pam.d/common-password` disappears | `pam-auth-update` (or `authselect`, `pam-config`) regenerates it | change the profile or feature, not the generated file |
| Root sets a weak password and nothing stops it | `enforce_for_root` is off by default | set it in the drop-in |
| A drop-in in `pwquality.conf.d` does not take effect | a later file sets the same option | the last file in ASCII order wins |
| An account locks after a few test logins | the tally counts every failure within `fail_interval` | `faillock --user <name> --reset`; test with a spare account |
| `getent passwd` shows accounts that are not in `/etc/passwd` | NSS adds directory services | decide which question the audit asks and read the matching source |
| `TMOUT` is set but `command: echo $TMOUT` shows nothing | tasks do not run in a login shell | check with `bash -lc` or read the file |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [3.02](../../exercises/stage3-intermediate/3.02-password-aging/README.md) | what the aging fields and `login.defs` defaults reach, how hashes are named, where defaults live on a vendor-split host |
| [3.03](../../exercises/stage3-intermediate/3.03-password-quality/README.md) | the `password` type, drop-in order, what `pam_pwquality` checks, who writes each family's stack |
| [3.05](../../exercises/stage3-intermediate/3.05-accounts-and-environment/README.md) | what the password field and the UID mean, NSS versus files, login shells and `readonly` |
| [4.06](../../exercises/stage4-advanced/4.06-faillock-authselect/README.md) | the `auth` and `account` types, controls, tally and `faillock.conf`, lock-out analysis |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. Why does an audit for "who is root" look at the third field of `passwd`, and when does
   `getent passwd` give a different list than the file?

   <details><summary>Answer</summary>

   The kernel decides on the UID, so any account with UID 0 has root's privileges whatever its
   name. `getent` asks NSS, which includes directory services configured on the host (LDAP,
   SSSD, ...); the file lists local accounts only. For a local audit read the file, for "who
   can log in here" ask `getent`.

   </details>

2. You change `PASS_MAX_DAYS` in `login.defs` to 365. What happens to an account that exists
   already, and what to one you create afterwards? How do you check?

   <details><summary>Answer</summary>

   The existing account keeps its value: the default is copied into the account when it is
   created. A new account gets 365. `chage -l <user>` prints the account's own values; compare
   them with the file.

   </details>

3. A hardening play writes `ENCRYPT_METHOD SHA512` into `login.defs` on every host without
   looking at the host first. What can go wrong, and how do you recognise the algorithm of
   existing hashes?

   <details><summary>Answer</summary>

   A host that already uses a stronger method gets a weaker default for new passwords, and a
   scanner that accepts both values will not complain. Existing hashes show their algorithm by
   the prefix: `$6$` SHA-512, `$y$` yescrypt, `$5$` SHA-256, `$1$` MD5. Also check whether the
   `pam_unix` line names an algorithm itself.

   </details>

4. A stack has two `required` modules for `auth` and the first fails. Does the second run? What
   changes if the first is `requisite`? Why is a hand-edited line in a generated PAM file a
   bad idea?

   <details><summary>Answer</summary>

   With `required` the second module still runs and the stack fails at the end; with `requisite`
   the stack returns at once. A generated file (`pam-auth-update`, `authselect`, `pam-config`) is
   rewritten the next time the tool runs, so the edit is lost: add a profile or feature the
   generator knows and let it regenerate.

   </details>

5. Two drop-ins define `minlen`: `10-vendor.conf` says 8, `50-site.conf` says 14. Which value
   applies, and what happens when root sets a 10-character password while `enforce_for_root`
   is not set?

   <details><summary>Answer</summary>

   14 applies: the files are read in ASCII order and the later value wins. Without
   `enforce_for_root` root gets a message about the failed check, but the change goes through.

   </details>

6. `unlock_time` is `0` and `deploy` is locked after failures. When is it usable again, and why
   is permanent locking risky? A play sets `TMOUT` in a profile script and checks it with
   `command: echo "$TMOUT"` - why does the check fail?

   <details><summary>Answer</summary>

   Only after somebody clears the tally (`faillock --user deploy --reset`), or after a reboot
   if the tally directory is cleared on boot. Anyone who knows the user name can lock the account
   by failing logins - a denial of service. The check fails because the `command` module does
   not run in a login shell, so the profile script is never read; ask a login shell on purpose
   (`bash -lc 'echo $TMOUT'`) or check the file.

   </details>

## Further reading

- [`ansible.builtin.getent`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/getent_module.html), [`ansible.builtin.user`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html) and [`ansible.builtin.find`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/find_module.html) - the modules used in the examples
- [`shadow(5)`](https://man.archlinux.org/man/shadow.5) and [`login.defs(5)`](https://man.archlinux.org/man/login.defs.5) - the fields and the defaults
- [`chage(1)`](https://man.archlinux.org/man/chage.1) and [`useradd(8)`](https://man.archlinux.org/man/useradd.8) - per-account and default values
- [`pam.conf(5)`](https://man.archlinux.org/man/pam.conf.5) and [`pam_unix(8)`](https://man.archlinux.org/man/pam_unix.8) - rule syntax, controls, hash options
- [`pwquality.conf(5)`](https://man.archlinux.org/man/pwquality.conf.5) and [`pam_pwquality(8)`](https://man.archlinux.org/man/pam_pwquality.8) - password quality settings
- [`faillock.conf(5)`](https://man.archlinux.org/man/faillock.conf.5), [`pam_faillock(8)`](https://man.archlinux.org/man/pam_faillock.8) and [`faillock(8)`](https://man.archlinux.org/man/faillock.8) - the lock module and its tool
- [Glossary](../GLOSSARY.md) - terms of this lesson: authselect, faillock, `login.defs`, PAM,
  pwquality, shadow, `TMOUT`, `umask`
