# L05 - Kernel hardening: modules and sysctl

*[Deutsch](L05-kernel-modules-and-sysctl.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 2.03, 2.04 | 1.1.1, 1.5, 3.2, 3.3 | ~25 min | L00, L02, L04 |

Everything so far changed files, packages and services - things a host owns. The kernel is
different: it decides what code may be loaded and how the network stack behaves, and in the lab
all eight targets share **one** kernel. This lesson covers the two settings that reach it
(kernel modules and `sysctl` parameters), what an Ansible task can safely do to each, and where
a container turns a harmless-looking write into a change of your host.

## Learning goals

After this lesson you can ...

- [ ] tell a per-namespace parameter from a global one, and say what writing a global one from a privileged container does
- [ ] predict which value wins when several `sysctl.d` files set the same key
- [ ] choose between persisting, applying now and reloading with `ansible.posix.sysctl`, and say what each of them touches
- [ ] write a `modprobe.d` rule that blocks loading and read it back without loading anything
- [ ] name what such a rule does not cover: `blacklist` alone, modules already loaded, `insmod`, the initramfs
- [ ] check that the collection a module comes from is installed, and declare it for your own project

## Theory

### One kernel, many views: namespaced and global parameters

A container has its own file system, process list and network stack, but not its own kernel.
The kernel's parameters appear as files below `/proc/sys`, and each key is one of two kinds.
**Namespaced** keys have one copy per namespace: most `net.*` keys belong to the network
namespace, so each container changes only its own value. **Global** keys have one copy for the
whole machine: `kernel.*`, `fs.*`, `vm.*`. A few `net.*` keys are global too, so look a key up
in the [kernel documentation](https://docs.kernel.org/admin-guide/sysctl/index.html) when it
matters.

By default a container gets `/proc/sys` read-only, so the question never comes up. The lab
targets run **privileged** because they need a real init system: there `/proc/sys` is
writable, and a write to a global key changes the host and every other container on it. This
play shows the namespaced case without risk: it starts a throw-away network namespace with
`unshare`, changes a value inside and reads the original again:

```yaml
- name: One value, two network namespaces
  hosts: targets:!alpine
  become: true
  gather_facts: false
  tasks:
    - name: Value in this network namespace
      ansible.builtin.command: sysctl -n net.ipv4.ip_default_ttl
      register: here
      changed_when: false
      check_mode: false
    - name: Set another value in a throw-away namespace and read it there
      ansible.builtin.command:
        argv:
          - unshare
          - --net
          - sh
          - -c
          - sysctl -w net.ipv4.ip_default_ttl=33 >/dev/null; sysctl -n net.ipv4.ip_default_ttl
      register: inside
      changed_when: false
      check_mode: false
    - name: Read the value in this namespace again
      ansible.builtin.command: sysctl -n net.ipv4.ip_default_ttl
      register: after
      changed_when: false
      check_mode: false
    - name: Compare the three readings
      ansible.builtin.debug:
        msg: "before {{ here.stdout }}, in the new namespace {{ inside.stdout }}, after {{ after.stdout }}"
```

The output is `before 64, in the new namespace 33, after 64`: the 33 existed only inside. Do
not try this with a `kernel.*` key - there is no second copy, and you would change the real
one. Reading is always safe (`sysctl -n <key>`); before writing, ask whose value it is.

The lab has a switch for this: `lab_in_container: true` in
`ansible/inventory/group_vars/all.yml`. Tasks that touch global state are reduced to writing
configuration while it is set and do the full job on a VM where it is `false` (see
[the container limits](../CONTAINER_LIMITS.md)).

### sysctl: running value, file, and the order of files

A parameter has a *running* value and, usually, a *configured* one. `sysctl -w key=value`
changes the running kernel at once and is forgotten at the next boot (in the lab: the next
start of the container). A file in a `sysctl.d` directory is applied at boot - by
`systemd-sysctl` on the systemd families - and changes nothing until then. Hardening needs
both, and an audit finds the places where they disagree.

When several files set the same key, **the last one read wins**. The directories
(`/etc/sysctl.d`, `/run/sysctl.d`, `/usr/lib/sysctl.d` and a few more) are merged and read in
the order of the *file names*, whatever directory they sit in; with `procps` the file
`/etc/sysctl.conf` comes last of all. A vendor `50-pid-max.conf` in `/usr/lib/sysctl.d` is
therefore read after a `10-*.conf` from `/etc` and before your `60-hardening.conf`, and a
stray `99-*.conf` overrides you. A file in `/etc` with the same name as one in `/usr/lib`
replaces it. Look at the merged result instead of guessing - on a systemd host this only reads:

```bash
ansible debian -b -m ansible.builtin.command -a "systemd-analyze cat-config sysctl.d"
```

`ansible.posix.sysctl` manages one key per task. Its options map directly to the two states:

| Option | What it controls |
|---|---|
| `name`, `value` | the key and the wanted value |
| `sysctl_file` | the file the line is written to (default `/etc/sysctl.conf`) |
| `sysctl_set` | `true`: also write the running value now (`sysctl -w`) |
| `reload` | default `true`: run `sysctl -p <file>` after a change - this applies **every line of that file**, not only your key |
| `ignoreerrors` | continue when the running kernel does not know the key |
| `state` | `present` (default) or `absent` to remove the line |

Three behaviours matter. The module compares the *running* value with the wanted one before
it acts, so a second run reports `ok`. In `--check` mode it reports `changed` without
writing. And the two modes fail differently for a key that does not exist - say
`kernel.yama.ptrace_scope` on a kernel without the Yama security module: with
`sysctl_set: true` the task fails with `cannot stat /proc/sys/...` and writes nothing; with
`sysctl_set: false` the line is written unchecked, a typo included, and you find out when the
file is applied.

```yaml
- name: Persist a per-namespace parameter and apply it now
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Make sure the drop-in directory exists (rocky and alma ship without it)
      ansible.builtin.file:
        path: /etc/sysctl.d
        state: directory
        owner: root
        group: root
        mode: "0755"
    - name: Persist and apply the default TTL (the default value, so nothing changes in behaviour)
      ansible.posix.sysctl:
        name: net.ipv4.ip_default_ttl
        value: "64"
        sysctl_file: /etc/sysctl.d/70-lesson.conf
        sysctl_set: true
        reload: false
    - name: Read the file back
      ansible.builtin.command: cat /etc/sysctl.d/70-lesson.conf
      register: persisted
      changed_when: false
      check_mode: false
    - name: Show it
      ansible.builtin.debug:
        var: persisted.stdout_lines
```

`reload: false` keeps the task to one key: the file may contain other lines, and `sysctl -p`
would apply them all - which matters as soon as one of them is global.

### Kernel modules: who loads them, and what `modprobe.d` can stop

A module is kernel code loaded on demand: when you run `modprobe`, when the kernel needs
support it does not have (mounting a file system type, opening a socket of an uncommon
protocol), and when a device appears. Each path ends in `modprobe`, which reads
`/etc/modprobe.d/*.conf` (and the vendor directories) first. Two keywords matter here:

- `install <module> <command>` replaces the load by the command - with `/bin/false` the load
  fails. It applies to every `modprobe` of that name, explicit or not.
- `blacklist <module>` tells `modprobe` to ignore the module's own aliases (the device and
  file-system names it announces about itself). It is only applied when the caller asks for it
  (`modprobe -b`): a plain `modprobe <module>` with the real name **still loads** it.

You can see this without loading anything: `modprobe -n -v` does a dry run, `modprobe -c`
dumps the effective configuration. With a module that is present, the three cases read:

| Configuration | `modprobe -n -v <module>` prints |
|---|---|
| none | `insmod <path>/<module>.ko` - it would load |
| `blacklist` only | the same `insmod ...` line - still loads; with `-b` it prints nothing |
| `install <module> /bin/false` | `install /bin/false` - the command replaces the load |

A real `modprobe` of an `install /bin/false` module exits with `Error running install command
'/bin/false' ... retcode 1`: that is the rule working, not a failure of your play. A rule that
holds has the `install` line; `blacklist` adds protection against callers that honour it.

What a rule does **not** do matters as much. It does not unload a module that is already
loaded, and it does not affect one compiled into the kernel. `insmod` loads a file you name
and does not read `modprobe.d`. Modules needed at boot come from the *initramfs*, which holds
its own copy of the configuration made when it was built (on Debian, `mkinitramfs` copies
`/etc/modprobe.d/*.conf`), so on a real host a changed rule needs an initramfs rebuild before
it holds at early boot. Loading and unloading is the job of `community.general.modprobe`, and
that must never run in a lab container: `lsmod` in a target shows the host's modules, and
`modprobe -r` would remove them from the host.

A rule file is a file, so `copy` writes it (with `loop` for several, L04). To see the
mechanism without touching a real module, use a name that does not exist. On the kmod hosts
(BusyBox on alpine has neither `-n` nor `-c`):

```yaml
- name: Write a module rule and read it back without touching a real module
  hosts: targets:!alpine
  become: true
  gather_facts: false
  tasks:
    - name: Rule for a module name that does not exist
      ansible.builtin.copy:
        dest: /etc/modprobe.d/lesson-demo.conf
        content: |
          install lesson_demo /bin/true
          blacklist lesson_demo
        owner: root
        group: root
        mode: "0644"
    - name: Dry run - what would modprobe do?
      ansible.builtin.command: modprobe -n -v lesson_demo
      register: dry
      changed_when: false
      check_mode: false
    - name: Dump the effective configuration
      ansible.builtin.command: modprobe -c
      register: dump
      changed_when: false
      check_mode: false
    - name: Show both
      ansible.builtin.debug:
        msg:
          - "dry run: {{ dry.stdout | trim }}"
          - "config: {{ dump.stdout_lines | select('search', 'lesson_demo') | list }}"
```

The dry run prints `install /bin/true`. Without the file it would say that the module was not
found - the targets have no module directory, so this is also what a real module name
reports *before* it is configured. The two demo files are harmless; `./lab.sh reset <host>`
(`.\lab.ps1 reset <host>` on Windows) or a `file` task with `state: absent` removes them.

### Collections: where `ansible.posix.sysctl` comes from

`ansible-core` ships the `ansible.builtin` modules only. Everything else lives in *collections*
named `namespace.name`, and a module is addressed by its fully qualified name (FQCN):
`ansible.posix.sysctl`. The `ansible` package on the lab's control node bundles the common
collections (`ansible.posix` and `community.general` among them), so nothing has to be
fetched. Ask what is installed:

```bash
ansible-galaxy collection list ansible.posix
ansible-doc ansible.posix.sysctl | head -20
```

Your own projects should not rely on what happens to be installed. Declare the collections in
`collections/requirements.yml` and install them with `ansible-galaxy collection install -r
collections/requirements.yml`, so a colleague or a CI job gets the same modules:

```yaml
---
collections:
  - name: ansible.posix
    version: ">=2.0.0"
```

A module that cannot be found fails at once with `couldn't resolve module/action
'ansible.posix.sysctl'` - the signal that the collection is missing, not that the task is wrong.

## CIS background

The four groups [in the control catalogue](../../cis/controls.yml) are "config only" in the
lab, except 3.3, for the reasons above. **1.1.1** (Level 1) keeps rarely used file-system
drivers from loading: every driver is kernel code that parses data an attacker may control -
a crafted image on a removable disk is enough - and a server almost never needs the format.
**3.2** (Level 2) does the same for uncommon network protocols; it is Level 2 because
switching them off breaks real products (telecom software that speaks SCTP).

**3.3** (Level 1, the one group fully testable in the lab) stops a host from behaving like a
router and hardens it against spoofed or redirected traffic; **1.5** (Level 1) is process
hardening - address-space randomisation, no core dumps from privileged programs, restricted
debugging between processes. They are one-line settings that cost almost nothing; what they
cost is knowing which host legitimately needs the opposite (a router, a debugger on a build
server). Such exceptions belong in data, not in a patched task (L04, L11).

## Platform differences

| os_family | Hosts | Tools in the lab image | `sysctl.d` applied at boot by |
|---|---|---|---|
| Debian | debian, ubuntu | `kmod`, `procps` | `systemd-sysctl` |
| RedHat | rocky, alma, fedora | `kmod`, `procps-ng` | `systemd-sysctl` |
| Suse | opensuse | `kmod`, `procps` | `systemd-sysctl` |
| Alpine | alpine | BusyBox applets (`modprobe`, `sysctl`); the `kmod` package is installed, but `/sbin/modprobe` is BusyBox | OpenRC service `sysctl` - present, but the lab image does not enable it |
| Archlinux | arch | `kmod`, `procps-ng` | `systemd-sysctl` |

The systemd families share the mechanism; what differs is *where the vendor's own files are*.
On Ubuntu 24.04 the `procps` package puts files such as `10-kernel-hardening.conf` into
`/etc/sysctl.d` itself; elsewhere they sit in `/usr/lib/sysctl.d`. List the directories (or
use `systemd-analyze cat-config`) before you pick a file number.

The `modprobe` on alpine is BusyBox 1.37: it has neither `-n` nor `-c` (checked in the lab),
so the dry run above cannot work there, and I did not verify how it treats `install` lines.
A rule file written for kmod is *stored* correctly, but do not assume it is *enforced*.
Minimal images do not always contain `/etc/sysctl.d`: rocky and alma ship without it, so
create the directory first, or the write fails with `No such file or directory` (the example
above does that). `/etc/modprobe.d` exists on all eight targets.

### In the lab containers

- All eight targets share the host kernel, run privileged and have no copy of its module
  directory. `lsmod` shows the host's modules; `modprobe -r` and `rmmod` would unload them
  from the host - never run them in a target.
- `systemd-modules-load` is masked in the systemd targets, but `systemd-sysctl` is **not**
  and applies `/etc/sysctl.d` whenever a target starts. A global key you *persist* there
  therefore reaches the host at the next start of that container.
- Alpine does not apply `sysctl.d` at start in the lab image, so for a namespaced key the
  running value is the one that counts there.
- The examples need Python on the target, so alpine needs 0.02 first - the two examples
  with `targets:!alpine` skip it.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| A module with only a `blacklist` line still loads | `blacklist` is applied only with `modprobe -b`; a plain `modprobe <name>` ignores it | add `install <module> /bin/false`; verify with `modprobe -n -v` |
| `Error running install command '/bin/false'` | the rule works; you ran a real `modprobe` | inspect with `modprobe -n -v` or `-c`, do not load to test |
| `modprobe -n -v <module>` says the module was not found | no module directory in the container and no rule yet | expected; once the rule exists the output is `install ...` |
| `lsmod` still lists the module despite the rule | it was loaded before, is built in, or came from the initramfs | a rule stops *new* loads; unload on a real host, rebuild the initramfs |
| Other keys of the file changed too | `reload` is `true` by default and runs `sysctl -p <file>` for the whole file | `reload: false`, or know every line of the file |
| `cannot stat /proc/sys/kernel/yama/ptrace_scope` | `sysctl_set: true` on a key the running kernel does not have (here: no Yama) | write the file only, or `ignoreerrors: true`; decide per key |
| A misspelled key is written without complaint | with `sysctl_set: false` nothing asks the kernel | read the key back with `sysctl -n` once the file is applied |
| Your value is gone after a reboot | a later-sorted file (`99-...`) or `/etc/sysctl.conf` sets the key again | `systemd-analyze cat-config sysctl.d`; renumber or remove the override |
| `couldn't resolve module/action 'ansible.posix.sysctl'` | the collection is not installed | `ansible-galaxy collection install -r collections/requirements.yml` |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [2.03](../../exercises/stage2-building-blocks/2.03-disable-kernel-modules/README.md) | what `install` and `blacklist` do, reading a rule back without loading, why nothing is loaded or unloaded in the lab, one `copy` per item |
| [2.04](../../exercises/stage2-building-blocks/2.04-sysctl-network/README.md) | namespaced vs global keys, running value vs file, the `sysctl_set` and `reload` options, file order, a module from a collection |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. Why may a play set `net.ipv4.ip_default_ttl` in a lab target but must treat `kernel.*` keys
   differently?

   <details><summary>Answer</summary>

   `net.*` keys are mostly per network namespace: the target has its own copy and the write
   stays inside it. `kernel.*` keys are global, and the targets run privileged, so a write
   changes the single copy that the host and all other containers share.

   </details>

2. `/usr/lib/sysctl.d/50-a.conf` sets a key to 1, `/etc/sysctl.d/60-b.conf` to 2 and
   `/etc/sysctl.d/10-c.conf` to 3. Which value is active after boot?

   <details><summary>Answer</summary>

   2: the files are read in the order of their names (`10-c`, `50-a`, `60-b`) regardless of
   the directory, and the last assignment wins. A `99-d.conf` setting the key again would
   override it.

   </details>

3. A task has `sysctl_set: false` and no `reload`. The file contains three keys. What does
   the task do besides writing one line?

   <details><summary>Answer</summary>

   `reload` defaults to `true`, so after a change the module runs `sysctl -p <file>` and
   applies **all three keys** - including a global one, which in a privileged container
   reaches the host. `reload: false` writes only.

   </details>

4. `blacklist foo` is in place, yet `modprobe foo` loads the module. Why, and what stops it?

   <details><summary>Answer</summary>

   `blacklist` concerns the module's *aliases* and applies only when the caller passes `-b`;
   the real name is not affected. `install foo /bin/false` replaces the load for every
   `modprobe` of that name.

   </details>

5. `modprobe -n -v foo` prints `install /bin/false`, and `lsmod` still lists `foo`. Is
   the rule broken?

   <details><summary>Answer</summary>

   No. The dry run shows what *future* loads do. A module that is already loaded stays loaded
   until it is unloaded, and it may have come from the initramfs, whose copy of the
   configuration changes only with a rebuild. On a real host you unload it
   (`community.general.modprobe`, `state: absent`); in the lab you never do.

   </details>

6. A task fails with `cannot stat /proc/sys/kernel/yama/ptrace_scope`. Name two ways
   to handle it and say what each gives up.

   <details><summary>Answer</summary>

   Write the file only (`sysctl_set: false`): right for hosts that have the key, but nothing
   checks it now. Or add `ignoreerrors: true`: the task continues, but a *typo* in the key
   is silenced too. Neither makes the parameter exist - that depends on the kernel.

   </details>

## Further reading

- [`ansible.posix.sysctl`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/sysctl_module.html) and [`community.general.modprobe`](https://docs.ansible.com/ansible/latest/collections/community/general/modprobe_module.html) - all options
- [Using Ansible collections](https://docs.ansible.com/ansible/latest/collections_guide/index.html) - installing, `requirements.yml`, FQCN
- [`sysctl.d(5)`](https://www.freedesktop.org/software/systemd/man/latest/sysctl.d.html) - the directories and the order in which files are read
- [Documentation for `/proc/sys`](https://docs.kernel.org/admin-guide/sysctl/index.html) - what each parameter does
- [`modprobe.d(5)`](https://man.archlinux.org/man/modprobe.d.5) - `install`, `blacklist` and the other keywords
