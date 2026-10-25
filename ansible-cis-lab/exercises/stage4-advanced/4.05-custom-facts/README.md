# 4.05 - Custom facts: hosts that describe their own hardening

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★☆☆ | ~45 min | (operations) (-) | `targets` |

**Concepts:** `facts.d`, `static vs executable facts`, `ansible_local`, `no timestamps in managed files`

## Goal

Make every host carry facts about its hardening (static: baseline name/version/level; dynamic: live security indicators) that any later play - or AWX/AAP inventory - can read via `ansible_local`.

## Background

Files in `/etc/ansible/facts.d/*.fact` are picked up by fact gathering:
- **static**: JSON or INI content → `ansible_local.<name>`,
- **executable** (mode 0755): run at gather time, must print JSON.
Static facts record *what was applied*; executable facts measure *what is true now*.

## Requirements

- [ ] `/etc/ansible/facts.d/cis.fact` (`0644`): JSON with `baseline` (`lab-cis`), `version` (`1.0.0`), `level` (`1`), `managed_by` (`ansible`).
- [ ] `/etc/ansible/facts.d/cis_live.fact` (`0755`, POSIX `sh`, works on busybox too): prints JSON with `uid0_accounts` (number) and `permit_root_login` (string from `sshd -T`).
- [ ] After deploying, re-gather facts in the same play (`ansible.builtin.setup` with `filter: ansible_local`).
- [ ] A second play on `localhost` writes `/lab/work/4.05/inventory.md`: one row per host with baseline version, level, uid0_accounts, permit_root_login.
- [ ] Second run: `changed=0` on the targets - so: **no timestamp** in `cis.fact`.

## How to work

```bash
lab start 4.05            # creates /lab/work/4.05/
cd /lab/work/4.05
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 4.05            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.05 1` (gentle) ... `lab hint 4.05 3` (almost the answer).  
Passed? Read `lab explain 4.05` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Where do these facts show up in AWX/AAP (host details) and how could a smart inventory filter use them?
- An executable fact that takes 10 seconds slows down *every* play on that host. How would you protect against that?
