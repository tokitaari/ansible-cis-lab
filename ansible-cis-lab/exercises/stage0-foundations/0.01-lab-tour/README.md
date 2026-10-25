# 0.01 - Lab tour: inventory and connectivity

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 0 - Foundations | ★☆☆☆☆ | ~15 min | - (-) | `targets` |

**Concepts:** `inventory`, `groups`, `ad-hoc`, `ping`

## Goal

Get to know the lab: which hosts exist, how they are grouped, and whether Ansible can manage them.

## Background

Ansible needs two things on a managed node: SSH access and a Python interpreter.
The inventory (`/lab/ansible/inventory/hosts.yml`) groups the eight targets by
OS family - the dimension that makes multi-distro hardening interesting. Every
hardening project starts with exactly this question: *what do I manage, and can I reach it?*

## Requirements

- [ ] Display the inventory as a tree (`ansible-inventory --graph`).
- [ ] Show all variables Ansible knows for host `debian` (`ansible-inventory --host debian`).
- [ ] Run the `ansible.builtin.ping` module against all targets with an ad-hoc command.
- [ ] Exactly one host fails. Find out which one and *why* (read the error message!). Don't fix it yet - that is 0.02.
- [ ] Write your findings into `/lab/work/0.01/notes.md` (not checked - for you).

## How to work

```bash
lab start 0.01
ansible-inventory --graph
ansible all -m ansible.builtin.ping      # or: ansible targets -m ...
lab check 0.01
```
Stuck? `lab hint 0.01 1`. Passed? `lab explain 0.01`.


## Bonus (optional)

- Run `ansible targets -m ansible.builtin.setup -a 'filter=ansible_distribution*'` and compare the hosts.
- Which ad-hoc module works on *every* host, even the failing one? (Hint: it does not need Python.)
