# 3.04 - auditd: rules and log retention (Level 2)

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 3 - Intermediate | ★★★☆☆ | ~50 min | 6.3 Configure auditd (L2) | `targets` |

**Concepts:** `dict of lists → files`, `template loop`, `lineinfile on key=value`, `host-global kernel features`

## Goal

Install auditd, deploy the CIS audit rules as separate rule files and configure log retention - without loading anything into the shared kernel.

## Background

**Level 2.** In current CIS benchmarks the auditd section belongs to the Level 2
profile (more protection, more operational cost: disk, CPU, alert handling). It is in
this lab because it is one of the most valuable controls for incident response - and
because it teaches a very important lesson about containers.

The kernel audit subsystem is **not namespaced**. Loading rules (`augenrules --load`,
`auditctl`) or starting `auditd` in a privileged container affects your *host* and
all other containers. So in this lab you only *configure*; the service stays off
(guard: `lab_in_container`). On a VM or bare metal the same role would also enable
and start the service.

Rules (one file per topic in `/etc/audit/rules.d/50-cis-<topic>.rules`):
scope (sudoers), user_emulation (sudo/su as other user), sudo_log, time_change,
identity (account files, PAM, nsswitch), logins - plus `99-cis-finalize.rules` with
`-e 2` (rules become immutable until reboot).

## Requirements

- [ ] Package per family: Debian `auditd`, all others `audit`.
- [ ] The rules come from **one** dict variable (topic → list of rule lines); one templated task with a loop writes `50-cis-<topic>.rules` (`root:root`, `0640`). Copy the rule list from `lab solution 3.04` if you do not want to type it - the exercise is about the structure.
- [ ] `99-cis-finalize.rules` contains exactly `-e 2`.
- [ ] `/etc/audit/auditd.conf`: `max_log_file_action = keep_logs`, `space_left_action = email`, `action_mail_acct = root`, `admin_space_left_action = single`.
- [ ] The service is enabled/started **only** when `not lab_in_container`.
- [ ] Second run: `changed=0`. Add to your role as `section6_logging.yml` (tag `auditd`), gated by `cis_level >= 2`.

## How to work

```bash
lab start 3.04            # creates /lab/work/3.04/
cd /lab/work/3.04
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 3.04            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 3.04 1` (gentle) ... `lab hint 3.04 3` (almost the answer).  
Passed? Read `lab explain 3.04` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- `augenrules --check` compares rules.d with the loaded rules. Why is it pointless here?
- Add the `perm_mod` rules (chmod/chown/setxattr family with `-F auid>=1000`). Why `auid` and not `uid`?
- On aarch64 hosts (Apple Silicon), is `-F arch=b64` still correct? What about `b32`?
