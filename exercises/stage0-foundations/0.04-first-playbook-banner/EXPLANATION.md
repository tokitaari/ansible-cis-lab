# 0.04 - First hardening playbook: SSH warning banner: Explanation

### What the check verifies
`lab check 0.04` runs `check.yml` on all eight targets (with `become`, minimal facts). For
`/etc/issue.net` it asserts:
- the text matches `authorized` or `authorised`, any case;
- it contains none of `\m`, `\r`, `\s`, `\v` (regex `\\[mrsv]`);
- it does not contain the host's `distribution` fact, any case;
- owner `root`, group `root`, mode `0644` (read with `stat`).

Then it runs your playbook once more with `--check` and expects `changed=0` (`meta.yml` says
`idempotency: true`). Here that is a real test: `copy` supports check mode.

It does not test, measured by running the real `check.yml` against each text on one host: other
escapes such as `\S`, `\l` or `\n`; a version number without the distribution name; the name of
a *different* distribution; and a text like "Unauthorized use is prohibited." passes because
"unauthorized" contains "authorized". Only `/etc/issue.net` is checked - `/etc/issue` and
`/etc/motd` come in 2.06.

One gap shows on arch. The shipped text is "Welcome to Arch Linux", the `distribution` fact is
`Archlinux` - the check would not notice the name (measured with the check's own expression on
all eight shipped texts: only arch is missed). The shipped text fails anyway because of `\r \m`,
but a banner that only drops the escapes passes on arch and still names the distribution.

### How it works

#### `copy` and idempotency
`copy` compares checksum, owner, group and mode with the desired state and acts only on
differences. The reference solution shows `changed=1` on all eight hosts the first time and
`changed=0` the second time (measured). `--check --diff` shows what would change without
changing it, here on fedora:

```
--- before: /etc/issue.net
+++ after: /etc/issue.net
@@ -1 +1 @@
-Welcome to Fedora Linux 44 (Container Image) \r \m
+Authorized access only. Activity on this system is monitored and logged.
```
Every task you write from now on must behave like this.

#### Quote the mode
`mode: 644` is the YAML integer 644; Ansible reads it as decimal and writes octal 1204 - the file
gets `--w----r-T` (measured). `mode: 0644` works because YAML 1.1 reads a leading zero as octal,
but it is fragile, and `ansible-lint` reports it as `yaml[octal-values]` (the lab's gate lints the
solutions with the `production` profile). Write `mode: "0644"`.

#### Symbolic links on fedora
On fedora `/etc/issue.net` is a symbolic link (`-> ../usr/lib/issue.net`, 20 bytes), and so is
`/etc/issue`. `stat` in the check sees the link itself, mode `0777`: on a fresh fedora the check
fails with `now: root:root 0777`. `copy` replaces the link with a regular file and leaves the
vendor file untouched (measured on a symlink layout; on the lab, after the run fedora's
`/etc/issue.net` is a regular file of 73 bytes while `/etc/issue` is still a link). A package
update can no longer overwrite your banner through the link.

#### Who reads which file
`/etc/issue` is printed by the console getty before the login prompt, and the getty expands
escapes in it (`\r` kernel release, `\m` architecture; see `issue(5)`). sshd sends the file
named by `Banner` as it is: with a local sshd, a file containing `Welcome to Testdistro 1.0 \r \m`
arrived with `\r \m` literally (measured). So over SSH the leak is the distribution name, on
the console also kernel and architecture. CIS treats all banner files alike.

sshd shows `/etc/issue.net` only when `Banner /etc/issue.net` is configured. That is the sshd
hardening of 2.02; 2.06 records that the hosts start without a banner.

#### Where it sits in the catalogue
Control 1.6 in `cis/controls.yml` ("Login banners contain a legal warning and no OS
information", Level 1) lists the exercises 0.04, 2.06, 3.01 and 5.01. This one covers
`/etc/issue.net`; 2.06 covers all three files.

### Per-family notes
All eight targets start with a text of the form "Welcome to <distribution> <version> \r \m"
(measured 2026-11-07); after the solution every `/etc/issue.net` is a regular file of 73 bytes.

| `os_family` | Hosts | `/etc/issue.net` at the start |
|---|---|---|
| Debian | debian, ubuntu | regular file: 46 bytes (Debian GNU/Linux 13 (trixie)), 36 bytes (Ubuntu 26.04.1 LTS) |
| RedHat | rocky, alma, fedora | rocky 47 and alma 48 bytes (with the release name in brackets); fedora: symbolic link, 20 bytes |
| Suse | opensuse | regular file, 36 bytes (openSUSE Leap 16.0) |
| Archlinux | arch | regular file, 28 bytes ("Arch Linux", see the gap above) |
| Alpine | alpine | regular file, 36 bytes (Alpine Linux v3.24) |

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| The file gets mode `1204` (`--w----r-T`) | `mode: 644` is a YAML integer | `mode: "0644"` |
| On fedora the check says `now: root:root 0777` | `/etc/issue.net` is a symbolic link | run the playbook, `copy` replaces the link |
| The check passes on arch but the banner says "Arch Linux" | it looks for `Archlinux` | no distribution name in the text at all |
| The check passes with `\S`, `\l` or `\n` in the text | it only looks for `\m \r \s \v` | no escapes at all in your text |
| Nobody ever sees the banner over SSH | `Banner` is not set in sshd | 2.02 (and 2.06) |

### Real-world notes
Banner text is often a legal requirement (works council, legal department). Keep it in a variable
so it can be changed centrally - you do that in 2.06. The text shown before authentication (sshd's
`Banner`) is the one that warns an intruder; the message of the day comes after the login.

### Further reading
- Lesson [L00 - Lab architecture and Ansible basics](../../../docs/lessons/L00-lab-and-ansible-basics.md): idempotency, `--check --diff` and the CIS background of control 1.6.
- Exercise [2.02 - SSH server hardening with a Jinja2 template](../../stage2-building-blocks/2.02-sshd-template/README.md): where `Banner` is set.
- Exercise [2.06 - All login banners from one template](../../stage2-building-blocks/2.06-banners-template-loop/README.md): the same idea for `/etc/issue`, `/etc/issue.net` and `/etc/motd`.
- [`ansible.builtin.copy` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html)
- [`sshd_config(5)`: `Banner`](https://man.openbsd.org/sshd_config) and [`issue(5)`](https://man7.org/linux/man-pages/man5/issue.5.html)

## Reference solution

Show it with `lab solution 0.04`, apply it with `lab solve 0.04`.
