# 3.04 - auditd: rules and log retention (Level 2): Explanation

### What the check verifies
`lab check 3.04` runs `check.yml` on all eight hosts and then your playbook once more with
`--check`, expecting `changed=0` (`meta.yml` says `idempotency: true`). `check.yml` joins all
`50-cis-*.rules` files, reads `99-cis-finalize.rules` and `auditd.conf`, and asserts:
- the keys `scope`, `user_emulation`, `sudo_log_file`, `time-change` and `logins` appear in the
  rules, plus the exact text `/etc/shadow -p wa -k identity`;
- the finalize file has a line `-e 2`;
- `max_log_file_action = keep_logs`, `space_left_action = email` and `admin_space_left_action`
  `single` or `halt`.

It does not test the rest of the README. Mutations of the reference solution that the check
accepted (measured on a Debian-family host): all rules in one `50-cis-all.rules` instead of a file
per topic, mode `0644`, a second line next to `-e 2`, no `action_mail_acct`, `halt` instead of
`single`, a line `this is not an audit rule` inside a rule file, and the service guard removed (the
check never reads the service state). A template that writes a literal `\n`, so that all rules of
a topic sit on one line, passes as well. The check is stricter than auditd in one place: its
regular expressions are case-sensitive, `KEEP_LOGS` fails although `auditd.conf(5)` says names and
values are case insensitive. And it needs the file name `99-cis-finalize.rules`: renaming the file
fails the check. Those parts of the contract are yours to get right.

### How it works

#### Data-driven rule files
One dict, one template, one loop. Adding a topic = adding a key. The file name comes from the
dict key (`time_change`), the `-k` key from the rule line (`time-change`) - they need not match.
In the template, put every rule on a line of its own: the template module removes the lines that
only hold a block tag, but a literal `\n` is no line break (measured: the file had no line break at
all, and `augenrules` merged all rules of the topic into one invalid line).

Removing a topic from the dict does not remove its file (measured: the next run says
`changed=0`, and `augenrules` still merges the old rules). That needs a cleanup task (`find` +
`file: state=absent` for `50-cis-*.rules` not in the dict) - a nice extension.

#### What the rules capture
| Key | Question it answers in an incident |
|---|---|
| `scope`, `sudo_log_file` | who changed sudo rights / tampered with the sudo log? |
| `user_emulation` | who ran commands as *another* user? |
| `time-change` | did someone move the clock to confuse log correlation? |
| `identity` | who created/modified accounts, PAM or name resolution? |
| `logins` | failed/successful login records touched? |

`-k` sets the key you later search for: `ausearch -k identity`. The reference solution writes
`arch=b64` rules only; a machine that runs 32-bit programs needs a `b32` twin (L09).

#### The merge and `-e 2`
`augenrules` merges `rules.d/*.rules` in natural order (`ls -v`) into `/etc/audit/audit.rules`,
and `augenrules(8)` says the last `-e` is always emitted as the last line. Measured with audit
3.1.2: with the finalize file named `05-cis-finalize.rules` the generated file was identical, `-e 2`
still last. So the `99-` prefix is a convention for the reader, not a requirement of auditd; the
check only insists on the name.

`-e 2` makes the rule set immutable until reboot - an attacker with root cannot simply
`auditctl -D`. Measured on a VM with audit 3.1.2, after the reference rules (16 rules, all
accepted by the kernel) had been loaded with `-e 2`: `auditctl -w ...` answered `The audit system
is in immutable mode, no rule changes allowed`, `auditctl -D` answered `Error deleting rule
(Operation not permitted)`. Test the rules unlocked and lock only the final set.

`augenrules --check` compares the merged files with `/etc/audit/audit.rules`, not with the loaded
rules, prints `No change` or `Rules have changed and should be updated`, and exits with 0 either
way (audit 3.1.2). After this exercise it reports a change in the lab, because nothing generates or
loads the rules there.

