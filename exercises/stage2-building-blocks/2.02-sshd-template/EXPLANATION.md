# 2.02 - SSH server hardening with a Jinja2 template: Explanation

### What the check verifies
`lab check 2.02` runs `check.yml` on `targets`: it reads the **effective** configuration with
`sshd -T`, reads `/etc/ssh/sshd_config.d/00-cis-hardening.conf` and asserts the README values -
some as a bound (`MaxAuthTries` at most 4, `LoginGraceTime` 1-60, `ClientAliveInterval` 1-15,
`ClientAliveCountMax` 1-3), `MaxStartups` exactly `10:30:60`, plus `PermitRootLogin`,
`PermitEmptyPasswords` and `X11Forwarding` set to `no`. Then it runs your playbook once more with
`--check` and expects `changed=0`.

- The file must contain the word "ansible" (any case). `AllowGroups ansible` already satisfies
  that, so the `ansible_managed` line itself is not tested.
- `LogLevel INFO` passes too, and it is the default on all eight hosts.
- `AllowGroups` only has to be non-empty; any group passes.
- Algorithms are tested against a list of weak patterns. Measured on all eight hosts: the default
  `Ciphers` and `KexAlgorithms` already pass, the default `MACs` fail (they contain `hmac-sha1`).
- Mode and owner of the drop-in, `validate`, the handler and the full `sshd -t` task are not
  tested. In the `--check` run that task is skipped (`Command would have run if not in check
  mode`).

### How it works

#### Variables, template, `join`
Every value is a variable, lists are joined in the template: `,` for `Ciphers`, `MACs` and
`KexAlgorithms`, a space for `AllowGroups` - the separators `sshd_config` expects.
`{{ ansible_managed | comment }}` renders three lines (`#`, `# Ansible managed`, `#`). The
output is deterministic: the reference solution reports `changed=2` per host in the first run
(template + handler) and `changed=0` in the second.

#### The first value wins, so name every checked key
The lab puts `Include /etc/ssh/sshd_config.d/*.conf` at the top of the main file, and `sshd` keeps
the first value it reads. Your `00-` file comes first. A key it does **not** set is taken from the
next file that does: `10-lab-legacy.conf` sets `PermitRootLogin yes`, `PermitEmptyPasswords yes`,
`X11Forwarding yes` and `MaxAuthTries 10`, and on the Red Hat hosts `50-redhat.conf` sets
`X11Forwarding yes` as well. Measured with a local `sshd`: a drop-in with only the values of the
README table leaves `permitrootlogin yes` in `sshd -T`. The file name is the one of 1.03, so the
template replaces that file and must carry its two lines.

`DisableForwarding yes` blocks every kind of forwarding at runtime, but `sshd -T` still prints the
single keys from wherever they come from: after the solution `allowtcpforwarding` is `yes` on seven
hosts and `no` on alpine (Alpine's default). That is why the check asserts
`X11Forwarding no` separately.

#### Two validation layers
`validate: /usr/sbin/sshd -t -f %s` tests the rendered fragment **alone**, before it replaces the
file. It catches a typo (`Bad configuration option: MaxAuthTry`, rc 255) or an algorithm the
local OpenSSH does not know; the old file then stays in place. It cannot see the other files.
Measured with OpenSSH 9.6: the fragment passes, the full test fails, when

- it sets `AuthenticationMethods publickey,password` and another file sets
  `PasswordAuthentication no` (`AuthenticationMethods cannot be satisfied by enabled
  authentication methods`), or
- any other drop-in contains an invalid line.

Hence the second layer, `sshd -t` without `-f`, after the template task. Handlers run at the end
of the play, so when the full test fails the host stops before the reload and the running daemon
keeps its old configuration. The new file, however, **is already on disk**: a restart or reboot
before you fix it starts no `sshd`. Fix and re-run at once, or keep a copy (`backup: true`) and
restore it in a `rescue` block (lesson L02).

#### Algorithms and OpenSSH versions
`mlkem768x25519-sha256` exists since OpenSSH 9.9; 9.6 rejects the fragment with `Unsupported KEX
algorithm`. The lab's oldest sshd is 9.9 (rocky, alma), so the list works on all eight hosts.

#### crypto-policies (bonus 3)
On rocky, alma and fedora the system crypto policy reaches `sshd` through the drop-in
`40-redhat-crypto-policies.conf` (before the exercise their lists differ from the other hosts',
e.g. no `aes192-ctr`). Your `00-` file is read before it, so your lists win: after the
solution the three hosts show exactly the template's lists. `50-redhat.conf` holds other
defaults, no algorithms. rocky and alma report the policy `DEFAULT`; the lab's fedora image has no
`update-crypto-policies`. A custom policy module (not tested in the lab) sets algorithms
system-wide.

#### Lock-out analysis (bonus 1)
- `AllowGroups ansible`: the lab account's only group is its primary group `ansible` (measured on
  all eight hosts), and `AllowGroups` counts the primary group. In production the list must hold
  your admin group *and* the automation account's group.
