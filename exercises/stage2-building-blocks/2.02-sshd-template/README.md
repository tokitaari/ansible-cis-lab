# 2.02 - SSH server hardening with a Jinja2 template

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 2 - Building blocks | ★★★☆☆ | ~45 min | 5.1 SSH server (L1) | `targets` |

**Concepts:** `template`, `variables`, `join filter`, `ansible_managed`, `full-config validation`

## Goal

Replace the hand-written drop-in from 1.03 with a template that implements the whole CIS SSH section from variables.

## Background

CIS 5.1 has around twenty SSH recommendations. Hard-coding them works once;
a template driven by variables lets different environments (or exceptions) reuse
the same code. The target values used in this lab:

| Setting | Value | Why |
|---|---|---|
| `LogLevel` | `VERBOSE` | logs key fingerprints on login |
| `MaxAuthTries` | `4` | limits brute force per connection |
| `MaxSessions` / `MaxStartups` | `10` / `10:30:60` | limits resource exhaustion |
| `LoginGraceTime` | `60` | unauthenticated connections are dropped |
| `ClientAliveInterval` / `CountMax` | `15` / `3` | idle sessions die after ~45 s of no response |
| `DisableForwarding` | `yes` | no TCP/agent/X11 forwarding |
| `IgnoreRhosts` / `HostbasedAuthentication` | `yes` / `no` | no trust relationships |
| `PermitUserEnvironment` | `no` | users cannot inject `LD_PRELOAD` etc. |
| `Banner` | `/etc/issue.net` | the banner from 0.04 |
| `AllowGroups` | `ansible` | explicit allow-list |
| `Ciphers`/`MACs`/`KexAlgorithms` | modern only | no CBC, no SHA-1, no MD5 |

## Requirements

- [ ] Template `templates/sshd_cis.conf.j2` rendered to `/etc/ssh/sshd_config.d/00-cis-hardening.conf` (`root:root`, `0600`).
- [ ] All values come from variables (see table); lists are joined in the template.
- [ ] The first line is the `ansible_managed` comment.
- [ ] Validate the rendered fragment with `sshd -t -f %s` and reload sshd via handler.
- [ ] **After** deploying, verify the *complete* configuration with `sshd -t` (no `-f`) and fail the play if it is broken.
- [ ] `sshd -T` shows all values on all hosts; Ansible can still connect (careful with `AllowGroups`!).

## How to work

```bash
lab start 2.02            # creates /lab/work/2.02/
cd /lab/work/2.02
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 2.02            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 2.02 1` (gentle) ... `lab hint 2.02 3` (almost the answer).  
Passed? Read `lab explain 2.02` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Before running: which of these settings could lock *you* out? Why is the lab user safe?
- Use `--diff` to see how the template differs from the 1.03 file.
- Red Hat systems also have *crypto-policies*. Why do your `Ciphers` still win? (Hint: `cat /etc/ssh/sshd_config.d/50-redhat.conf`)
