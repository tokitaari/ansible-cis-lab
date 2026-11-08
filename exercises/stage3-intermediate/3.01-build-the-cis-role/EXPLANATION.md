# 3.01 - Refactor everything into a role: Explanation

### What the check verifies
`lab check 3.01` runs `check.sh` in four steps, then your `site.yml` once more with `--check`
and expects `changed=0`:

- **Structure:** nine files must exist in `/lab/work/roles/cis` (`tasks/main.yml`, the five
  section files, `defaults/main.yml`, `handlers/main.yml`, `meta/main.yml`), at least one
  `vars/*.yml`, and `/lab/work/3.01/site.yml`. `templates/` is not required.
- **Tags:** `ansible-playbook site.yml --list-tags` must name `section1`, `section2`, `section3`,
  `section5`, `section7`, `ssh`, `sudo`, `cron` and `sysctl`. The other topic tags of the README
  (`modules`, `banners`, `packages`, `services`, `permissions`) are not tested, nor which task
  carries a tag.
- **Lint:** `ansible-lint --offline --profile moderate` on the role.
- **State:** the checks of 0.04, 1.01-1.05 and 2.01-2.06.

It checks the hosts, not where their state came from: hosts that still carry the results of your
earlier playbooks pass even if the role does little. The README's "one run on freshly reset hosts"
is the real test - run `./lab.sh reset all` and 0.02 first. Measured with the reference role on
freshly reset hosts: all twelve checks `ok` after one run, the second run `changed=0`,
`lab check 3.01` passed. The limits of each single check stay (see the EXPLANATIONs of 0.04-2.06);
the role writes `cis-<module>.conf` like 2.03, so the openSUSE vendor rules win here too.

### How it works

#### Layout of the reference role
```
roles/cis/
├── defaults/main.yml        # every knob, prefixed cis_
├── vars/{Debian,RedHat,Suse,Archlinux,Alpine,default}.yml
├── tasks/main.yml           # include_vars + import per section
├── tasks/section{1,2,3,5,7}_*.yml
├── handlers/main.yml        # Reload sshd
├── templates/{banner,sshd_cis.conf}.j2
└── meta/main.yml            # platforms, min_ansible_version
```
Ansible loads `tasks/main.yml`, `defaults/main.yml`, `vars/main.yml`, `handlers/main.yml` and
`meta/main.yml` by itself (L07). The reference role has no `vars/main.yml`: a task loads its
platform files.

#### defaults, vars and `include_vars`
Defaults are the interface (`cis_level`, the sshd values, the module list) and lose against every
other layer. The platform data (service names, shadow group and mode, `cron.allow` support) is
loaded with `include_vars` + `first_found` (`<os_family>.yml`, then `default.yml`), and that layer
behaves differently from a role's `vars/main.yml`. Measured with a small test role (ansible-core
2.21.6):

| Layer | Beats | Still set in the next play |
|---|---|---|
| `defaults/main.yml` | nothing | no |
| `vars/main.yml` | inventory, play `vars:` | no |
| `include_vars` | inventory, play `vars:` | **yes** (for that host, for the rest of the run) |
| role parameter (`- role: cis` + `cis_x: ...`) | `include_vars`, inside the role only | no |
| `-e` | everything | yes |

So `cis_sshd_service` and the other platform values exist in every later play of the same
`ansible-playbook` run - one more reason for the `cis_` prefix.

#### `import_tasks`, tags and `always`
`import_tasks` is static: the tags of the import are copied to each task inside, so
`--list-tasks --tags ssh` shows the `always` task plus the two `ssh` tasks of section 5 (measured).

The `include_vars` task is tagged `always` because later tasks and the handler need its values.
Without the tag, `--tags ssh` writes the drop-in (`changed`), then the handler fails with
`'cis_sshd_service' is undefined` - the file is new, sshd still runs the old configuration
(session test). `--skip-tags always` is worse: Ansible's implicit handler flush also carries the
tag `always` (ansible-core source), so on debian the drop-in changed (`changed=1`), no handler ran
and nothing failed (measured).

