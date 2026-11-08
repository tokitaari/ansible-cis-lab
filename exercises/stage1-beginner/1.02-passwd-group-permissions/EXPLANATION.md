# 1.02 - Permissions on /etc/passwd and /etc/group: Explanation

### What the check verifies
`lab check 1.02` runs `check.yml` on `targets`: it runs `stat` on `/etc/passwd` and `/etc/group`
and asserts for both `mode == '0644'`, owner `root` and group `root`. Then it runs your playbook
once more with `--check` and expects `changed=0`.

- The check wants **exactly** `0644`. CIS allows "0644 or stricter", but `0600` fails here.
- It does not look at the backup files `/etc/passwd-` and `/etc/group-` (bonus 1).
- It does not test which module you used, only the resulting state.

### How it works

#### `file` changes attributes
Without `state`, `ansible.builtin.file` uses `state: file`: it expects the path to exist and only
adjusts owner, group and mode. A second run reports `ok`. Measured with the reference solution:
`changed=2` on every host in the first run, `changed=0` in the second, and the backup files
stay as they were (see the table below).

#### The mode is a string
The mode goes through YAML first:

| You write | YAML sees | Result |
|---|---|---|
| `mode: "0644"` | string | `rw-r--r--` ✔ |
| `mode: 0644` | octal integer (YAML 1.1) | works; `ansible-lint` reports `yaml[octal-values]` |
| `mode: 644` | decimal 644 = octal 1204 | `-w----r-T` ✘; `ansible-lint` reports `risky-octal` |

An ad-hoc `-a mode=644` is passed as a string and does not show the problem, only a playbook
does. Without any `mode`, `ansible-lint` reports `risky-file-permissions`. The lab output
(`callback_result_format = yaml`) prints the value as `mode: '0644'`.

#### Symbolic modes
`mode: "u=rw,go=r"` has the same bits and documents the intent. `go-w` removes bits without
touching the others, which fits "at most 0644" - but the result then depends on the start state,
and the lab check still wants exactly `0644`.

#### `state: touch` and `state: file`
`touch` sets the timestamps on every run, so it is `changed` every time and never idempotent. It
also creates a missing file. `state: file` fails on a path that does not exist, which is the
right behaviour for files that must be there.

### Per-family notes
At the start of the lab the two files are `0664` on all eight hosts. The backups differ:

| Host | `/etc/passwd-` | `/etc/group-` |
|---|---|---|
| debian | 664 | 644 |
| ubuntu | 664 | 664 |
| rocky | 664 | 644 |
| alma | 644 | 644 |
| fedora | 664 | 664 |
| opensuse | 644 | 644 |
| arch | 644 | 644 |
| alpine | 644 | 644 |

The reference solution does not change the backups.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `-w----r-T` after `mode: 644` | YAML reads 644 as decimal | quote it: `"0644"` |
| `lab check` fails on a stricter mode | check wants exactly `0644` | set `0644` |
| Backups still `0664` | the solution only touches the two main files | bonus 1: add them |
| `state: file` fails | the path does not exist | on hosts without the backup, check with `stat` first |

### Real-world notes
- A group-writable `/etc/passwd` lets group members add a UID-0 account. That is why CIS names
  these files.
- Backups can be missing on a real host. Check with `stat` and use `when`, as in the bonus.

### Further reading
- Lesson [L02 - Safe changes](../../../docs/lessons/L02-safe-changes.md): `--check --diff` before a change, and what check mode can predict.
- Lesson [L03 - Base hardening](../../../docs/lessons/L03-base-hardening.md): packages, services, files, SSH and sudo in one place.
- Exercise [1.01 - Remove insecure client packages](../1.01-remove-telnet/README.md)
- Exercise [2.01 - /etc/shadow: correct permissions per OS family](../../stage2-building-blocks/2.01-shadow-permissions-per-family/README.md)

## Reference solution

Show it with `lab solution 1.02`, apply it with `lab solve 1.02`.
