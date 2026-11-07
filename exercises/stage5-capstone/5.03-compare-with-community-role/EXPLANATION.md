# 5.03 - Review: your role vs. a community CIS role: Explanation

### What the check verifies
`lab check 5.03` runs `check.sh` only. It looks for `/lab/work/5.03/review.md`, for a line that
starts the answer to each question 1 to 6 (`1.`, `1)`, `1:`, `## 1.`, `Q1:` or `Frage 1:`; a bare
`## 1` or `**1.**` does not count) and for at least 300 words. It does not read the content, run
the role or verify a single fact. `lab solve 5.03` only prints that there is no reference
solution, and `solution/NOTES.md` says the same: the real check is the discussion with a
colleague.

### How it works

#### What to look for in any third-party hardening role
- **Toggle granularity**: one variable per control is essential - you *will* need exceptions.
- **Disruptive controls**: good roles mark them (often a `disruption_high`-style switch) and
  keep them off by default. Firewall, PAM, mount options, SELinux/AppArmor enforcement, GRUB
  passwords are typical.
- **Audit capability**: separate audit tooling gives an independent second opinion - your
  check-mode approach uses the same code for both, which is simpler but not independent.
- **Benchmark version tracking**: does the role say which CIS benchmark version it implements?
  Do release notes map changes to control ids?
- **Test matrix**: which OS versions and scenarios are tested in CI?

#### Reading a role without running it
Read in this order. The defaults show which knobs exist and how they are named; `tasks/` shows
the structure; a search for `command`, `shell` and `raw` finds the tasks that know nothing
about idempotency or check mode; `meta/` shows dependencies that install more roles; handlers
show service restarts. Then let Ansible tell you what the role would do:
`ansible-playbook site.yml --list-tasks --list-tags`, `--syntax-check`, and `--check --diff`
against one freshly reset host (L14 explains the limits of check mode).

#### Build vs adopt - a typical conclusion
Adopting a maintained role saves enormous effort on coverage; your value moves to
*configuration* (which controls, which exceptions), *testing* (a lab like this) and
*operations* (rollout, reporting). Building your own makes sense for small scopes, unusual
platforms (like Alpine here), or when you need full control over every line. Many teams do
both: adopt, wrap it in their own role for org-specific settings and reporting, and contribute
fixes upstream.

#### Never run unreviewed
A hardening role is root-level code that touches authentication and networking on every server.
Review it like a kernel patch for production - your lab is the place to do that safely.

### Measured example: two ansible-lockdown roles
Read in the code on 2026-11-07, at the tags `RHEL10-CIS` 1.1.2 (commit
`71d291ea07be450aee602e858b7288452fb27b56`, 2026-10-16) and `UBUNTU24-CIS` 1.8.0 (commit
`3a2f05b9a8040eb869fd14fdca882aae4f68733b`, 2026-10-22). Roles move on: look again before you
rely on a detail. These are facts, not answers to your questions.
- **Switches:** `RHEL10-CIS` has 328 variables `rhel10cis_rule_*`, one per rule, all `true`, and
  seven section switches `rhel10cis_section1` to `7`; the comment in the defaults says a rule
  switch works only while its section is on. Variables such as `rhel10cis_avahi_server` or
  `rhel10cis_nfs_server` say whether *you use* a service; the removal tasks act on `not
  rhel10cis_avahi_server`, and with the default `true` for NFS the NFS control does nothing.
- **Disruption:** `rhel10cis_disruption_high: false` appears in 45 task conditions, for example
  the firewalld zone tasks (4.1.x) and the authselect/PAM tasks (5.3.x).
- **Levels and profiles:** every task carries tags such as `level1-server` or
  `level2-workstation`, and the README says the profiles are managed with tags; the defaults
  have `rhel10cis_level_1` and `_2`, which the comment ties to the audit.
- **Check mode:** the README of both roles says the role completes in check mode without
  errors, but check mode is not supported.
- **Audit:** `run_audit` and `setup_audit` are `false` by default in both roles (`audit_only` in
  `RHEL10-CIS`); the checks come from a separate audit repository and run with a small binary -
  `goss` in `UBUNTU24-CIS`, `syver` (a signed goss fork that reads the same content) in
  `RHEL10-CIS`.

### Per-family notes
Which lab platform has a matching role? Probed on 2026-11-07 by repository name in the
`ansible-lockdown` organisation (not exhaustive: a role may exist under another name or not be
public).

| os_family | Hosts | Community role found | Notes |
|---|---|---|---|
| Debian | debian, ubuntu | `DEBIAN13-CIS` 1.1.0, `UBUNTU26-CIS` 0.9.0 | the lab runs Debian 13 and Ubuntu 26.04; `UBUNTU24-CIS` 1.8.0 is the older release |
| RedHat | rocky, alma, fedora | `RHEL10-CIS` 1.1.2 | `meta/main.yml` lists rocky and alma; no role found for fedora |
| Suse | opensuse | none found | no public repository named `SLES15-CIS`, `SLES16-CIS`, `SLE16-CIS` or `OPENSUSE-CIS` |
| Archlinux | arch | none found | - |
| Alpine | alpine | none found | the case for building your own |

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `lab check 5.03` misses question 3 although you answered it | the line does not start with a number and `.`, `)` or `:` (`## 3`, `**3.**`) | start the line with `3.` or `## 3.` |
| `lab check 5.03` says "only N words" | the review has fewer than 300 words | add the reasoning, not filler |
| the role "works" in `--check` and changes a lot in enforce mode | check mode is not supported or skips `command` tasks | read the tasks, do not trust the dry run alone |
| a rule switch has no effect | its section switch is off | set both |
| a control does nothing by default | the variable names a service you use (`..._nfs_server: true`) | read what the default means before you "fix" it |

### Real-world notes
- Pin the role to a tag or a commit and read the diff of every update; benchmarks and roles move
  to new versions.
- A fork needs a merge routine; an adopted role needs a place for your exceptions (a wrapper
  role or inventory variables).
- Your acceptance tests are the lab idea at scale: a throw-away host per platform, check mode
  plus an independent audit, then a canary.

### Further reading
- Lesson [L14 - Production rollout](../../../docs/lessons/L14-production-rollout.md): where community roles come from, pinning, reading a role without running it, adopt, fork or build.
- Lesson [L01 - CIS Benchmarks](../../../docs/lessons/L01-cis-benchmarks.md): levels, profiles and why recommendation numbers move.
- Lesson [L11 - Profiles, exceptions and data-driven roles](../../../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.md): the exception design you compare against.

## Reference solution

Show it with `lab solution 5.03`, apply it with `lab solve 5.03`.