- `PermitRootLogin no`: Ansible logs in as `ansible` and uses sudo.
- `ClientAliveInterval 15`, `ClientAliveCountMax 3`: a client that stops answering is dropped after
  about 45 seconds; an idle client that answers stays. Ansible's persistent connections answer.
- A reload keeps open sessions (measured in 1.03), so a mistake is noticed only at the next login.

### Per-family notes
| os_family | OpenSSH | Unit | Drop-ins besides `10-lab-legacy.conf` |
|---|---|---|---|
| Debian | debian 10.0p2, ubuntu 10.2p1 | `ssh` | none |
| RedHat | rocky and alma 9.9p1, fedora 10.2p1 | `sshd` | `40-redhat-crypto-policies.conf`, `50-redhat.conf`; alma also `25-permitrootlogin.conf` |
| Suse | 10.0p2 | `sshd` | none |
| Alpine | 10.3p1 | `sshd` (OpenRC) | none |
| Archlinux | 10.6p1 | `sshd` | `20-systemd-userdb.conf`, `99-archlinux.conf` |

`/usr/sbin/sshd` is a link to `/usr/bin/sshd` on arch and fedora, so the same path works on all
eight hosts. Arch's `sshd -T` prints the keys in mixed case (`PermitRootLogin`); the check
lower-cases them.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `sshd -T` shows `permitrootlogin yes` after your run | the template does not set it, the legacy file does | set every key the check asserts |
| `x11forwarding yes` despite `DisableForwarding yes` | `sshd -T` prints each key on its own | `X11Forwarding no` as well |
| `Bad configuration option: ...`, rc 255, in `validate` | typo in the template | fix it; the old file stays |
| `Unsupported KEX algorithm` | OpenSSH older than the algorithm | per-host list, or leave it out |
| Play stops at the full `sshd -t` | another file, or a combination of files | fix now - the new file is on disk |
| `Permission denied` for an admin after the run | not in a group of `AllowGroups` | add the group; test a second login before closing the first |

### Real-world notes
- Keep one session open and test a **new** login before you close it.
- `sshd -T -C user=<name>,host=<host>,addr=<ip>` shows the values a `Match` block would give that
  connection.
- Exceptions belong in variables at a narrower layer (`group_vars`, `host_vars`), not in a copy
  of the template (lesson L04).

### Further reading
- Lesson [L02 - Safe changes](../../../docs/lessons/L02-safe-changes.md): `validate`, handlers, `backup` and `rescue`.
- Lesson [L03 - Base hardening](../../../docs/lessons/L03-base-hardening.md): several sshd files, one effective value.
- Lesson [L04 - Platform differences as data](../../../docs/lessons/L04-platform-differences-as-data.md): templates, `join`, `ansible_managed`.
- Exercise [1.03 - SSH: forbid root login and empty passwords](../../stage1-beginner/1.03-ssh-root-login/README.md)
- Exercise [2.06 - All login banners from one template](../2.06-banners-template-loop/README.md)
- [`sshd_config(5)`](https://man.openbsd.org/sshd_config) - `Include`, `Match`, `DisableForwarding`, the algorithm keywords

## Reference solution

Show it with `lab solution 2.02`, apply it with `lab solve 2.02`.