#### auditd.conf choices
- `keep_logs` - rotate without deleting (disk planning becomes your job!).
- `space_left_action = email` → early warning; `admin_space_left_action = single` → stop the
  system rather than run unaudited. That is a business decision; L2 means "you accept that
  trade-off". These three values are the ones the NOTES section of `auditd.conf(5)` recommends.
  `email` needs `/usr/lib/sendmail` (manual). The shipped values on all eight hosts are `rotate`,
  `syslog` and `suspend`, so all three change (L09).
- `action_mail_acct = root` is already the shipped value on Ubuntu 24.04: that task reports `ok`.
  The shipped file has all four keys there, so `lineinfile` replaces the line; Ubuntu writes the
  values in upper case (`ROTATE`).
- The daemon reads `auditd.conf` at start; `SIGHUP` makes it re-read the file (`auditd(8)`). The
  reference solution has no handler, because the lab never starts the daemon - on a real host you
  need one, and the rules only count once they are loaded (L09).

#### The container lesson
Kernel features fall into two groups: namespaced (network, mounts, PIDs, some sysctls) and global
(audit, modules, most `kernel.*`). Containers isolate the first group only. Hardening code needs a
switch for environments where it must not touch the second group - that is what `lab_in_container`
models. Inside the lab targets even `auditctl -s` fails on all eight hosts (L09).

### Per-family notes
| `os_family` | Hosts | Package (audit version) | Shipped in `rules.d` | After the install |
|---|---|---|---|---|
| Debian | debian, ubuntu | `auditd` (4.0.2, 4.1.2) | `-D`, `-b 8192`, `--backlog_wait_time 60000`, `-f 1` | `auditd.service` and `audit-rules.service` enabled |
| RedHat | rocky, alma, fedora | `audit` (4.0.3, 4.0.3, 4.2.1) | rocky, alma: as Debian; fedora: `-D`, `-a task,never` | both enabled; `auditd` `activating` on rocky, `failed` on alma and fedora |
| Suse | opensuse | `audit` (4.0) | `-D`, `-a task,never` | both enabled, `auditd` inactive; it runs `augenrules --load` after the start |
| Alpine | alpine | `audit` (4.1.2) | none | OpenRC script `/etc/init.d/auditd`, stopped |
| Archlinux | arch | `audit` (4.2.1) | none | both units present, disabled |

All values are the measurements of lesson L09 on the lab's targets (Debian family with the service
start suppressed). `auditd.conf` has the same defaults on all eight hosts.

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `No package matching 'auditd' is available` on Debian/Ubuntu | the image ships an empty index and `cache_valid_time` judges its directory fresh | `update_cache: true` without `cache_valid_time`, or look for `*_Packages*` first like the solution |
| All rules of a topic on one line, check green | literal `\n` in the template | real line breaks, one rule per line |
| `The audit system is in immutable mode` | `-e 2` was loaded | reboot; test unlocked |
| The check fails with `KEEP_LOGS` | its regular expressions are case-sensitive | lower case, as in the README |
| A removed topic is still audited | its file is still in `rules.d` | cleanup task |
| `augenrules --check` is "successful" | its exit code is 0 either way | read its text |

### Real-world notes
- Roll rules out in two steps: write the files, then load them (`augenrules --load`, in a handler
  or by restarting the service). Only the final set carries `-e 2`.
- Size the disk first: `keep_logs` loses nothing by itself and so makes the disk fill, and
  `single` then stops the machine. Many sites forward the log to a central host as well.

### Further reading
- Lesson [L09 - Auditing and integrity](../../../docs/lessons/L09-auditing-and-integrity.md): the audit subsystem, rule kinds, `rules.d` and `-e 2`, `auditd.conf` actions - the concepts before this exercise.
- Exercise [4.08 - File integrity with AIDE](../../stage4-advanced/4.08-aide-async/README.md): the second half of the lesson.

## Reference solution

Show it with `lab solution 3.04`, apply it with `lab solve 3.04`.
