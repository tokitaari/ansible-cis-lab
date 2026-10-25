# 5.03 - Review: your role vs. a community CIS role: Explanation

### What to look for in any third-party hardening role
- **Toggle granularity**: one variable per control is essential - you *will* need
  exceptions.
- **Disruptive controls**: good roles mark them (often a `disruption_high`-style
  switch) and keep them off by default. Firewall, PAM, mount options, SELinux/AppArmor
  enforcement, GRUB passwords are typical.
- **Audit capability**: separate audit tooling (e.g. goss-based) gives an independent
  second opinion - your check-mode approach uses the same code for both, which is
  simpler but not independent.
- **Benchmark version tracking**: does the role say which CIS benchmark version it
  implements? Do release notes map changes to control ids?
- **Test matrix**: which OS versions and scenarios are tested in CI?

### Build vs adopt - a typical conclusion
Adopting a maintained role saves enormous effort on coverage; your value moves to
*configuration* (which controls, which exceptions), *testing* (a lab like this), and
*operations* (rollout, reporting). Building your own makes sense for small scopes,
unusual platforms (like Alpine here), or when you need full control over every line.
Many teams do both: adopt, wrap it in their own role for org-specific settings and
reporting, and contribute fixes upstream.

### Never run unreviewed
A hardening role is root-level code that touches authentication and networking on
every server. Review it like you would review a kernel patch for production - your
lab is the place to do that safely.

## Reference solution

Show it with `lab solution 5.03`, apply it with `lab solve 5.03`.
