# 0.03 - Facts: one report across eight distributions: Explanation

### What the check verifies
`lab check 0.03` runs `check.yml` on the control node and asserts for
`$LAB_WORK_DIR/0.03/facts.csv`:
- the file exists and its first line is exactly
  `host,distribution,version,os_family,pkg_mgr,service_mgr,python`;
- there are 8 data lines with 7 fields each, and the first column is exactly the set of
  `groups['targets']`;
- the `alpine` line contains `,openrc,` and no line contains `unreachable`.

Then it runs your playbook once more with `--check` and expects `changed=0` (`meta.yml` says
`idempotency: true`). Unlike 0.02 this is a real test: `setup`, `file` and `template` all support
check mode.

It does not test the values or how the file was made. A hand-typed file with made-up values
(`x` for the distribution, `3` for Python) passes, and so do rows in reverse order (measured with
the real `check.yml`). The README's "no shell `echo >>`" and the sorting bonus are therefore on
your honour.

### How it works

#### Why two plays
Facts are gathered *per host*, but the report needs *all* of them in one place. Play 1 on
`targets` fills `hostvars`, play 2 on `localhost` reads it and writes the file on the control
node. A single play also works: gather facts for all hosts, then one task with `delegate_to:
localhost` and `run_once: true` renders the template (measured with two hosts: the task shows
`changed: [a -> localhost]`, the second run is `ok`). Two plays are clearer to read.

#### Reading facts
`hostvars[h]['ansible_facts']` holds the facts of host `h` without the `ansible_` prefix:
`distribution`, `distribution_version`, `os_family`, `pkg_mgr`, `service_mgr`, `python_version`.
`python_version` is the version of the interpreter Ansible used on that host.

#### What a missing fact looks like
A host that did not deliver facts is either `UNREACHABLE` (no SSH connection) or `FAILED` (for
example Alpine without Python, see 0.02). In both cases it was in play 1 and its `ansible_facts`
is an empty dict (measured with ansible-core 2.21.6). Reading `f.distribution` then stops play 2:

```
object of type 'dict' has no attribute 'distribution'
```
The reference template avoids that with `f.get('distribution', 'unreachable')` and `| default({})`:
`.get()` covers the empty dict, `default({})` covers a host that was in no play at all (then
`ansible_facts` is undefined, see L00). The placeholder word `unreachable` is used for both
cases, including the failed Alpine; the check rejects it either way.

#### Template details
`template` renders with `trim_blocks=True` and `lstrip_blocks=False` (module defaults, measured),
so `{% ... %}` lines at the start of a line leave no blank lines. Sorting the loop with
`groups['targets'] | sort` gives a stable order and an idempotent file. The solution creates the
directory (`0755`) and the file (`0644`) on the control node.

### Per-family notes
Measured on the lab images of 2026-11-07, after 0.02:

| `os_family` | Hosts: `distribution` `distribution_version` | `pkg_mgr` | `service_mgr` | `python_version` |
|---|---|---|---|---|
| Debian | debian: Debian 13.7; ubuntu: Ubuntu 26.04 | apt | systemd | 3.13.5 (debian), 3.14.4 (ubuntu) |
| RedHat | rocky: Rocky 10.2; alma: AlmaLinux 10.2; fedora: Fedora 44 | dnf (rocky, alma), dnf5 (fedora) | systemd | 3.12.15 (rocky, alma), 3.14.10 (fedora) |
| Suse | opensuse: openSUSE Leap 16.0 | zypper | systemd | 3.13.14 |
| Archlinux | arch: Archlinux 20261101.0.620205 | pacman | systemd | 3.14.9 |
| Alpine | alpine: Alpine 3.24.3 | apk | openrc | 3.14.10 |

Fedora's `dnf5` shows that one family can have two package managers - that is why
`ansible.builtin.package` (it picks the right backend) is useful. Ubuntu is in the Debian family.
Arch is a rolling release: its "version" is a build id.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `object of type 'dict' has no attribute 'distribution'` | a host of play 1 failed or was unreachable, its `ansible_facts` is `{}` | `f.get('distribution', ...)` instead of `f.distribution` |
| The `alpine` line says `unreachable` and the check asks "did every host deliver facts?" | Python is missing on Alpine, the host failed at "Gathering Facts" | do 0.02 first |
| `hostvars['x']['ansible_facts']` is undefined | `x` was in no play of this run | gather facts for `x` first, or `default({})` |
| "Premature end of stream waiting for become success" / `sudo: not found` | `become: true` copied into the `localhost` play: the control container has no `sudo`, the user `learner` is unprivileged | no `become` in play 2 - it only writes below `/lab/work` |
| The check passes with a hand-typed file | the check tests the shape, not the values | build the file with the template |

### Real-world notes
The same technique produces inventory reports, patch-level overviews and the compliance reports of
later exercises. For a large fleet a fact cache saves the gathering time; a report that must be
complete should say which hosts are missing instead of leaving them out.

### Further reading
- Lesson [L00 - Lab architecture and Ansible basics](../../../docs/lessons/L00-lab-and-ansible-basics.md): facts, `hostvars` and when the facts of other hosts exist.
- Exercise [0.02 - Bootstrap Python on Alpine with raw](../0.02-bootstrap-alpine/README.md): without it Alpine has no facts.
- Exercise [4.01 - Audit-only compliance report](../../stage4-advanced/4.01-audit-only-report/README.md): per-host results collected into one report on the control node.
- [Discovering variables: facts and magic variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_vars_facts.html) and [Controlling where tasks run: delegation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_delegation.html)
- [`ansible.builtin.template` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)

## Reference solution

Show it with `lab solution 0.03`, apply it with `lab solve 0.03`.
