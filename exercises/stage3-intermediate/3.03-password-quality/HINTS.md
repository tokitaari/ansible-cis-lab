# 3.03 - Password quality with pam_pwquality

## Hint 1

Template the drop-in from a dict: `{% for k, v in cis_pwquality.items() %}{{ k }} = {{ v }}\n{% endfor %}` plus a literal `enforce_for_root` line (it is a flag without value).

## Hint 2

For the PAM verification: `slurp` the stack file, then a conditional `command: pam-auth-update --enable pwquality` when `'pam_pwquality' not in content`. On Red Hat, `command: authselect current` with `changed_when: false` - report what profile is active.

## Hint 3

Use a dict for the stack file per family: `{Debian: /etc/pam.d/common-password, RedHat: /etc/pam.d/system-auth}`. Reference: `lab solution 3.03`.
