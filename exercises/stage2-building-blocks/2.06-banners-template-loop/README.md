# 2.06 - All login banners from one template

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 2 - Building blocks | ★★☆☆☆ | ~25 min | 1.6 Command line warning banners (L1) | `targets` |

**Concepts:** `template in a loop`, `inventory variables`, `--diff`

## Goal

Manage `/etc/motd`, `/etc/issue` and `/etc/issue.net` from a single template that takes the organisation name from the inventory.

## Background

0.04 fixed one file with a hard-coded string. Real environments have three banner
files (message of the day, local console, remote login) and a legal text that comes
from someone else. The inventory already defines `lab_org_name` in
`group_vars/all.yml` - your template should use it.

## Requirements

- [ ] One template `templates/banner.j2` that includes `{{ lab_org_name }}` and the word *authorized*.
- [ ] One task with a `loop` deploys it to `/etc/motd`, `/etc/issue`, `/etc/issue.net` - `root:root`, `0644`.
- [ ] No OS information in any of the files (no `\m \r \s \v`, no distribution name).
- [ ] Second run: `changed=0`.

## How to work

```bash
lab start 2.06            # creates /lab/work/2.06/
cd /lab/work/2.06
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 2.06            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 2.06 1` (gentle) ... `lab hint 2.06 3` (almost the answer).  
Passed? Read `lab explain 2.06` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Override `lab_org_name` for one host only with `-e` or in `host_vars`, run with `--diff -l alpine`.
- On some distributions `/etc/motd` is generated dynamically (`/etc/update-motd.d` on Ubuntu, `/etc/motd.d` on Fedora). Do those directories exist here? What would you do about them?