Tags skip helper tasks too: `--tags sysctl` runs only tasks that carry the tag, and
`ansible.posix.sysctl` does not create its directory (`No such file or directory`, session test).
The reference role therefore tags both directory helpers with their topic (`Ensure /etc/sysctl.d
exists` with `sysctl`, `Ensure /etc/modprobe.d exists` with `modules`). `--tags sysctl` on freshly
reset rocky and alma, which have no `/etc/sysctl.d`, creates it and ends with `failed=0`
(measured; with the helper untagged it ended with `failed=1`). `always` would be wrong for such
helpers: they would create the directory under every `--tags` selection. `/etc/modprobe.d`
exists on all eight hosts (2.03); the `modules` tag matters for hosts without it (a `--tags
modules` run failed there in a session test).

#### What `ansible-lint --profile moderate` catches
Measured by changing one thing at a time in the reference role (ansible-lint 26.10.1):

- caught from `basic` on: a default, a `vars/` file or a `register` without the `cis_` prefix
  (`var-naming[no-role-prefix]`), an unquoted mode (`yaml[octal-values]`), an unnamed task
  (`name[missing]`);
- caught only by `production`: a module without FQCN (`fqcn[action-core]`) and a `command`
  without `changed_when` (`no-changed-when`, from `shared`).

The prefix rule fires only when the role sits in a directory called `roles/`. The repository's
own gate lints the reference solutions with `production`.

#### Testing the refactor
The checks of 0.04-2.06 are your regression suite: reset, run the role once, run the checks, run
it again (`changed=0`). Molecule automates the same loop.

### Per-family notes
| os_family | Platform file (sshd / cron service, `cron.allow`, shadow) | Run 1 on fresh hosts | Note |
|---|---|---|---|
| Debian | `ssh` / `cron`, yes, `shadow` `0640` | `changed=13` | - |
| RedHat | `sshd` / `crond`, yes, `root` `0000` | `changed=15` (rocky, alma), `14` (fedora) | rocky, alma: no `/etc/sysctl.d` at start, `--tags sysctl` creates it |
| Suse | `sshd` / `cron`, yes, `shadow` `0640` | `changed=14` | vendor modprobe rules win (2.03) |
| Alpine | `sshd` / `crond`, no (the spool `/etc/crontabs` instead), `shadow` `0640` | `changed=11`, `skipped=3` | needs 0.02 first |
| Archlinux | `sshd` / `cronie`, yes, `root` `0600` | `changed=13` | - |

Second run: `changed=0` on all eight (measured).

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `'cis_sshd_service' is undefined` in the handler under `--tags ssh` | `include_vars` task not tagged `always` | tag it `always` |
| Drop-in changed, no handler ran, no error | `--skip-tags always` also skips the implicit handler flush | do not skip `always` |
| `--tags sysctl` fails on a host without `/etc/sysctl.d`: `No such file or directory` | the directory helper task has no `sysctl` tag (your own role) | topic tag on the helper task, not `always` |
| A play variable or inventory value has no effect | the value comes from `include_vars` or `vars/` | knobs belong in `defaults/` |
| A later play sees `cis_*` values | `include_vars` sets host variables for the rest of the run | prefix everything |
| Lint passes, but `production` reports `fqcn` | `moderate` does not include it | lint with `production` before sharing |
| Role found in `/lab`, not in `roles_path` | the working directory is searched too (L07) | run from `/lab/work/3.01` |

### Real-world notes
- Tag every task that prepares something (directories, facts, vars) with the topic tag or
  `always`, and test the tags you advertise: `--tags <tag>` on a fresh host.
- Put the Python bootstrap (bonus 3) into the play, not the role. Facts are gathered before
  `pre_tasks` (session test: `Gathering Facts` failed before the first `pre_tasks` task), so the
  play needs `gather_facts: false`, the `raw` bootstrap, then `ansible.builtin.setup`. The role
  itself depends on facts (`ansible_facts.os_family`) and cannot repair their absence.
- Review `defaults/main.yml` like a policy: every value is a decision for every host.

### Further reading
- Lesson [L07 - Roles, tags and project structure](../../../docs/lessons/L07-roles-tags-project-structure.md): layout, precedence, imports, tags, lint profiles, links to the Ansible documentation.
- Exercise [2.03 - Disable unneeded kernel modules](../../stage2-building-blocks/2.03-disable-kernel-modules/README.md)
- Exercise [2.04 - Kernel parameters: network hardening via sysctl](../../stage2-building-blocks/2.04-sysctl-network/README.md)
- Exercise [4.03 - Data-driven role for all platforms (incl. Alpine)](../../stage4-advanced/4.03-data-driven-multi-platform-role/README.md)

## Reference solution

Show it with `lab solution 3.01`, apply it with `lab solve 3.01`.
