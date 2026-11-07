# 2.06 - All login banners from one template: Explanation

### What the check verifies
`lab check 2.06` runs `check.yml` on all eight targets and then your playbook once more with
`--check`, expecting `changed=0` (`meta.yml` says `idempotency: true`). For each of `/etc/motd`,
`/etc/issue` and `/etc/issue.net` it reads the text and asserts:
- it contains `lab_org_name` and the word *authorized* (or *authorised*, any case);
- it contains none of the getty escapes `\m`, `\r`, `\s`, `\v` and not the host's
  `distribution` fact (any case);
- the file is `0644` and `root:root`.

It does not test: other escapes such as `\S` (the pretty name), `\l` (the terminal) or `\n` (the
host name) - a banner with `\S` passes, measured with the check's own expression -, a version
number without the distribution name, and that one template and one looped task produced the
three files. The fresh targets fail on purpose: every `/etc/issue` and `/etc/issue.net` holds the
distribution name and `\r \m`.

### How it works

#### One template, three destinations
```yaml
- name: Deploy login banners
  ansible.builtin.template:
    src: banner.j2
    dest: "{{ item }}"
    owner: root
    group: root
    mode: "0644"
  loop: [/etc/motd, /etc/issue, /etc/issue.net]
```
The template is plain text with `{{ lab_org_name }}`. Three files, one source: a change to the
legal text is one edit, and `--diff` shows it per file.

#### Where the variable comes from
`lab_org_name` lives in `/lab/ansible/inventory/group_vars/all.yml`. Measured for lesson L07:
inventory `group_vars` lose against play `vars:`, a role's `vars/main.yml` beats both, and `-e`
beats everything. `ansible-inventory --host alpine` shows what a host ends up with - use it for
the bonus with `host_vars`.

#### No `ansible_managed` here
In configuration files the comment helps; in a banner every user would read it. Choose
deliberately.

#### Who shows which file
- `/etc/issue` is printed by the console getty before the login prompt. It replaces escapes
  like `\r` (kernel release) and `\m` (architecture) - which is how OS information leaks.
- `/etc/issue.net` is shown by sshd only when `Banner` points to it. On all lab hosts sshd
  reports `banner none` at the start: the file is managed for CIS, but nobody sees it until the
  sshd configuration of 2.02 (`Banner /etc/issue.net`) is in place.
- `/etc/motd` appears after the login - through `pam_motd` or through sshd's `PrintMotd`. The
  table shows which one each host uses; on opensuse the measurement found neither in
  `/etc/pam.d` (`PrintMotd no`).

#### Generated message of the day (bonus 2)
Some hosts add text from scripts or directories to what the user sees. Ubuntu runs the
scripts in `/etc/update-motd.d` (`00-header` and three more), Debian has one named `10-uname`;
both hosts have a `/run/motd.dynamic` for `pam_motd` to show. opensuse ships `/usr/lib/motd.d/welcome`.
CIS cares about what the user *sees*: remove the execute bit of such scripts, or drop the dynamic
part from the PAM configuration, and document it.

#### Symbolic links on fedora
On fedora `/etc/issue` and `/etc/issue.net` are symbolic links into `/usr/lib` (`stat` shows mode
`777` and a size of 16 and 20 bytes). `template` replaces the link with a regular file and leaves
the vendor file untouched (measured: run 1 `changed`, run 2 `ok`). That is what you want here - a
package update cannot overwrite your banner through the link any more.

### Per-family notes
| `os_family` | Hosts | `/etc/motd` at the start | Generated parts | Shown after an SSH login by |
|---|---|---|---|---|
| Debian | debian, ubuntu | debian: Debian licence text; ubuntu: none | debian: `update-motd.d/10-uname`; ubuntu: four scripts in `update-motd.d` | `pam_motd` |
| RedHat | rocky, alma, fedora | empty | `/etc/motd.d` and `/usr/lib/motd.d` empty | `pam_motd` |
| Suse | opensuse | none | `/usr/lib/motd.d/welcome` | no `pam_motd` in `/etc/pam.d`, `PrintMotd no` |
| Archlinux | arch | none | none | `pam_motd` in `system-login` |
| Alpine | alpine | welcome text (284 bytes) | none | sshd `PrintMotd yes` |

`/etc/issue` and `/etc/issue.net` start as "Welcome to <distribution> <version> \r \m" on all
eight hosts.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| The check fails on a fresh host | the shipped `issue` files name the distribution and contain `\r \m` | deploy your template |
| Users still see the OS version after login | generated message of the day (Debian, Ubuntu) | disable the scripts, document it |
| The check passes with `\S` in the banner | it only looks for `\m \r \s \v` | no escapes at all in your text |
| "Ansible managed" shows up at login | `ansible_managed` in the template | leave it out of banners |
| Nobody ever sees `/etc/issue.net` | sshd `Banner none` | set `Banner /etc/issue.net` in sshd (2.02) |

### Real-world notes
- The legal text belongs to someone else (legal, security office). Keep it in one variable or
  one file and let them review changes through the repository.
- A banner shown before authentication (`issue.net` via sshd) is the one that matters for
  warning unauthorised users; the message of the day comes too late for that.

### Further reading
- Lesson [L04 - Platform differences as data: dictionaries, loops, Jinja2 and templates](../../../docs/lessons/L04-platform-differences-as-data.md): templates, loops and variables - the concepts before this exercise.
- Exercise [0.04 - First hardening playbook: SSH warning banner](../../stage0-foundations/0.04-first-playbook-banner/README.md): the one-file version this exercise generalises.
- Exercise [2.02 - SSH server hardening with a Jinja2 template](../2.02-sshd-template/README.md): where the SSH `Banner` belongs.

## Reference solution

Show it with `lab solution 2.06`, apply it with `lab solve 2.06`.
