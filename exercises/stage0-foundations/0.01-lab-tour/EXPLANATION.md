# 0.01 - Lab tour: inventory and connectivity: Explanation

### What the check verifies
`lab check 0.01` runs `check.yml`. `meta.yml` says `idempotency: false`: the exercise changes
nothing, so there is no second run. The check asserts:
- `groups['targets']` has 8 hosts, `alpine_family` is exactly `['alpine']` and `redhat_family`
  has 3 hosts;
- every target except the Alpine family answers `ansible.builtin.ping`.

It does not test: the other family groups (`debian_family`, `suse_family`, `arch_family`), the
content of `notes.md`, and that Alpine fails. The check skips Alpine on purpose, so it passes on
a fresh lab and after 0.02 alike.

### How it works

#### The inventory as a tree
`ansible-inventory --graph` prints (measured on the lab):
```
@all:
  |--@ungrouped:
  |--@targets:
  |  |--@debian_family:
  |  |  |--debian
  |  |  |--ubuntu
  |  |--@redhat_family:
  |  |  |--rocky
  |  |  |--alma
  |  |  |--fedora
  |  |--@suse_family:
  |  |  |--opensuse
  |  |--@arch_family:
  |  |  |--arch
  |  |--@alpine_family:
  |  |  |--alpine
```
`@ungrouped` is built in and empty here. The grouping by OS family is deliberate: package names,
service names, file locations and defaults differ along exactly these lines.

#### What `--host` shows
`ansible-inventory --host debian` prints four variables: `ansible_user`,
`ansible_ssh_private_key_file` (both from `group_vars/targets.yml`), `lab_in_container` and
`lab_org_name` (from `group_vars/all.yml`). It shows *inventory* data after merging all groups,
not the settings of `ansible.cfg` - `remote_user` is not in the list. When "a variable has the
wrong value", this is the first look.

#### Patterns
`ansible 'targets:!alpine_family' --list-hosts` resolves to 7 hosts without connecting
anywhere. Quote the pattern: `!` means something to the shell. `redhat_family:&targets` is the
intersection, `debian:rocky` the union.

#### Why `ping` fails on Alpine
`ping` is a Python module, not ICMP. With `pipelining = True` (the lab's `ansible.cfg`) Ansible
does not copy a file to the target: it starts the Python interpreter over the SSH session and
feeds it the module code (`-vvv` shows no `PUT`, `sftp` or `scp` line). With
`interpreter_python = auto_silent` it searches the target for an interpreter. The seven other
hosts have one; the fresh Alpine image does not, and the fallback `/usr/bin/python3` fails:

```
msg: The module interpreter '/usr/bin/python3' was not found.
module_stderr: /bin/sh: /usr/bin/python3: not found
rc: 127
```
SSH itself works - only Python is missing. That is the difference between `FAILED` (connected,
module failed) and `UNREACHABLE` (no connection, for example no route or a wrong key).

#### What still works without Python
`ansible.builtin.raw` sends a command line over SSH and returns what it prints: the reference
solution reads `/etc/os-release` and finds `no python3`. `ansible.builtin.script` copies a local
script and runs it - on the fresh Alpine it ran as well (measured). Both are the tools to
bootstrap a host, which is 0.02.

#### Bonus: comparing the hosts
`setup -a 'filter=ansible_distribution*'` returns the same keys everywhere, with values that
differ: `ansible_distribution_version` is `13.7` on debian, `26.04` on ubuntu, `10.2` on rocky and
alma, `44` on fedora, `16.0` on opensuse, `3.24.3` on alpine - and `20261101.0.620205` on arch,
a rolling release with a build id instead of a version (its major version is `20261101`). Ubuntu
reports `ansible_distribution_file_variety: Debian`. This only works on Alpine after 0.02.

### Per-family notes
Interpreter that `ping` discovered (measured 2026-11-07, versions change with the image build):

| `os_family` | Hosts | Python for Ansible |
|---|---|---|
| Debian | debian, ubuntu | `/usr/bin/python3.13`, `/usr/bin/python3.14` |
| RedHat | rocky, alma, fedora | `/usr/bin/python3.12` (rocky, alma), `/usr/bin/python3.14` (fedora) |
| Suse | opensuse | `/usr/bin/python3.13` |
| Archlinux | arch | `/usr/bin/python3.14` |
| Alpine | alpine | none on a fresh lab (`/usr/bin/python3` not found); `/usr/bin/python3.14` after 0.02 |

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `ping` on alpine: "The module interpreter '/usr/bin/python3' was not found" | no Python in the fresh Alpine image | bootstrap it with `raw` (0.02) |
| No host fails at all | 0.02 was done before; Alpine now has Python | `./lab.sh reset alpine` on the host restores the failure |
| `lab check 0.01` passes although you did not read the error | the check does not test your findings | write them into `notes.md` for yourself |

### Real-world notes
In production the inventory also carries `ansible_host`, jump hosts
(`ansible_ssh_common_args`) and often comes from a dynamic source (Azure, AWS, Satellite). The
questions stay the same: what do I manage, and can I reach it? A reachability run with `ping`
before any change is cheap, and the split between `UNREACHABLE` and `FAILED` tells you whether
to look at the network or at the host.

### Further reading
- Lesson [L00 - Lab architecture and Ansible basics](../../../docs/lessons/L00-lab-and-ansible-basics.md): the concepts before this exercise (inventory, patterns, how a module runs).
- Exercise [0.02 - Bootstrap Python on Alpine with raw](../0.02-bootstrap-alpine/README.md): the fix for the failing host.
- [How to build your inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html) and [Patterns: targeting hosts and groups](https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html)
- [Interpreter discovery](https://docs.ansible.com/ansible/latest/reference_appendices/interpreter_discovery.html) and the [`ansible.builtin.raw` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/raw_module.html)

## Reference solution

Show it with `lab solution 0.01`, apply it with `lab solve 0.01`.
