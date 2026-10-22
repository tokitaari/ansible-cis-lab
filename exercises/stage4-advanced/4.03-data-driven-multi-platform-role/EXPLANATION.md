# 4.03 - Data-driven role for all platforms (incl. Alpine): Explanation

### Data beats branches
Compare:
```yaml
# branchy
- when: ansible_facts.os_family in ['Debian', 'RedHat']
# data-driven
- when: cis_pwquality_supported
```
The second version says *why* the task runs. Supporting a new platform becomes a
vars file and a review of the flags - no edits in task logic, no risk for existing
platforms.

### The variable hierarchy
`first_found` returns the most specific existing file. Typical use:
- `Rocky-9.yml` vs `Rocky-10.yml` for version differences (e.g. crypto policies),
- `Ubuntu.yml` for Ubuntu-only behaviour within the Debian family (snaps, `ssh.socket`),
- `default.yml` with conservative values so an unknown platform does not crash.
Note: it loads **one** file. If you want layering (family + distribution), use two
`include_vars` calls, family first.

### Alpine as a first-class citizen
Alpine forces the honest questions: no PAM (no pwquality), busybox crontab (no
cron.allow), OpenRC (different service names), no Python until bootstrapped. Each
becomes a flag with a comment explaining the compensating control or documented gap.

### Regression testing
You just changed a role that hardens eight platforms. The earlier checks are your
safety net - run them after every refactor (`lab check 4.03` does it for you).

## Reference solution

Show it with `lab solution 4.03`, apply it with `lab solve 4.03`.
