# 4.01 - Audit-only compliance report: Explanation

### What the check verifies
`lab check 4.01` runs `check.yml` on `localhost`. It reads the files in `/lab/work/4.01`:

- `report.json` and `report.md` exist;
- the JSON keys are exactly the hosts of `targets`, all eight values have a numeric `score`, each
  has at least ten `results`, every result has an `id`, and no status other than `pass`, `fail`
  and `n/a` occurs.

Then your playbook runs once more with `--check` and must report `changed=0` on every target; the
recap line of `localhost` is not looked at.

Not checked: the content of `report.md` (an empty file passes), the scores, which controls you
evaluate, `ignore_errors`, and `changed=0` in normal mode. A hand-written `report.json` with
`score: 123` and ten copies of `{"id": "x", "status": "pass"}` passed in our test, and so does a
report left over from an earlier run. Compare the report with the hosts yourself (values below).

### How it works

#### Collect with read-only modules
`package_facts`, `service_facts`, `stat` and `slurp` support check mode and simply run under
`--check`. A `command` task does not: in check mode it is skipped with the message "Command would
have run if not in check mode", so `sshd -T` and `sysctl -n` deliver nothing and the evaluation
fails (measured). `check_mode: false` makes these readers run anyway, `changed_when: false` keeps
the recap clean.
`sshd -T` needs root ("no hostkeys available" otherwise, see 4.05), hence `become: true`. Measured:
run 1, run 2 and `--check` are `changed=0` on all targets.

#### Evaluate in one `set_fact`
Each status is a Jinja expression, so a failing control cannot stop the host: every host gets all
ten results.
The helpers live in task `vars:`, which are templated per host when the task runs:

- `sshd` turns the `sshd -T` lines into a dict. The keywords must be lower-cased: seven hosts print
  `permitrootlogin`, arch (OpenSSH 10.6p1) prints `PermitRootLogin` and `MaxAuthTries`.
- `slurp` of the missing `/etc/sudoers.d/50-cis` fails; `failed_when: false` keeps the host alive,
  the result has no `content`, and `default('')` turns that into an empty string.
- `uid0` splits `/etc/passwd` into fields; `selectattr('2', 'equalto', '0')` works because Jinja
  turns the attribute `'2'` into the list index 2.
- `vsftpd` is `vsftpd.service` in `service_facts` on systemd hosts and `vsftpd` (with `runlevels`)
  on Alpine's OpenRC; the expression reads both.

`assert` would stop the host at the first failing control; expressions give you data.

#### Aggregate on `localhost`
The second play loops over `groups['targets']` and reads `hostvars[h].cis_results`. Two failure
cases, measured: a host that fails before the `set_fact` is silently missing from the report (the
`if ... is defined` filter), `ansible-playbook` ends with rc 2 and the check fails on the
structure. If *all* targets fail, the `localhost` play never starts and the old `report.json` stays
unchanged - a stale report looks like a fresh one.

#### n/a and the score
`n/a` counts neither as pass nor as fail: counting it as pass inflates scores, as fail punishes a
platform. Alpine's BusyBox `crond` does not read `cron.allow` (see 2.05), so 2.4 is `n/a` there and
Alpine's score is 2 of 9 = 22.2. `[p + f, 1] | max` guards the division for a host whose results
are all `n/a`.

#### What a control really measures
- **2.2** looks at the package name only. After 1.01 the Debian/Ubuntu dummy package `telnet` is
  gone and the report says `pass`, while `/usr/bin/telnet` from `inetutils-telnet` still works (see
  the 1.01 explanation). Arch and Alpine have no package `telnet` at all and pass from the start.
- **5.2** reads only the lab's drop-in `/etc/sudoers.d/50-cis` (1.05). At the start all eight hosts
  (sudo 1.9.16p2-1.9.17p2) already have `use_pty` in effect - `sudo -V` as root lists "Always run
  commands in a pseudo-tty", debian and ubuntu also set it in `/etc/sudoers` - and the reference
  still reports `fail`. `sudo -V` shows the effective value (the line disappears with
  `Defaults !use_pty`); `sudo -l` lists only explicit `Defaults`.
