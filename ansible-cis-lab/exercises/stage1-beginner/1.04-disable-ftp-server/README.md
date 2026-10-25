# 1.04 - Stop and disable the FTP server

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 1 - Beginner | ★★☆☆☆ | ~25 min | 2.1 Server services (L1) | `targets` |

**Concepts:** `service`, `package_facts`, `when`, `systemd vs OpenRC`

## Goal

`vsftpd` is installed and enabled on most targets. Make sure it is neither running nor started at boot.

## Background

Every listening service is attack surface. CIS: services that are not needed must
be removed or at least stopped and disabled/masked. `ansible.builtin.service`
abstracts systemd *and* OpenRC - one task for all eight hosts. But: on a host
where `vsftpd` is not installed, the service module fails ("Could not find the
requested service"). That is your first real conditional.

## Requirements

- [ ] On every host that has the package `vsftpd`: service stopped and not enabled.
- [ ] Hosts without `vsftpd` are skipped, not failed.
- [ ] Use `ansible.builtin.package_facts` + `when`.
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 1.04            # creates /lab/work/1.04/
cd /lab/work/1.04
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 1.04            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 1.04 1` (gentle) ... `lab hint 1.04 3` (almost the answer).  
Passed? Read `lab explain 1.04` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- CIS prefers *removing* the package. Add a second task that removes `vsftpd`. Why is the order of the two tasks irrelevant here - or is it?
- systemd hosts only: `masked: true` (needs `ansible.builtin.systemd_service`). What is the difference to `enabled: false`?
