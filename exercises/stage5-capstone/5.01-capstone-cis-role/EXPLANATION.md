# 5.01 - Capstone: CIS role with audit and enforce mode: Explanation

### What the check verifies
`lab check 5.01` runs `check.sh`, which expects that you have already run the role in enforce mode:

- `ansible-lint --offline --profile production` on the role;
- the checks of 0.04, 1.01-1.05, 2.01-2.06, 3.02, 3.03 and 3.05; 3.04 only with
  `-e cis_level=2` (a level set inside `-e @file` is not seen);
- an audit run (`-e cis_mode=audit` plus your extra arguments): it must succeed with `changed=0` on
  every target, and `compliance.json` must cover eight hosts, each with `mode: audit`, `level`,
  `counts`, at least 14 `findings` and no `fail`.

Then `site.yml` runs once more with `--check` (enforce mode) and must report `changed=0`. The report
tasks run in that run too, so after `lab check 5.01` the report says `mode: enforce` (measured).

Not checked: the first audit on fresh hosts, `fixed`, exceptions, `compliance.md`, a Level 2 audit
on fresh hosts and the second enforce run (only its `--check` stand-in). The README's sequence was
measured, see below.

### How it works

#### Check mode as the audit engine
An idempotent module knows whether the desired state is met; in check mode it answers without
acting, so the remediation code is the audit code:

| Task in check mode | Result | Recorded as |
|---|---|---|
| `file`, `copy`, `template`, `lineinfile`, `package`, `service`, `sysctl` | `changed: true` when it would act | finding |
| `command` (here `useradd -D -f`, `pam-auth-update`) | skipped, `changed: false`, msg "Command would have run if not in check mode" | finding (the `msg`) |
| `slurp`, `stat`, `package_facts`; `command` with `check_mode: false` (`useradd -D`) | reads for real | data, not recorded |

Measured: `changed_when: true` is not applied to the skipped `command`, so `control.yml` must look
at the `msg`. Both commands of the role run only when a reader found a deviation (`when`); an
unguarded command would be a finding on every audit.

#### `apply: check_mode` and the dry-run trap
`include_tasks` does not accept `check_mode:` itself; `apply:` hands the keyword to every task of
the included file, and a task's own `check_mode: false` still wins. The expression is
`ansible_check_mode or cis_mode == 'audit'`. The plain `"{{ cis_mode == 'audit' }}"` is `false` in
enforce mode and overrides `--check`: with it, `ansible-playbook site.yml --check` wrote files on
the targets (measured). `cis_status` uses the same condition, so a dry run in enforce mode records a deviation
as `fail`, not `fixed`, while the report says `mode: enforce`. Inside the include
`ansible_check_mode` is only the command-line flag (L10), so test the mode variable there.

#### Registry, decision, recording
`vars/main.yml` lists 16 controls (id, level, file, optional `requires`). `control.yml` decides
(`excepted`, `out-of-profile`, `not-applicable`, else `active`), includes the file of an active
control and records it: non-compliant when any registered result - loop items included - is
`changed` or "would have run". Each file registers `cis_r_<n>` and sets `cis_control_results`.
Measured: 5.3.3 is `not-applicable` on opensuse, arch and alpine (no `pwquality` feature).

#### Dry runs into missing state
On a fresh host an audit checks tasks whose input an earlier task would create. Measured in check
mode: `copy` and `template` into a missing directory report `changed` without error; `lineinfile`
without `create` on a missing file fails in check mode as well. So 6.3's `lineinfile` on
`/etc/audit/auditd.conf` breaks a **Level 2 audit on fresh hosts**: it failed on seven hosts (arch
ships `auditd.conf` at the start), and the report held arch only. Run enforce first, or guard the
task like the four `when: not (cis_mode == 'audit' and cis_r_0 is changed)` tasks in the module and
sysctl controls.

#### Handlers
`Reload sshd` has `when: cis_mode == 'enforce'`: a handler does not inherit the keyword, and L10
measured one that ran for real after a checked task notified it. A global `--check` does reach it.

