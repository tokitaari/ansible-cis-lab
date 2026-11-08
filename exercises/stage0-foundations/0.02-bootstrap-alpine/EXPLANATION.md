# 0.02 - Bootstrap Python on Alpine with raw: Explanation

### What the check verifies
`lab check 0.02` runs `check.yml` on `alpine_family`: `ansible.builtin.ping` works (it needs
Python) and `python3 --version` prints a `Python 3` version. Then it runs your playbook once more
with `--check` and expects `changed=0` (`meta.yml` says `idempotency: true`).

**That second part cannot see your guard.** `raw` does not support check mode, so under `--check`
it is skipped (`skipping:`, recap `skipped=1`, measured on the lab) and only the `ping` runs. A
playbook without the shell guard, or with `changed_when: true`, passes `lab check` and still
reports `changed=1` on every real run (measured on a stand-in with a local connection: run 2
`changed=1`, `--check` run `changed=0`). The test that counts is your own second run:

```bash
ansible-playbook playbook.yml     # first run: changed=1 on alpine
ansible-playbook playbook.yml     # second run: changed=0
```
The check also does not require that `raw` was used: Python installed by hand passes.

### How it works

#### The pattern
```yaml
- name: Install python3 if missing
  ansible.builtin.raw: test -e /usr/bin/python3 || { apk add --no-cache python3 && echo INSTALLED; }
  register: bootstrap
  changed_when: "'INSTALLED' in bootstrap.stdout"
```
Two layers, both needed. The shell guard (`test -e ... ||`) makes the *command* idempotent. The
marker makes the *report* honest: `echo INSTALLED` runs only after `apk add` succeeded (`&&`), so
a failed install fails the task (non-zero return code) instead of printing the marker.
`changed_when` turns the marker into `changed`.

#### Why `gather_facts: false`
The implicit first task `setup` is a Python module. On a fresh Alpine the play stops before your
first task:

```
TASK [Gathering Facts]
fatal: [alpine]: FAILED! => ... The following modules failed to execute: ansible.legacy.setup.
```
The starter play has no `gather_facts: false` - run as it is, it fails here. Once Python is
installed, the later plays gather facts normally.

#### `become` and `raw`
`raw` goes through the connection like every module, including the privilege escalation: with
`become: true` Ansible wraps the command in `sudo -H -S -n -u root /bin/sh -c '...'` and runs it
over `ssh -tt` (measured with the lab's SSH options against a local sshd). The target therefore
needs `sudo` and a POSIX shell, not Python: on Alpine `/usr/bin/sudo` exists and `/bin/sh` is
BusyBox. `apk add` changes the system and needs root; the account `ansible` is unprivileged.

#### What `raw` returns
The output arrives with `\r\n` line endings (the tty from `-tt`), so compare with `in`, not `==`.
With the lab's `LogLevel=ERROR` the stderr stayed empty.

#### Why `--no-cache`
A fresh Alpine has no package index: `/var/cache/apk` is empty and a plain
`apk add --simulate jq` fails with `unable to select packages: jq (no such package)`.
`apk add --no-cache` fetches the index for that one call (the simulation lists 14 packages for
`python3`). The mirrors in `/etc/apk/repositories` must be reachable from the container
(`dl-cdn.alpinelinux.org`).

#### What Python costs on Alpine
`apk stats` before and after: 44 -> 58 packages and 22.4 MB -> 63.1 MB installed, so about
**40 MB** for Python 3.14 and its libraries; the `python3` package alone is 22 MiB. Python is
what Ansible needs on the managed host - a conscious trade-off, see the notes below.

#### Bonus: avoiding Python altogether
With `raw` and `script` alone you can run commands and scripts, but you lose everything that
needs the module machinery: facts, check mode, `template`, `copy`, `changed` reporting. `script`
runs on a host without Python (measured on the fresh Alpine). Pull-based tools or an image that
already ships Python are the alternatives.

### Per-family notes
The exercise runs on `alpine_family` only (one host), so there is no per-family table.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| The play fails at "Gathering Facts" with `ansible.legacy.setup` | no Python yet and facts are gathered by default | `gather_facts: false` |
| `ping`: "The module interpreter '/usr/bin/python3' was not found" | the bootstrap has not run | run the `raw` task first |
| `lab check` says "idempotent" but every run shows `changed=1` | `raw` is skipped in check mode | run the playbook twice yourself |
| The task is always `changed` | no guard, or `changed_when` without the marker | guard plus marker in the output |
| `unable to select packages` | no package index on the fresh host | `apk add --no-cache` |
| `bootstrap.stdout == 'INSTALLED'` never matches | `\r\n` in the `raw` output | `'INSTALLED' in bootstrap.stdout` |

### Real-world notes
CIS keeps asking to remove unnecessary packages. Python is necessary *for Ansible*, so it is a
trade-off: document it. Where it is not acceptable, stay with `raw` and `script` or use a
pull-based tool. On Alpine the cost is the 14 packages and about 40 MB measured above.

### Further reading
- Lesson [L00 - Lab architecture and Ansible basics](../../../docs/lessons/L00-lab-and-ansible-basics.md): how a module runs, `raw`, `changed_when`, check mode.
- Exercise [0.01 - Lab tour: inventory and connectivity](../0.01-lab-tour/README.md): where the failing `ping` comes from.
- Exercise [0.03 - Facts: one report across eight distributions](../0.03-facts-report/README.md): needs Python on Alpine.
- [`ansible.builtin.raw` module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/raw_module.html) and [`ansible.builtin.script` module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/script_module.html)
- [Alpine Package Keeper](https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper) (`apk`, `--no-cache`)

## Reference solution

Show it with `lab solution 0.02`, apply it with `lab solve 0.02`.