- **5.1** and **3.3** read effective values (`sshd -T`, the live sysctl), not files.

### Per-family notes
Measured on freshly reset hosts (after 0.02):

| Host | Score at start | Passing at start | `sshd -T` keywords |
|---|---|---|---|
| debian | 0.0 | none | lower case (OpenSSH 10.0p2) |
| ubuntu | 10.0 | 5.4.2 | lower case (10.2p1) |
| rocky | 0.0 | none | lower case (9.9p1) |
| alma | 10.0 | 5.4.2 | lower case (9.9p1) |
| fedora | 10.0 | 5.4.2 | lower case (10.2p1) |
| opensuse | 10.0 | 5.4.2 | lower case (10.0p2) |
| arch | 20.0 | 2.2, 5.4.2 | `PermitRootLogin`, `MaxAuthTries` (10.6p1) |
| alpine | 22.2 | 2.2, 5.4.2 (2.4 `n/a`) | lower case (10.3p1) |

All eight start with `permitrootlogin yes`, `maxauthtries 10` and `ip_forward=1`; debian and rocky
have the extra UID 0 account `toor` (3.05). After 5.01 (enforce, Level 1) every host scores 100.0.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| Only arch: "`dict` has no attribute `permitrootlogin`" | arch's OpenSSH prints the keywords as written | Lower-case the keys |
| The same error on every host, only under `--check` | `command` is skipped, `sshd -T` delivers nothing | `check_mode: false` on readers |
| `sshd -T`: "no hostkeys available" | Play runs without `become` | `become: true` |
| 5.2 `fail` although `use_pty` is in effect | Only the drop-in is read | Read `sudo -V` as root, or say what you measure |
| A host is missing in the report, rc 2 | The host failed before `set_fact` | Read the recap; fix the host |
| `report.json` unchanged after a run | All targets failed, the `localhost` play never ran | Remove the old report first, or check its time stamp |

### Real-world notes
Read effective values where the system offers them (`sshd -T`, `sysctl -n`, `sudo -V`) and write
down which source a control uses - 5.2 shows how a file and the effective value disagree. Keep the
playbook's exit code and recap next to the report, so a stale file cannot pass as fresh.

**Bonus - the timestamp:** measured with a `generated` field in `report.json`: `localhost` then
reports `changed=1` on every run, also under `--check`; the targets stay at `changed=0` and
`lab check` ignores `localhost`, but a top-level key next to the host names breaks `keys == targets`.
The cost is on the control node: every report differs, so a diff no longer shows real drift. L10
puts the time into the file name or a log.

**Bonus - controls as data:** a list in play `vars` with `ok: "{{ ... }}"` per entry works: play
vars are templated lazily per host and gave real booleans in our test. Strings read from a file
through `from_json` stayed literal text (ansible-core 2.21.6): data is not templated a second time.
5.01's registry is the bigger version of this idea, with a task file per control.

### Further reading
- Lesson [L10 - Compliance reporting: audit mode, enforce mode and custom facts](../../../docs/lessons/L10-compliance-reporting.md): check mode, recording results, report formats.
- Exercise [1.01 - Remove insecure client packages](../../stage1-beginner/1.01-remove-telnet/README.md)
- Exercise [1.05 - sudo: use a PTY and log to a file](../../stage1-beginner/1.05-sudo-hardening/README.md)
- Exercise [2.05 - Job schedulers: cron permissions and access](../../stage2-building-blocks/2.05-cron-hardening/README.md)
- Exercise [5.01 - Capstone: CIS role with audit and enforce mode](../../stage5-capstone/5.01-capstone-cis-role/README.md)

## Reference solution

Show it with `lab solution 4.01`, apply it with `lab solve 4.01`.