#### The report
The report tasks use `run_once`, `delegate_to: localhost`, `check_mode: false` and
`changed_when: false`. Such a task is counted on the first target host, so without the last one the
audit recap could not be `changed=0`. The host list is every host with a `cis_summary`, not
`ansible_play_hosts` (5.02 runs with `serial`). Measured: a host that fails is missing from the
report; when every host fails (an expired exception fails the preflight everywhere), nothing is
written and the previous report stays.

#### Tags and subsets
The controls carry no tags. Measured: `--tags sysctl` - like any other `--tags` selection - fails
on all eight hosts at the apt index task, because the untagged `include_vars` is skipped and
`cis_apt_cache_refresh` is undefined. Select controls with `-e '{"cis_controls_only": ["5.2"]}'`;
the report then lists only those. Give booleans as JSON: `-e cis_apt_cache_refresh=false` is the
string `"false"`, and the `when` refuses it (measured).

### Per-family notes
Measured on freshly reset hosts (after 0.02), Level 1:

| Host | First audit: `fail` | Not failing at the start | Recap `changed`, audit / enforce |
|---|---|---|---|
| debian | 14 | - | 19 / 21 |
| ubuntu | 14 | - | 19 / 21 |
| rocky | 14 | - | 18 / 21 |
| alma | 13 | 5.4.2 | 17 / 20 |
| fedora | 14 | - | 18 / 20 |
| opensuse | 12 | 5.4.2; 5.3.3 `not-applicable` | 16 / 18 |
| arch | 11 | 2.2, 5.4.2; 5.3.3 `not-applicable` | 15 / 17 |
| alpine | 11 | 2.2, 5.4.2; 5.3.3 `not-applicable` | 14 / 16 |

At Level 1, `1.1.1-L2` and `6.3` are `out-of-profile` everywhere. After the first audit no file
under `/etc` or `/usr` had changed; debian and ubuntu had downloaded their apt index (0 -> 3 and 13
files). Enforce turned every `fail` into `fixed`; the next audit, the second enforce run and
`--check` were `changed=0`. Level 2 on top changed 5 tasks per host; `lab check 5.01` passed with
and without `-e cis_level=2`. Unlike 4.01, 5.4.2 also locks accounts with an empty password, so
ubuntu and fedora (`guest`, 3.05) fail it too.

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `--check` in enforce mode changed the targets | `check_mode: "{{ cis_mode == 'audit' }}"` is `false` and beats `--check` | `ansible_check_mode or cis_mode == 'audit'` |
| The audit recap shows `changed=14`-`19` | Check mode reports a would-be change as `changed` | Expected on fresh hosts; read the report |
| Level 2 audit on fresh hosts fails at 6.3 | `lineinfile` on the missing `auditd.conf` fails in check mode | Enforce first, or guard the task |
| `--tags ...` fails on every host | `include_vars` has no tag | `cis_controls_only` |
| The report shows old data | A failed run writes no report | Check the recap and the file time |
| After `lab check 5.01` the report says `enforce` | The `--check` run rewrites it | Run the audit again for evidence |

### Real-world notes
The audit mode changes no configuration, but it is not zero-touch: on Debian/Ubuntu it refreshes
the apt index (`check_mode: false`, a cache). Introduce the role as the README's sequence does:
audit, enforce in a change window, audit again as evidence, then audits on a schedule. Exceptions
expire on purpose - the next run fails until someone renews or removes them.

### Further reading
- Lesson [L10 - Compliance reporting: audit mode, enforce mode and custom facts](../../../docs/lessons/L10-compliance-reporting.md): check mode as an audit engine, `apply:`, handlers, the flag.
- Lesson [L11 - Profiles, exceptions and data-driven roles: one role, many audiences](../../../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.md)
- Exercise [4.01 - Audit-only compliance report](../../stage4-advanced/4.01-audit-only-report/README.md)
- Exercise [4.02 - Profiles (Level 1/2) and documented exceptions](../../stage4-advanced/4.02-profiles-and-exceptions/README.md)
- Exercise [4.03 - Data-driven role for all platforms (incl. Alpine)](../../stage4-advanced/4.03-data-driven-multi-platform-role/README.md)
- Exercise [5.02 - Rollout strategy: preflight, canary, batches](../5.02-rollout-strategy/README.md)

## Reference solution

Show it with `lab solution 5.01`, apply it with `lab solve 5.01`.
