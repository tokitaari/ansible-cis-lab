# 4.05 - Custom facts: hosts that describe their own hardening: Explanation

### What the check verifies
`lab check 4.05` runs `check.yml` and then your playbook once more with `--check`, expecting
`changed=0` (`meta.yml` says `idempotency: true`). `check.yml` has two plays:
- on all eight targets, with `become`: it gathers `ansible_local` itself and asserts
  `cis.baseline == 'lab-cis'`, that `cis.version` and `cis.level` exist, `cis_live.uid0_accounts`
  at least 1 and a non-empty `cis_live.permit_root_login`; `cis.fact` must be `0644`,
  `cis_live.fact` `0755` and owned by root;
- on `localhost`: `inventory.md` in the work directory (`$LAB_WORK_DIR/4.05`) contains the name of
  every target.

It does not test: the values of `version`, `level` and `managed_by`, the group of the files, that
your play gathers again after deploying (the check gathers on its own), the columns and values
of the report (any file that names the eight hosts passes), and whether `permit_root_login` is
real - the fallback `unknown` passes. A timestamp in `cis.fact` is caught only by the second run.

### How it works

#### Static and executable facts
| | static `.fact` | executable `.fact` |
|---|---|---|
| content | JSON or INI written by Ansible | the output of the script |
| answers | "what did we apply?" | "what is true right now?" |
| cost | none | runs on *every* fact gathering |

Measured for lesson L10: JSON keeps types and key case (`level` stays the number 1); INI gives
strings and lowercases the option names. A file with the owner's execute bit is always run, never read (ansible-core source).

#### When facts are read
Facts are gathered at the start of a play - before your files exist. Right after the `copy`
tasks `ansible_local` is still the old value (empty on the first run) until an
`ansible.builtin.setup` with `filter: ansible_local` gathers again. The second play reads the
fresh values through `hostvars[h].ansible_local`; without the re-gather its first report has a
`-` in every cell. Under `--check` nothing is written, yet executable facts already on disk still
run.

#### Facts run with the play's rights
Measured for lesson L10: the fact script ran as the `ansible` user without `become` and as root
with it. That matters here: `sshd -T` needs the host keys, and as a normal user it only prints
`sshd: no hostkeys available -- exiting.` (measured), so the script reports `unknown` - and the
check accepts that. Hence `become: true` on the play. The flip side: a `facts.d` that someone
else can write to is code execution as root on the next Ansible run. Keep it `0755 root:root`.

#### What a slow fact costs
Every gathering runs every executable fact, for every play that gathers. `gather_timeout` does not
protect you: with `gather_timeout: 2` and a script that sleeps 8 seconds the `setup` task waited
9 seconds (measured; the local-facts collector calls the script without a time limit). Bonus 2,
answered: keep the script cheap, put a `timeout` in front of the slow command inside the script,
or let a scheduled job write the measurement as a *static* fact. Plays that do not need local
facts can skip them with a `gather_subset` such as `['!all', '!min']` (L10).

#### Broken facts do not stop the play
A static file that is not valid JSON or INI, or a script that exits non-zero, leaves a string in
`ansible_local.<name>` (`error loading facts as JSON or ini - please check content: <path>`,
`Failure executing fact script (<path>), rc: 3, err: `) and the play goes on (L10). The check then
fails on the missing keys - read the value it prints.

#### No timestamps
`"last_run": "{{ now() }}"` makes the file change on every run - never `changed=0`, and your
drift reports become noise. If you need run history, send it to a log or the report on the
control node, not into managed state.

#### Using them in AWX/AAP
With fact caching enabled on the job template, AWX/AAP stores the gathered facts per host and
shows them in the host details; smart inventories can filter hosts on those facts. This was not
tested in the lab - check the filter syntax in the documentation of your version.

### Per-family notes
| `os_family` | Hosts | `/bin/sh` (runs the script) |
|---|---|---|
| Debian | debian, ubuntu | dash |
| RedHat | rocky, alma, fedora | bash |
| Suse | opensuse | bash |
| Archlinux | arch | bash |
| Alpine | alpine | BusyBox |

`/etc/ansible/facts.d` exists on none of the eight targets at the start. Write the script for the
smallest shell (POSIX `sh`, BusyBox `awk`) and it runs everywhere.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| The first report shows `-` for every host | facts were gathered before the files existed | `setup` with `filter: ansible_local` after deploying |
| `permit_root_login` is `unknown` | the script ran without root, `sshd -T` found no host keys | `become: true` on the play |
| `ansible_local.cis_live` is a string with `error loading facts` | the script printed no valid JSON, or the file lacks the execute bit | test the script by hand, mode `0755` |
| `changed=1` on every run | a timestamp or other moving value in `cis.fact` | only stable values in managed files |
| Every play on a host got slow | an expensive executable fact | `timeout` in the script, or a static fact written by a job |

### Real-world notes
- Version the baseline in the fact (`version`) and bump it with the role: "which hosts still run
  1.0.0?" becomes a query instead of an audit.
- Keep executable facts read-only and quick; they run on every play, including ones that have
  nothing to do with hardening.

### Further reading
- Lesson [L10 - Compliance reporting: audit mode, enforce mode and custom facts](../../../docs/lessons/L10-compliance-reporting.md): `facts.d`, the re-gather, check mode and reports - the concepts before this exercise.
- Exercise [4.01 - Audit-only compliance report](../4.01-audit-only-report/README.md): the report side without changing the hosts.
- Exercise [5.01 - Capstone: CIS role with audit and enforce mode](../../stage5-capstone/5.01-capstone-cis-role/README.md): where facts and reports come together.

## Reference solution

Show it with `lab solution 4.05`, apply it with `lab solve 4.05`.
