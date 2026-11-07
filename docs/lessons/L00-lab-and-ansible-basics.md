# L00 - Lab architecture and Ansible basics

*[Deutsch](L00-lab-and-ansible-basics.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 0.01, 0.02, 0.03, 0.04 | 1.6 | ~25 min | - |

Before you harden anything you need to know what you manage, whether you can reach it and how
Ansible turns a task into a change on a remote host; this lesson covers the lab's moving parts
and the four Ansible ideas every later exercise relies on: inventory, module execution, facts
and idempotency.

## Learning goals

After this lesson you can ...

- [ ] describe how the control node reaches the eight targets and which account and privileges it uses
- [ ] read the lab inventory and select hosts with patterns, and check a pattern without connecting
- [ ] explain what happens on the target when a module runs and why some hosts cannot run modules
- [ ] decide when `raw` is the right tool and why it needs your help to report changes
- [ ] use facts such as `os_family` to make decisions, and know when facts of other hosts are available
- [ ] predict whether a task is idempotent and verify it with a second run or `--check --diff`

## Theory

### The lab: one control node, eight targets

Ansible is agentless and push-based: nothing runs permanently on a managed host. The control
node opens SSH connections, sends small programs (modules), collects their JSON results and
closes the connection again. In the lab this looks like this:

```
Docker host (native Linux, or the Linux VM of Docker Desktop / WSL2)
└── network "lab" (bridge)
    ├── control   Ansible, the lab CLI, your /lab/work  (you work here)
    └── targets   debian ubuntu rocky alma fedora opensuse arch alpine
                  sshd + init system (systemd, OpenRC on alpine), account "ansible"
```

How the pieces fit together:

- **Authentication.** The control node creates an SSH key pair in the shared volume
  `lab-keys`. Every target installs the public key for the account `ansible` at start
  (`lab-keysync`). There is no password: key only.
- **Privileges.** `ansible` may run any command as root via sudo without a password. That is
  what `become: true` (ad-hoc: `-b`) uses. Without `become` your tasks run as `ansible`.
- **Configuration.** The variable `ANSIBLE_CONFIG` points to `/lab/ansible/ansible.cfg`. It sets
  the inventory, `remote_user`, the key, `interpreter_python = auto_silent` (find Python on the
  target without warnings) and `pipelining = True` (send modules through the open SSH session
  instead of copying temporary files). Because `ANSIBLE_CONFIG` is set, an `ansible.cfg` in your
  current directory is **not** read.
- **Your work.** Everything you write lives in `/lab/work/<id>/` (`lab start <id>` creates it).
  The `lab` CLI shows exercises, hints and explanations and runs the checks.
- **Reset.** On the host, `./lab.sh reset <host|all>` (Windows PowerShell: `.\lab.ps1`)
  recreates a target in its original, deliberately non-compliant state. Breaking a target is part of learning, not a disaster.

The targets are reached exactly like servers: over SSH, as an unprivileged account that
escalates with sudo. `docker exec` would bypass all of that and teach the wrong habits.

### Inventory and patterns

The inventory answers *what do I manage?* The lab inventory (`/lab/ansible/inventory/hosts.yml`)
nests groups: `targets` contains one group per OS family, and each family group contains hosts.

```yaml
all:
  children:
    targets:
      children:
        redhat_family:
          hosts:
            rocky:
            alma:
            fedora:
```

The excerpt shows the shape: a host can be addressed through every group above it
(`fedora` is in `redhat_family`, `targets` and `all`). Variables attach to groups through
`group_vars/<group>.yml`; the lab has `all.yml` (lab-wide values such as `lab_in_container`) and
`targets.yml` (the SSH user and key). A host gets the merge of all its groups, more specific
groups win.

**Patterns** select hosts for an ad-hoc command or a play. They combine groups and hosts:

| Pattern | Meaning |
|---|---|
| `redhat_family` | all hosts in the group |
| `debian:rocky` | union (also written with `,`) |
| `targets:!alpine_family` | all targets except the group |
| `redhat_family:&targets` | intersection |

Check a pattern before you use it - `--list-hosts` resolves it without connecting anywhere,
and `ansible-inventory` shows structure and the merged variables of one host:

```bash
ansible 'targets:!debian_family' --list-hosts
ansible-inventory --graph redhat_family
ansible-inventory --host rocky --yaml
```

When "a variable has the wrong value", `ansible-inventory --host` is the first debugging step:
it shows what Ansible really sees for that host after merging all groups.

### How a module runs

`ansible.builtin.ping` is not an ICMP ping. It is a module like any other: Ansible connects via
SSH, starts the Python interpreter on the target, feeds it the module code, and expects JSON
back. A module run therefore needs two things on the target: **SSH access and Python**. A host
that accepts SSH logins can still fail every module if it has no usable Python interpreter.

Ad-hoc commands run one module once, from the shell - good for looking around:

```bash
ansible debian_family -m ansible.builtin.command -a 'uptime'
ansible rocky -b -m ansible.builtin.command -a 'id -u'
ansible ubuntu -m ansible.builtin.ping -vvv
```

The second line shows `become`: with `-b` the command runs as root and prints `0`. With `-vvv`
you see the SSH command line and how the module is sent - worth doing once.

A few modules work without Python on the target. `ansible.builtin.raw` sends a command line
over SSH and returns whatever it prints; `ansible.builtin.script` copies a local script and
runs it. This makes them the tools for **bootstrapping** a host that cannot run modules yet:

```bash
ansible arch -m ansible.builtin.raw -a 'uname -r'
```

The price: `raw` knows nothing about the state of the system. It cannot tell whether it
changed something, it does not support check mode, and it reports `changed` on every run. When
a task cannot judge its own effect, you tell Ansible with `changed_when` - an expression over
the registered result:

```yaml
- name: Read the SSH client version
  hosts: debian_family
  gather_facts: false
  tasks:
    - name: Ask ssh for its version
      ansible.builtin.command: ssh -V
      register: ssh_version
      changed_when: false
    - name: Show it
      ansible.builtin.debug:
        var: ssh_version.stderr
```

`changed_when: false` fits a task that only reads. A task that *sometimes* changes something
needs an expression that is true exactly then - for example based on its output or return
code. Designing such a task for a bootstrap is exercise 0.02.

### Facts

Facts are what Ansible knows about a host: distribution, OS family, package manager, service
manager, network interfaces, Python version and much more. The module `ansible.builtin.setup`
collects them; a play runs it automatically at the start (`gather_facts: true` is the default).
Because `setup` is a Python module, fact gathering fails on a host without Python - the play
then stops before your first task, which is why a bootstrap play must disable it.

Look at single facts ad-hoc with a filter:

```bash
ansible opensuse -m ansible.builtin.setup -a 'filter=ansible_os_family'
```

In playbooks, read facts from the dictionary `ansible_facts`, where the `ansible_` prefix is
dropped: `ansible_facts['os_family']`. Ansible also injects the prefixed names as top-level
variables (`ansible_os_family`) by default, but that is a setting (`inject_facts_as_vars`) that
can be switched off; `ansible_facts[...]` always works. Facts make platform decisions:

```yaml
- name: React to the OS family
  hosts: targets
  tasks:
    - name: Only on RedHat-family hosts
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} uses {{ ansible_facts['pkg_mgr'] }}"
      when: ansible_facts['os_family'] == 'RedHat'
```

Facts belong to the host that reported them. `hostvars['<host>']` gives access to the
variables and facts of any host, `groups['<group>']` lists the hosts of a group, and
`inventory_hostname` is the name of the current host:

```yaml
- name: Look at another host's facts
  hosts: debian_family
  tasks:
    - name: Show what ubuntu reported
      ansible.builtin.debug:
        msg: "{{ hostvars['ubuntu']['ansible_facts']['distribution_version'] | default('no facts') }}"
```

Run as is, both hosts print Ubuntu's version: every host of the play gathered its facts first.
Run with `-l debian`, it prints `no facts`: the facts of `ubuntu` exist only after a play in the
same run gathered them (or when a fact cache is configured). Keep this in mind whenever one
host or `localhost` needs data from others.

### Idempotency: describe the state, not the steps

A hardening playbook runs again and again - after changes, after updates, on new hosts. It must
therefore describe a **desired state**, and each task must change only what differs from it.
Modules such as `file`, `copy`, `template`, `package` and `service` compare the current state
with the requested one and report:

- `ok` - already as requested, nothing done
- `changed` - something was changed to reach the state
- `failed` / `skipped` / `unreachable` - self-explanatory

```yaml
- name: Desired state, not a command
  hosts: debian_family
  become: true
  tasks:
    - name: Directory for local notes exists
      ansible.builtin.file:
        path: /etc/lab-notes
        state: directory
        owner: root
        group: root
        mode: "0750"
```

Run it twice. The first run shows `changed=1` per host, the second `changed=0`: the directory
already exists with the right owner and mode. That second run is the test every playbook in
this lab must pass, and `lab check` performs it for you as a `--check` run - which skips tasks
that cannot predict their effect, such as the `raw` bootstrap of 0.02, so run that playbook
twice yourself.

Two tools let you look before you leap:

```bash
ansible-playbook notes.yml --check --diff
```

`--check` asks every module what it *would* change without changing it; `--diff` shows the
difference (file contents, permissions). Modules that cannot predict their effect are skipped
in check mode - `raw` always, `command` and `shell` unless they have `creates` or `removes`.

`command` and `shell` are the usual idempotency breakers: Ansible cannot know what a command
line does, so it reports `changed` every time. Prefer a module that manages the state; if a
command is unavoidable, add `creates`/`removes` or `changed_when`.

## CIS background

The CIS Benchmarks are configuration baselines per operating system; lesson L01 covers their
structure, levels and profiles. Two ideas from them already matter here:

- **Every package is attack surface.** CIS recommends removing software a system does not need.
  Ansible needs Python on the managed host, so installing it is a conscious trade-off for
  manageability - document it, or stay with `raw`/`script` where Python is not acceptable.
  The same applies to the managed-node account: passwordless sudo for `ansible` is a privileged
  path into every host and must be protected like one (key handling, who can use the control
  node). Privilege escalation is control 5.2 in [the control catalogue](../../cis/controls.yml).
- **Do not hand out free reconnaissance.** Control 1.6 (Level 1) asks for login banners that warn
  about authorised use and reveal nothing about the operating system or its version. Exercise
  0.04 is the first hardening change of the lab and starts there.

From now on every hardening task is checked twice: does it reach the required state, and is
the second run quiet? A playbook that "fixes" a host on every run hides real drift.

## Platform differences

| os_family | Hosts | Python in the lab image | `pkg_mgr` | `service_mgr` |
|---|---|---|---|---|
| Debian | debian, ubuntu | yes | apt | systemd |
| RedHat | rocky, alma, fedora | yes | dnf (Fedora: dnf5) | systemd |
| Suse | opensuse | yes | zypper | systemd |
| Alpine | alpine | **no** (bootstrap in 0.02) | apk | openrc |
| Archlinux | arch | yes | pacman | systemd |

The family is the dimension along which package names, service names, file locations and
defaults differ - that is why the inventory groups by it. Note that a family is not one
system: Ubuntu is in the Debian family, Fedora uses a different `pkg_mgr` value than Rocky and
Alma. `ansible.builtin.package` and `ansible.builtin.service` pick the right backend module
from these facts.

### In the lab containers

- The targets run their real init system as PID 1 (systemd, OpenRC on Alpine) in privileged
  containers, so services, sshd and sudo behave like on a VM.
- All targets share the kernel of the Docker host: the `kernel` fact is the same on every target.
  On native Linux it is the host's own kernel; with Docker Desktop (macOS, Windows) or WSL2 it
  is the kernel of the Linux VM that runs Docker. Kernel-wide settings are therefore configured
  but not applied in the lab - see [container limits](../CONTAINER_LIMITS.md).
- Some facts are incomplete in containers. For example `ansible_facts['mounts']` has no entry
  for the overlay root filesystem; exercise 5.02 comes back to this.
- Alpine ships without Python on purpose: minimal images, appliances and network devices often
  lack it, and bootstrapping is a skill you need in practice.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `ping` fails although SSH to the host works | `ping` is a Python module, the host has no usable Python | bootstrap Python with `raw`, or manage the host with `raw`/`script` only |
| A play fails at "Gathering Facts" before your first task | fact gathering runs `setup`, which needs Python | `gather_facts: false` for the bootstrap play |
| A task is `changed` on every run | `raw`, `command` or `shell` cannot judge their effect | use a state module, or `creates`/`removes`/`changed_when` |
| A file gets odd permissions such as `1204` | `mode: 644` is the YAML integer 644, which Ansible reads as decimal | always quote modes: `mode: "0644"` |
| Settings in your own `ansible.cfg` have no effect | `ANSIBLE_CONFIG` is set in the lab and wins over `./ansible.cfg` | use command-line options or play keywords, or `ANSIBLE_CONFIG=./ansible.cfg` for one command |
| `hostvars['x']['ansible_facts']` is undefined | no play in this run gathered facts for `x` | gather facts for those hosts first (or use a fact cache) |
| "Permission denied" when writing to `/etc` | task runs as `ansible` | `become: true` on the play or task |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [0.01](../../exercises/stage0-foundations/0.01-lab-tour/README.md) | lab architecture, inventory, patterns, ad-hoc commands, why a module run fails |
| [0.02](../../exercises/stage0-foundations/0.02-bootstrap-alpine/README.md) | `raw`, fact gathering needs Python, `become`, `changed_when` |
| [0.03](../../exercises/stage0-foundations/0.03-facts-report/README.md) | facts, `ansible_facts`, `hostvars`, `groups`, when facts of other hosts exist |
| [0.04](../../exercises/stage0-foundations/0.04-first-playbook-banner/README.md) | desired state, idempotency, quoted modes, `--check --diff`, CIS 1.6 |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A host accepts your SSH login, but `ansible <host> -m ansible.builtin.ping` fails. What is
   the most likely reason, and which module would still work?

   <details><summary>Answer</summary>

   `ping` is a Python module, not ICMP: it needs a usable Python interpreter on the target.
   SSH works, so the transport is fine - Python is missing or not found. `ansible.builtin.raw`
   (and `script`) still work because they only send a command over SSH.

   </details>

2. You want to run a command on all targets except the Debian family. How do you write the
   pattern, and how do you verify it without touching any host?

   <details><summary>Answer</summary>

   `'targets:!debian_family'` (quoted, because `!` means something to the shell).
   `ansible 'targets:!debian_family' --list-hosts` resolves the pattern against the inventory
   and prints the hosts without connecting.

   </details>

3. You put an `ansible.cfg` with `forks = 1` into `/lab/work/demo/` and run your playbook from
   there. Nothing changes. Why?

   <details><summary>Answer</summary>

   Ansible reads exactly one configuration file, and the environment variable `ANSIBLE_CONFIG`
   comes first in the search order. The lab sets it to `/lab/ansible/ansible.cfg`, so the file
   in the current directory is ignored. Use `--forks 1`, or set `ANSIBLE_CONFIG` for that command.

   </details>

4. A task uses `ansible.builtin.command` to run a tool that changes nothing, and every run shows
   `changed`. Why, and what are the options?

   <details><summary>Answer</summary>

   Ansible cannot know what an arbitrary command line does, so `command` always reports
   `changed`. For a read-only command add `changed_when: false`. If the command creates a file,
   `creates:` lets Ansible skip it once the file exists. Best of all is a module that manages
   the state directly.

   </details>

5. A play on `localhost` reads `hostvars['rocky']['ansible_facts']['distribution']` and gets an
   undefined-variable error. What is missing?

   <details><summary>Answer</summary>

   Facts are gathered per host, and a play on `localhost` gathers only the facts of
   `localhost`. The facts of `rocky` exist only if a play in the same run (or a configured fact
   cache) gathered them. Without that, `hostvars['rocky']` has inventory variables but no
   `ansible_facts`.

   </details>

6. All eight targets report the same `kernel` fact although they run five different
   distributions. Why, and what follows for kernel-related hardening in the lab?

   <details><summary>Answer</summary>

   Containers do not have their own kernel; they all use the Docker host's kernel. Settings
   that are not namespaced (kernel modules, many sysctls, the audit subsystem) would change the
   host, so the lab only writes their configuration files and does not apply them.

   </details>

7. Why does a hardening playbook have to report `changed=0` on its second run?

   <details><summary>Answer</summary>

   It describes a state; once the state is reached, there is nothing left to do. A playbook
   that reports changes on every run cannot be used to detect drift, makes `--check` useless as
   a compliance test and often really rewrites something each time (restarting services,
   resetting timestamps).

   </details>

## Further reading

- [How to build your inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html) and [Patterns: targeting hosts and groups](https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html)
- [Introduction to ad hoc commands](https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html)
- [Discovering variables: facts and magic variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_vars_facts.html)
- [Validating tasks: check mode and diff mode](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html)
- [`ansible.builtin.raw` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/raw_module.html) and [Interpreter discovery](https://docs.ansible.com/ansible/latest/reference_appendices/interpreter_discovery.html)
- [Ansible configuration settings](https://docs.ansible.com/ansible/latest/reference_appendices/config.html) - search order of `ansible.cfg`
- `man 5 sshd_config` (`Banner`), `man 5 issue`
