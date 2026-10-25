# 4.03 - Data-driven role for all platforms (incl. Alpine)

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★☆ | ~120 min | Sections 1-7 (L1 (+L2 auditd)) | `targets` |

**Concepts:** `first_found variable hierarchy`, `feature flags instead of os_family checks`, `Alpine/OpenRC`, `regression testing`

## Goal

Integrate stage 3 (password policy, PAM, accounts, auditd) into your `cis` role so that it runs on all eight platforms - with **zero** `os_family ==` conditions in the task files.

## Background

Every `when: ansible_facts.os_family == 'Debian'` in a task file is a small debt: the
next platform means editing logic. Mature roles express platform differences as
**data and feature flags**:

```yaml
# vars/Alpine.yml
cis_pam_tool: none           # instead of: when: os_family != 'Alpine'
cis_pwquality_supported: false
cis_cron_allow_supported: false
```
Tasks then ask *capability* questions: `when: cis_pwquality_supported`.

A four-level lookup lets you override per distribution and version without copying:
`Rocky-10.yml` → `Rocky.yml` → `RedHat.yml` → `default.yml`.

## Requirements

- [ ] Extend `/lab/work/roles/cis` with `section5_password_policy.yml` (3.02), `section5_pam.yml` (3.03), `section5_accounts.yml` (3.05), `section6_logging.yml` (3.04, only when `cis_level >= 2`).
- [ ] Platform vars are loaded with `first_found` over `<distribution>-<major>.yml`, `<distribution>.yml`, `<os_family>.yml`, `default.yml`.
- [ ] No task file under `tasks/` contains `os_family ==`, `os_family !=`, `distribution ==` or similar fact comparisons - use flags/values from `vars/`.
- [ ] `/lab/work/4.03/site.yml` bootstraps Python on Alpine (pre-play) and applies the role to all targets.
- [ ] After **one** run on freshly reset hosts (`./lab.sh reset all`) the checks of 0.04-2.06 and 3.02, 3.03, 3.05 pass; with `-e cis_level=2` also 3.04. Second run: `changed=0`.
- [ ] `ansible-lint --offline` passes on the role.

## How to work

```bash
lab start 4.03            # creates /lab/work/4.03/
cd /lab/work/4.03
# write site.yml, then run it:
ansible-playbook site.yml
lab check 4.03            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.03 1` (gentle) ... `lab hint 4.03 3` (almost the answer).  
Passed? Read `lab explain 4.03` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Add `vars/Ubuntu.yml` that only overrides one value (e.g. disables `cis_cron_allow_supported` for a test) and prove with `ansible-inventory`/`debug` that Debian still uses `Debian.yml`. Then delete it again.
- Add a ninth platform on paper: what would a `vars/Gentoo.yml` need? Which tasks would break anyway?
