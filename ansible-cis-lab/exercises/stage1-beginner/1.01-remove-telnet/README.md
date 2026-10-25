# 1.01 - Remove insecure client packages

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 1 - Beginner | ★☆☆☆☆ | ~20 min | 2.2 Client services (L1) | `targets` |

**Concepts:** `package`, `state: absent`, `package_facts`, `--check --diff`

## Goal

Remove the `telnet` client from every target that has it.

## Background

Telnet transmits everything - including passwords - in clear text. CIS lists a
number of legacy clients (telnet, rsh, talk, ftp, NIS) that should not be
installed. The generic `ansible.builtin.package` module picks the right package
manager (`apt`, `dnf`, `zypper`, `pacman`, `apk`) on its own.

## Requirements

- [ ] One play for `targets` with `become: true`.
- [ ] Package `telnet` is absent on all hosts.
- [ ] Use `ansible.builtin.package` - not `apt`/`dnf`/`shell`.
- [ ] Hosts that never had telnet must not fail.
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 1.01            # creates /lab/work/1.01/
cd /lab/work/1.01
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 1.01            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 1.01 1` (gentle) ... `lab hint 1.01 3` (almost the answer).  
Passed? Read `lab explain 1.01` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Before you run it: `ansible-playbook playbook.yml --check --diff`. Which hosts *would* change?
- On Debian/Ubuntu `telnet` may only be a transitional package. Is `/usr/bin/telnet` really gone? (`ansible debian_family -m ansible.builtin.command -a 'which telnet'`) What else would you have to remove?
- Extend the list with `rsh-client`, `talk`, `ftp`. What happens if a name does not exist on a distribution?
