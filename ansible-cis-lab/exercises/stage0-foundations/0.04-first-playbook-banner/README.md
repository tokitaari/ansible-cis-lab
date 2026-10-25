# 0.04 - First hardening playbook: SSH warning banner

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 0 - Foundations | ★☆☆☆☆ | ~20 min | 1.6 Command line warning banners (L1) | `targets` |

**Concepts:** `playbook`, `copy`, `mode/owner`, `idempotency`

## Goal

Replace the banner in `/etc/issue.net` that currently leaks OS details with a neutral legal warning.

## Background

Look at it first: `ansible targets -m ansible.builtin.command -a 'cat /etc/issue.net'`.
It contains the distribution name and the escape sequences `\r` (kernel release) and
`\m` (architecture). Attackers love free reconnaissance. CIS requires banners that
warn about authorised use and contain **no** OS or version information.

## Requirements

- [ ] Write `playbook.yml` that targets `targets` and uses privilege escalation.
- [ ] `/etc/issue.net` contains a warning that includes the word **authorized** (any case).
- [ ] No OS information: none of `\m`, `\r`, `\s`, `\v` and no distribution name.
- [ ] Owner `root`, group `root`, mode `0644`.
- [ ] Running the playbook twice shows `changed=0` the second time.

## How to work

```bash
lab start 0.04            # creates /lab/work/0.04/
cd /lab/work/0.04
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 0.04            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 0.04 1` (gentle) ... `lab hint 0.04 3` (almost the answer).  
Passed? Read `lab explain 0.04` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Run with `--check --diff` before applying. What does `--diff` show you?
- Apply the same banner to `/etc/issue` (local console login).
