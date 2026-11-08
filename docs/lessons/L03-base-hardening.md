# L03 - Base hardening: packages, services, file permissions, SSH and sudo

*[Deutsch](L03-base-hardening.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 1.01, 1.02, 1.03, 1.04, 1.05, 2.01 | 2.1, 2.2, 5.1, 5.2, 7.1 | ~25 min | L00, L02 |

L02 taught how to change a host safely; this lesson is about *what* you change in the first
hardening steps and what "done" means for each of them: software that should not be there,
services that should not run, files that should not be readable, and the two programs - sshd
and sudo - through which you manage the host yourself.

## Learning goals

After this lesson you can ...

- [ ] tell apart installed, running, enabled and masked, and pick the module that changes each
- [ ] verify that a removal had the intended effect instead of trusting the package database
- [ ] write file modes without the quoting trap and explain why compliance is a bound, not a value
- [ ] predict which value sshd uses when several files set the same keyword, and read the effective result
- [ ] predict which sudoers drop-ins are read, in which order, and which are ignored
- [ ] name the two programs where a mistake costs you the management channel, and why

## Theory

### Attack surface in layers: installed, running, enabled

"Get rid of the FTP server" can mean four different things, and a policy that asks for one is
not met by another. A program has several layers, and each one is changed by a different
mechanism:

| Layer | Question | Ansible |
|---|---|---|
| installed | are the files on the disk? | `package` with `state: absent` |
| running | is there a process right now? | `service` with `state: stopped` |
| enabled | is it started at boot? | `service` with `enabled: false` |
| masked (systemd only) | can anything start it? | `systemd_service` with `masked: true` |

Stopped and disabled still leave the program startable: an administrator, a script or another
unit that depends on it can bring it back. A masked unit cannot be started at all, and a
removed package has nothing left to start, to misconfigure or to receive a vulnerability.
Removal is therefore the strongest answer; stop-and-disable is the fallback when something on
the host needs the package.

`package` looks at the fact `pkg_mgr` and calls the matching module, so one task works on all
eight hosts. `state: absent` describes the end state: a package that is not installed already
satisfies it, so the task reports `ok` and nothing needs a condition to protect it. Options
that only one manager knows (`purge` for apt, `autoremove` for apt and dnf) need that
manager's own module. `service` hides the difference between systemd and OpenRC, but it does
not hide it from `service_facts`:

```yaml
- name: Report how the init system describes a service
  hosts: targets
  become: true
  tasks:
    - name: Collect service data
      ansible.builtin.service_facts:
    - name: Show the entry of the SSH daemon
      ansible.builtin.debug:
        msg: "{{ ansible_facts.services[item] }}"
      loop: [ssh.service, sshd.service, sshd]
      when: item in ansible_facts.services
```

On systemd hosts the entry has `state` (running or stopped) and `status` (enabled, disabled,
static, masked ...); on OpenRC it has `state` and a list `runlevels`, and no `status` at all -
"enabled" means that `default` is in that list. Code that reads `status` works on seven hosts
and silently fails to see anything on the eighth.

The package database is not the last word either. Verify the *effect*:

```yaml
- name: Remove a package and check the effect
  hosts: targets
  become: true
  tasks:
    - name: Package is absent
      ansible.builtin.package:
        name: lab-no-such-package
        state: absent
    - name: Look for the program itself
      ansible.builtin.stat:
        path: /usr/bin/lab-no-such-program
      register: program
    - name: Removal left nothing behind
      ansible.builtin.assert:
        that: not program.stat.exists
        fail_msg: "the program is still installed"
```

Both tasks are `ok` on every host, so the second run is a no-op as well - and that is the point:
the assertion checks the thing the policy cares about, not the thing the module reports.

### One tool, many packages: removing by name

The same program ships in differently named packages: the DNS lookup tool `dig` lives in
`bind9-dnsutils` on Debian, `bind-utils` on RedHat and Suse, `bind-tools` on Alpine and `bind`
on Arch (see the table below). A removal list written for one distribution fails or does
nothing on another. Two more traps make the name unreliable:

- a **transitional or meta package** exists only to depend on another one; removing it leaves
  the program installed
- a **bundle** package ships several tools, and removing it removes all of them; read what a
  name provides first (`dpkg -L`, `rpm -ql`, `pacman -Ql`, `apk info -L` list the files of an
  installed package)

Write the removal for the name the *host* uses and look at what is left on disk afterwards.

### Modes: bits, notation and why compliance is a bound

A file mode has three groups (owner, group, others) of three bits each: read, write, execute.
`0640` means owner read and write, group read, others nothing; the leading `0` is part of the
octal notation, the optional first digit holds setuid, setgid and sticky. The `file`, `copy`
and `template` modules accept octal or symbolic modes, and `stat` reports the current value as
a four-digit string:

```yaml
- name: Modes as the file module sees them
  hosts: targets
  become: true
  tasks:
    - name: Scratch directory
      ansible.builtin.file:
        path: /tmp/lab-modes
        state: directory
        mode: "0755"
    - name: One file per notation
      ansible.builtin.copy:
        dest: "/tmp/lab-modes/{{ item.name }}"
        content: "demo\n"
        owner: root
        group: root
        mode: "{{ item.mode }}"
      loop:
        - {name: octal, mode: "0640"}
        - {name: symbolic, mode: "u=rw,g=r,o="}
        - {name: strict, mode: "0000"}
    - name: Read the result back
      ansible.builtin.stat:
        path: "/tmp/lab-modes/{{ item }}"
      loop: [octal, symbolic, strict]
      register: modes
    - name: Compare
      ansible.builtin.debug:
        msg: "{{ item.item }}: {{ item.stat.mode }} {{ item.stat.pw_name }}:{{ item.stat.gr_name }}"
      loop: "{{ modes.results }}"
      loop_control:
        label: "{{ item.item }}"
```

`octal` and `symbolic` end up with the same bits (`0640`). **Quote the mode.** YAML reads an
unquoted `0640` as an octal number and an unquoted `640` as the *decimal* number 640, which is
octal `1200`: write-only for the owner and the sticky bit on top. `ansible-lint` has a rule for
this because the result looks plausible and is wrong. Symbolic modes are self-documenting and
can remove single bits (`go-w`), but then the result depends on the starting state.

Two details matter for system files. First, the owner and group are given by **name** and
looked up *on the target*: a group that does not exist there makes the task fail, and the same
file can have a different correct group on a different distribution. Second, root bypasses the
read and write bits of ordinary files (it holds the capability `CAP_DAC_OVERRIDE`), so even
`0000` costs root nothing and denies everyone else. Distributions use the freedom differently:
some give the password hash files to a dedicated group so that small setgid helpers can verify
a password without being root, others close them for everyone but root. Both are secure, which
is why the recommendations are written as a bound ("this strict or stricter") and why a check
must not compare against a single magic value.

Finally, `file` with only `mode`, `owner` or `group` expects the path to exist and fails on a
missing file. System files such as backup copies do not exist everywhere, so the task needs to
know first - `stat` and a condition, or a loop over what exists (L04 builds that).

### sshd: several files, one effective value

An sshd setting is only worth what the *running* daemon sees. The configuration is the main
file plus the files pulled in by `Include` (typically `sshd_config.d/*.conf`), read in lexical
order, and for almost every keyword the **first** value that sshd reads wins. Later values for
the same keyword are ignored. The position of the `Include` line matters as well: at the top of
the main file, the drop-ins decide; at the bottom, the main file's own lines win.

```yaml
- name: First value wins in sshd
  hosts: targets
  become: true
  tasks:
    - name: Scratch directory for the drop-ins
      ansible.builtin.file:
        path: /tmp/lab-sshd/conf.d
        state: directory
        mode: "0755"
    - name: Main file that includes the drop-ins first
      ansible.builtin.copy:
        dest: /tmp/lab-sshd/sshd_config
        content: |
          Include /tmp/lab-sshd/conf.d/*.conf
          MaxAuthTries 6
        mode: "0644"
    - name: Two drop-ins that disagree
      ansible.builtin.copy:
        dest: "/tmp/lab-sshd/conf.d/{{ item.name }}"
        content: "MaxAuthTries {{ item.tries }}\n"
        mode: "0644"
      loop:
        - {name: 10-legacy.conf, tries: 10}
        - {name: 20-team.conf, tries: 3}
    - name: Ask sshd for the effective configuration
      ansible.builtin.command: /usr/sbin/sshd -T -f /tmp/lab-sshd/sshd_config
      register: effective
      changed_when: false
    - name: Report the winner
      ansible.builtin.debug:
        msg: "{{ effective.stdout_lines | select('match', '(?i)^maxauthtries ') | list }}"
```

The report shows `10`: `10-legacy.conf` is read before `20-team.conf`, and both come before
the main file's own `6`. A file named `00-` would beat all of them; a file named `99-` would
lose. The example works on a scratch copy so that it cannot affect the real daemon; with the
real files the same command is `sshd -T` without `-f`, run as root.

`sshd -T` prints the effective configuration, keyword and value per line. Keywords are
case-insensitive and the output spelling depends on the version (some releases print
`permitrootlogin`, others `PermitRootLogin`), so compare the keyword in lower case; the values
keep their case. Sections that start with `Match` apply only to connections that fit a
condition, and everything after a `Match` line belongs to it until the next `Match` or the
end of that file. Evaluate one for a given connection with `-C`:

```bash
sshd -T -f /tmp/lab-sshd/sshd_config -C user=backup,host=example,addr=192.0.2.10
```

A line appended to the end of a main file that already contains a `Match` block becomes part of
that block: silently if the keyword is allowed there, as a startup error if it is not. A
`Match` block inside a drop-in ends with that file, so it cannot swallow the next one. That is
one more reason to keep your own settings in a file you own.

A changed configuration reaches the daemon with a **reload** (sshd re-reads its files and
re-executes itself) or a **restart**. Existing sessions survive a reload - including the one
Ansible is using - and only *new* logins follow the new rules. So a configuration that is valid
but wrong does not hurt on the run that applies it; it hurts on the next login, when you cannot
get in. Keep a second session open, and test a new login before you close the first one.

### sudo: drop-ins, order, and the management channel

`sudo` reads `/etc/sudoers`, which ends with an include directive for a directory
(`@includedir /etc/sudoers.d`; older sudo spells it `#includedir`, and the `#` there is *not* a
comment). The rules for that directory:

- files are read in lexical order, and **later entries win** for `Defaults` - the opposite of
  sshd
- a file whose name contains a `.` or ends in `~` is skipped without a message (packages leave
  backups and templates there); `30-site.conf` does nothing, `30-site` works
- a file is a list of `Defaults` options and rules; both kinds can appear in any file

```
# /etc/sudoers.d/10-site            read first
Defaults passwd_tries=5
# /etc/sudoers.d/20-site            read later: this value is used
Defaults passwd_tries=2
# /etc/sudoers.d/30-site.conf       never read: the name contains a dot
Defaults passwd_tries=7
```

`Defaults` settings tune the policy. A pseudo-terminal for the command (`use_pty`) stops a
process that outlives the command from writing into the user's terminal; a dedicated log file
(`logfile`) gives auditors one place to read privilege use, in addition to the system log; how
long a user stays authenticated (`timestamp_timeout`) is a `Defaults` option as well.

What sets sudo and sshd apart from every other hardening target: **Ansible itself depends on
both**. It connects through sshd and becomes root through sudo. A syntax error in a sudoers
file makes sudo refuse *all* commands, so the very next task cannot become root - on every
host the play has reached. The program ships a checker that reads a file without installing
it; finding the call is part of the exercise, and L02 showed where it plugs in (`validate`).
In the lab the account Ansible uses has its own sudo rule; leave it where it is.

## CIS background

The recommendations behind these exercises share one idea: remove what the host does not need
and close what it must keep. Sections 2.1 (server services) and 2.2 (client services) in
[the control catalogue](../../cis/controls.yml) reduce what an attacker can reach or abuse;
clear-text clients such as telnet are the textbook case, and "remove, or at least stop and
disable" mirrors the layers above. Section 5.1 (SSH server) limits how an attacker can log in:
no direct root login, so that the audit trail names a person, and no empty passwords. Section
5.2 (privilege escalation) makes sudo use traceable and keeps runaway processes out of the
user's terminal. Section 7.1 (system file permissions) protects the files that hold accounts
and password hashes: a readable hash file lets any local user crack the hashes offline.

All of them are Level 1: cheap, with little risk for the services on the host. The risk is in
the two that touch the management channel (5.1, 5.2) - hence the care in L02. The trade-off of
"remove instead of disable" is that a package needed later must be reinstalled; the answer is a
recorded exception (L11), not a service that runs by default.

## Platform differences

| os_family | Hosts | `pkg_mgr` | Package with `dig` | "Enabled" in `service_facts` | Vendor defaults |
|---|---|---|---|---|---|
| Debian | debian, ubuntu | `apt` | `bind9-dnsutils` | `status: enabled` | `/etc` |
| RedHat | rocky, alma, fedora | `dnf` (`dnf5` on fedora) | `bind-utils` | `status: enabled` | `/etc`, distribution drop-ins in `sshd_config.d` |
| Suse | opensuse | `zypper` | `bind-utils` | `status: enabled` | `/usr/etc`, local changes in `/etc` |
| Alpine | alpine | `apk` | `bind-tools` | `default` in `runlevels`, no `status` | `/etc` |
| Archlinux | arch | `pacman` | `bind` | `status: enabled` | `/etc` |

On openSUSE the vendor defaults of several programs live under `/usr/etc` and a file in `/etc`
overrides them. A tool that checks "the system's" configuration can complain about a file you
do not own. On Ubuntu 26.04 the `sudo` command is a Rust reimplementation (sudo-rs) by default,
with the original sudo available beside it; it reads the same sudoers files, but it does not
implement every option and `sudo -V` does not list policy values. Look at `sudo --version`
before you rely on a sudo feature. The lab's Ubuntu image is different: there `sudo` is the
original sudo 1.9.17p2 (an alternatives link to `sudo.ws`), so the exercises behave as on the
other hosts.

### In the lab containers

- Services run under a real init system, so `service` and `systemd_service` behave as on a VM.
  The targets ship `telnet` and `vsftpd` where their distribution has them, so some hosts
  start with the software and some without.
- The lab's boot script puts the `Include` line at the **top** of the sshd main file on every
  host, so a drop-in decides, as described above. On a real host check
  `grep -n '^Include' /etc/ssh/sshd_config` first. It also plants a legacy drop-in with weak
  settings, which is what you have to outvote.
- The lab account `ansible` has its own sudo rule in `/etc/sudoers.d`. If you break sudo,
  `./lab.sh reset <host>` (`.\lab.ps1 reset <host>` on Windows) restores the host.
- File permissions are fully realistic: they live in the container's own file system.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The package task is `ok`, the program is still on the disk | meta or transitional package, or another package provides the program | verify the effect (`stat`, `command -v`), remove what actually provides the file |
| A removal takes unrelated tools with it | the package bundles several programs | list what the package provides before you remove it |
| A stopped, disabled service is running again | a socket unit or a dependent unit starts it on demand | disable the socket too, or mask the unit, or remove the package |
| A file has odd bits such as `-w----r-T` after `mode: 644` | YAML read `644` as a decimal number | quote the mode: `"0644"` |
| `failed to look up group shadow` | the group does not exist on that distribution | take the group per OS family (L04) or choose a group that exists |
| `file (...) is absent, cannot continue` | the path does not exist on this host | `stat` first and act only where it exists |
| A new sshd drop-in has no effect | another file is read earlier, a `Match` block swallows it, or `Include` is at the bottom | read `sshd -T`, then rename the drop-in or move the `Include` |
| The comparison with `sshd -T` output fails on one host | the keyword is spelled `PermitRootLogin` there, not `permitrootlogin` | lower-case the keyword before comparing |
| A sudoers drop-in is ignored although the syntax is fine | the file name contains a `.` or ends in `~` | rename it without a dot |
| The play passed, and the next login fails | a reload applies the configuration only to new connections | keep a second session open and log in anew before you close it |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [1.01](../../exercises/stage1-beginner/1.01-remove-telnet/README.md) | layers, `state: absent` as end state, package names, verifying the effect |
| [1.02](../../exercises/stage1-beginner/1.02-passwd-group-permissions/README.md) | mode notation and the quoting trap, owner and group by name, files that may not exist |
| [1.03](../../exercises/stage1-beginner/1.03-ssh-root-login/README.md) | the sshd file order, first value wins, `sshd -T`, reload versus restart |
| [1.04](../../exercises/stage1-beginner/1.04-disable-ftp-server/README.md) | stopped versus disabled versus masked, `service_facts` per init system |
| [1.05](../../exercises/stage1-beginner/1.05-sudo-hardening/README.md) | sudoers drop-ins, order and ignored names, why sudo cannot be broken |
| [2.01](../../exercises/stage2-building-blocks/2.01-shadow-permissions-per-family/README.md) | why the correct mode differs per distribution, modes as a bound, optional files |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. `package` with `state: absent` reports `ok` on a host, yet the program still starts. Name
   two reasons and the check that would have caught it.

   <details><summary>Answer</summary>

   The name you removed was a meta or transitional package that only depends on the real one,
   or another package provides the program as well. `ok` says that the package named in the
   task is absent, not that the policy is met. Check the effect: does the file exist, does the
   command resolve? The same applies to the services: a program can be stopped and still be
   startable.

   </details>

2. What separates stopped, disabled and masked, and which one still lets another unit start the
   service?

   <details><summary>Answer</summary>

   Stopped affects the running process only, disabled only the start at boot; neither stops an
   administrator or a dependent unit from starting it again. Masked (systemd) links the unit to
   `/dev/null`, so nothing can start it, whereas removal takes away the program itself. Masking
   needs `systemd_service`; `service` covers the first two on systemd and OpenRC alike.

   </details>

3. How do you test in code that a service is enabled on systemd hosts and on alpine?

   <details><summary>Answer</summary>

   On systemd, `ansible_facts.services[name].status` is `enabled`. OpenRC entries have no
   `status`; they carry `runlevels`, and the service counts as enabled if `default` is in that
   list. A condition that reads only `status` never sees an enabled service on alpine.

   </details>

4. What does `mode: 644` (unquoted) set, and why is `0000` still a sensible mode for a system
   file?

   <details><summary>Answer</summary>

   YAML reads it as the decimal number 644, which is octal `1204`: an odd mode with the sticky
   bit, not `rw-r--r--`. Quote modes, and `ansible-lint` flags the unquoted forms. `0000` is
   sensible because root bypasses the read and write bits of ordinary files, so it costs
   nothing and denies everyone else.

   </details>

5. Two sshd drop-ins `10-a.conf` and `20-b.conf` set the same keyword to different values.
   Which value is effective, which command proves it, and what would change it?

   <details><summary>Answer</summary>

   The one in `10-a.conf`, because sshd uses the first value it reads for most keywords and
   reads the drop-ins in lexical order. `sshd -T` (as root) prints the effective value. A file
   that sorts earlier (`00-...`), or the `Include` line moving, would change the outcome; so
   would a `Match` block that applies to the connection.

   </details>

6. A reload of sshd finishes without an error and your session continues. Why can the host
   still be unreachable ten minutes later?

   <details><summary>Answer</summary>

   A reload leaves established sessions alone and applies the new configuration to *new*
   connections only. A configuration that is syntactically valid but wrong (forbidden login
   method, wrong user, wrong key setting) shows its effect at the next login. Keep a second
   session open and make a test login before you close the first.

   </details>

7. How do the order rules of sudoers drop-ins differ from sshd's, and what makes a drop-in with
   perfect syntax do nothing?

   <details><summary>Answer</summary>

   Both read files in lexical order, but for sudo the later `Defaults` entry wins and for sshd
   the first value. Sudo skips file names that contain a `.` or end in `~` without any message,
   so `30-site.conf` is never read; name it `30-site`.

   </details>

8. A distribution makes `/etc/shadow` `root:root` with mode `0000`, another uses
   `root:shadow` with `0640`. Which is wrong?

   <details><summary>Answer</summary>

   Neither. Root bypasses the permission bits, and the group on the second variant lets small
   helper programs verify passwords without being root. A recommendation names a bound ("this
   strict or stricter, owner root"), so the right change keeps each distribution's own
   convention and tightens only what is looser than it. A check must test the bound, not a
   single value.

   </details>

## Further reading

- [`ansible.builtin.package`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/package_module.html) and [`ansible.builtin.service`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/service_module.html)
- [`ansible.builtin.systemd_service`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/systemd_service_module.html) - `masked` and `daemon_reload`
- [`ansible.builtin.service_facts`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/service_facts_module.html) and [`ansible.builtin.stat`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/stat_module.html)
- [`ansible.builtin.file`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/file_module.html) - `mode`, `owner`, `group`
- [`sshd_config(5)`](https://man.openbsd.org/sshd_config) - `Include`, `Match`, the first-value rule; [`sshd(8)`](https://man.openbsd.org/sshd) - `-T` and `-C`
- [`sudoers(5)`](https://www.sudo.ws/docs/man/sudoers.man/) - include directives, `Defaults`, file name rules
- [Glossary](../GLOSSARY.md) - terms of this lesson: attack surface, drop-in, management channel,
  mode (file), sshd effective value, sudoers
