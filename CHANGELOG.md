# Changelog

All notable changes to the Ansible CIS Hardening Lab.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow
[Semantic Versioning](https://semver.org/) - MAJOR: incompatible lab/exercise changes,
MINOR: new features or exercises, PATCH: fixes.

**Rebuild hints** per release tell you what to run after `git pull --ff-only`:
- *none* - live scripts in `control/`, docs or exercises only
- *control* - `docker compose build control && docker compose up -d --force-recreate control`
- *targets* - `docker compose build && ./lab.sh reset all` (targets restart non-compliant)

## [Unreleased]

### Added
- Lesson L00 *Lab architecture and Ansible basics* in `docs/lessons/` (EN and DE), the first
  self-study lesson: how the control node reaches the targets (SSH key, `ansible` account,
  sudo, `ANSIBLE_CONFIG`), inventory and patterns, how a module runs and why `raw` needs
  `changed_when`, facts and `hostvars`, idempotency and `--check --diff`; with
  platform table, container notes, pitfalls and self-check questions. Prepares 0.01-0.04. Read
  it with `lab lesson 0`.
  Rebuild: *none*
- Lesson L01 *CIS Benchmarks: structure, levels and the lab catalogue* in `docs/lessons/` (EN
  and DE): what a Benchmark is and how it is made (consensus process, licence, CIS Controls,
  CIS-CAT), the fields of a recommendation, *Automated* vs. *Manual*, why recommendation numbers
  move between versions, Level 1/2 and Server/Workstation profiles, mapping audit and
  remediation to Ansible tasks (and what does not automate), exceptions, and how
  `cis/controls.yml` and the exercises' `meta.yml` connect to the PDFs - with a tested play
  that queries the catalogue, container values, pitfalls and self-check questions. Background
  for all exercises, applied directly in 4.01, 4.02 and 5.03. Read it with
  `lab lesson 1`. Rebuild: *none*
- Lesson L02 *Safe changes: check mode, validate, handlers and conditionals* in
  `docs/lessons/` (EN and DE): what `--check --diff` can and cannot predict (skipped
  `command` tasks, `check_mode: false`, `diff: false`), what `validate` proves and what it
  does not, handlers (run once, `flush_handlers`, `listen`, `force_handlers`, lost handlers
  after a failure), conditionals with `package_facts`, `failed_when` instead of
  `ignore_errors`, and ordering a risky change (`--limit`, `--step`, `backup`,
  `block`/`rescue`) - with tested examples, platform table, pitfalls and self-check
  questions. Prepares 1.01-1.05. Read it with `lab lesson 2`.
  Rebuild: *none*
- Lesson L03 *Base hardening: packages, services, file permissions, SSH and sudo* in
  `docs/lessons/` (EN and DE): the layers of attack surface (installed, running, enabled,
  masked) and why `service_facts` differs between systemd and OpenRC, verifying a removal by
  its effect, package names across distributions, file modes (octal and symbolic, the
  unquoted-mode trap, why compliance is a bound), how sshd combines several files (first value
  wins, `Match`, `sshd -T`, reload versus restart) and how sudo reads `sudoers.d` (later
  wins, dotted names ignored, sudo-rs) - with tested examples, platform table, pitfalls and
  self-check questions. Prepares 1.01-1.05 and 2.01. Read it with
  `lab lesson 3`. Rebuild: *none*
- Lesson L04 *Platform differences as data: dictionaries, loops, Jinja2 and templates* in
  `docs/lessons/` (EN and DE): a dictionary keyed by `os_family` instead of a chain of `when`
  conditions (and what a missing key or a `default` means), registered loop results
  (`results`, `item.item`, `selectattr`), Jinja2 expressions, filters, tests and undefined
  values in ansible-core 2.21, templates (block trimming, `ansible_managed`, deterministic
  output, `--diff`) and where a variable gets its value (layers, `ansible-inventory --host`) -
  with tested examples, platform table, pitfalls and self-check questions. Prepares 2.01, 2.02
  and 2.06. Read it with `lab lesson 4`.
  Rebuild: *none*
- Lesson L05 *Kernel hardening: modules and sysctl* in `docs/lessons/` (EN and DE): namespaced
  vs. global kernel parameters and why a privileged container makes the difference matter,
  running value vs. `sysctl.d` file and the order in which files are read, the options of
  `ansible.posix.sysctl` (`sysctl_set`, `reload`, `ignoreerrors`) and how they fail, what
  `install` and `blacklist` in `modprobe.d` really do and what a rule does not cover (loaded
  modules, `insmod`, the initramfs), and collections (FQCN, `requirements.yml`) - with tested
  examples, platform table, pitfalls and self-check questions. Prepares 2.03 and 2.04. Read it
  with `lab lesson 5`.
  Rebuild: *none*
- Lesson L06 *Job schedulers: who runs what, and who may schedule it* in `docs/lessons/` (EN
  and DE): where cron reads jobs from and under whose authority they run (system crontab,
  drop-ins, user spool, periodic directories), the file checks of Debian cron, cronie and
  BusyBox crond (owner, mode, name, execute bit - measured, with the log line of a refusal),
  how `cron.allow`/`cron.deny` and `at.allow`/`at.deny` work and what they leave untouched
  (existing crontabs, drop-ins, BusyBox), `at`, systemd timers and anacron as other places for
  jobs, and the `ansible.builtin.cron` module (name marker, `cron_file`) - with tested examples,
  platform table, pitfalls and self-check questions. Prepares 2.05. Read it with
  `lab lesson 6`. Rebuild: *none*
- Lesson L07 *Roles, tags and project structure: one baseline, many switches* in
  `docs/lessons/` (EN and DE): the directory contract of a role (what Ansible loads on its own,
  where it searches for a role, `roles:` against `import_role`/`include_role`), `defaults/` against
  `vars/` with a measured precedence table and the role-prefix rule, `import_tasks` against
  `include_tasks` (what `--list-tasks` and `--tags` do with each), tags with `always`/`never`, and
  `ansible-lint` profiles from `min` to `production` with a worked violation list - with a
  runnable demo role, platform table, pitfalls (tested error texts) and self-check questions.
  Prepares 3.01. Read it with `lab lesson 7`.
  Rebuild: *none*
- Lesson L08 *Accounts and PAM: who may log in, how, and with what password* in
  `docs/lessons/` (EN and DE): the `passwd`/`shadow` fields and what `*`, `!` and an empty field
  mean, UID 0 against the name `root`, `getent` against the files, aging values and why a
  `login.defs` default reaches new accounts only (tested), hash prefixes and the two places that
  choose the algorithm, vendor-split configuration, the removed minimum age of `shadow` 4.20,
  PAM types and controls with the generators of each family, `pam_pwquality` and `pam_faillock`
  (drop-in order, `enforce_for_root`, tally, lock-out analysis), and why `umask` and `TMOUT` from a
  profile script are invisible to an Ansible task - with tested examples, a platform table
  measured on all eight targets, pitfalls and self-check questions. Prepares 3.02, 3.03, 3.05
  and 4.06. Read it with `lab lesson 8`. Rebuild: *none*
- Lesson L09 *Auditing and integrity: auditd, AIDE and long-running tasks* in `docs/lessons/`
  (EN and DE): why the audit subsystem belongs to the host kernel, watch and syscall rules, keys
  and `auid`/`unset`, the `rules.d` merge order and the last-`-e` rule (tested), `-e 2` and what it
  means for automation, the `auditd.conf` actions for a full log, a low disk and a write error,
  what an AIDE database holds, `database_in`/`database_out` and the promote step, the exit-code
  bits, baseline review and where the database lives, timer and `Type=oneshot` service units,
  and `async`/`poll`/`async_status` (failures stay invisible until collected, `poll: 0` with
  `creates` is `changed` on every run) - with tested examples, a platform table measured on all
  eight targets, pitfalls and self-check questions. Prepares 3.04 and 4.08. Read it with
  `lab lesson 9`. Rebuild: *none*
- Lesson L10 *Compliance reporting: audit mode, enforce mode and custom facts* in
  `docs/lessons/` (EN and DE): one code path for audit and enforce through check mode, how each
  kind of task reports (and why a skipped `command` means "unknown"), a `check_mode` keyword
  that does not override `--check`, what check mode does not stop (handlers, `async` with
  `poll: 0`, the flag inside a keyword block, dynamic includes) - all tested - findings as data
  with ok/deviation/not-applicable and a score, collecting `hostvars` into a deterministic JSON
  and Markdown report with a "no data" list, and custom facts (`facts.d`, static and executable,
  stale `ansible_local`, types, broken facts, privileges) - with a platform table measured on all
  eight targets, pitfalls and self-check questions. Prepares 4.01, 4.05 and 5.01. Read it with
  `lab lesson 10`. Rebuild: *none*
- Lesson L11 *Profiles, exceptions and data-driven roles* in `docs/lessons/` (EN and DE): a
  profile as one validated value (`-e` gives a string, a block's `when` is evaluated per task,
  a lower level undoes nothing), exceptions as records with a reason and an end date (YAML
  dates, `to_datetime` and `now()`, midnight and the day an exception ends), validation before
  the first change with `assert` and `meta/argument_specs.yml` (what it checks and what it does
  not), capability flags instead of system conditions (one data file or layers, a conservative
  fallback, the precedence of `include_vars`), and testing a role from the outside with the JSON
  callback and `--check` - all tested - with a platform table measured on all eight targets,
  pitfalls and self-check questions. Prepares 4.02 and 4.03. Read it with
  `lab lesson 11`. Rebuild: *none*
- Lesson L12 *Secrets with Ansible Vault* in `docs/lessons/` (EN and DE): what Vault protects
  and where a secret still shows up, vault files, password sources (file, environment variable,
  executable) and ids, a whole file or one value with the `vault_` naming convention, why a
  random salt makes `password_hash` report `changed` on every run, the salt rules, the dependence
  on the control node's hashing library and what `update_password: on_create` costs, and which
  output shows a secret (`--diff`, registered results, command lines) with and without `no_log`;
  with platform table, container notes, pitfalls and self-check questions. Prepares 4.04. Read it
  with `lab lesson 12`. Rebuild: *none*
- Lesson L13 *Host firewall with nftables* in `docs/lessons/` (EN and DE): tables, hooks and why
  a firewall owns one table (several base chains on one hook, a drop is final, `flush ruleset`
  in a throw-away namespace), loading rules (the check-only mode and what it cannot know, one file
  is one transaction, what a second load and a delete of a missing table do), the dead-man switch
  in four tested pieces (a job that outlives its task, `async` has no cancel, a reused against a
  new SSH connection, `wait_for_connection` and the rule for its timeout), and what survives a
  restart (file, service, live ruleset) - with platform table measured on all eight targets,
  pitfalls and self-check questions. Prepares 4.07. Read it with
  `lab lesson 13`. Rebuild: *none*
- Lesson L14 *Production rollout* in `docs/lessons/` (EN and DE): failure semantics of a play
  (what one failed host does to the others, the later batches and the later plays with and
  without `serial`, `max_fail_percentage` and `any_errors_fatal`, the strict threshold, the recap
  that omits hosts that never started), `serial` lists and percentages, what limits parallelism
  (`forks`, `serial`, `throttle`), a preflight gate that also runs under `--check`, what facts and
  free space can and cannot tell (the missing mount entry of a container root, thin
  provisioning), the host lists of a play and of a batch with `run_once` and `post_tasks`, and
  community roles (Galaxy, Git, pins in `requirements.yml`, what a second install does, reading a
  role without running it, adopt, fork or build) - with platform table measured on all eight
  targets, a Galaxy example measured by the user, pitfalls and self-check questions. Prepares
  5.02 and 5.03. Read it with `lab lesson 14`. Rebuild: *none*
- `lab lesson [n] [answers]`: without arguments it lists the lessons L00-L14 with reading time,
  the exercises each one prepares and a ✔ once you have passed all of them; `lab lesson 5`
  (also `05`, `L05`) shows lesson L05 in your language with the self-check answers hidden,
  `lab lesson 5 answers` with the answers. An exercise id works too: `lab lesson 2.03` shows the
  lesson that prepares 2.03, or lists them when there are two (1.01-1.05, 2.01).
  `lab start <id>` names the lesson(s) of the exercise. The lesson header is the only source of this
  mapping. Tab completion for `lab lesson` (lesson ids, `answers`) and `lab placement`
  (`answers`); the README lists the lessons and the new commands (and no longer promises a
  getting-started guide in `docs/`). Rebuild: *none* (open a new shell for the completion)
- Glossary `docs/GLOSSARY.md` (EN and DE, `lab docs glossary`): 97 terms of the lessons and
  exercises - Ansible (check mode, handler, `validate`, tags, `serial`, Vault, ...), CIS
  (Benchmark, recommendation, Level 1/2, *Automated* / *Manual*, ...), Linux (PAM, faillock,
  `modprobe.d`, sysctl, auditd, nftables, ...) and the lab itself - each in one or two sentences
  with a link to the lesson section that explains it. Sorted by the English term; the German
  page adds the German term where the lessons use one. Every lesson ends its *Further reading*
  with a line naming its glossary terms; the lesson template, LEARNING_PATH and the README link
  the glossary. Rebuild: *none*

### Changed
- Exercise 5.01 (EN and DE): deeper `EXPLANATION.md` with measured facts (what `check.sh` tests
  and what it leaves out, how check-mode results are read, the `apply: check_mode` trap and why a
  dry run in enforce mode records `fail`, per-family results of the README's acceptance sequence,
  pitfalls); hint 3 is now a skeleton of the role's `tasks/control.yml`. Measured: a Level 2
  audit on freshly reset hosts fails on seven of eight hosts at 6.3 (`lineinfile` on the missing
  `/etc/audit/auditd.conf` fails in check mode); any `--tags` selection fails before the first
  control (`include_vars` has no tag); a failed run leaves the previous report in place; the
  audit mode refreshes the apt index. Rebuild: *none*
- Exercise 4.01 (EN and DE): deeper `EXPLANATION.md` with measured facts (what `check.yml`
  tests and what it leaves out, scores per host at the start, pitfalls, answers to both bonus
  questions); hint 3 is now a skeleton of the playbook with `"..."`. Measured: a hand-written
  report with any score passes the check; if all targets fail, the old `report.json` stays; only
  arch's OpenSSH prints `PermitRootLogin`; `use_pty` is already in effect on all eight hosts, so
  the README now says that control 5.2 looks at the drop-in `/etc/sudoers.d/50-cis`. Rebuild:
  *none*
- Exercises 3.02 and 3.05 (EN and DE): deeper `EXPLANATION.md` with measured facts (check scope,
  per-family notes, pitfalls), hint 3 is now a play skeleton with `"..."`. 3.02: only the four
  `shadow` builds with `libeconf` (rocky, alma, fedora, opensuse) read `/etc/login.defs.d`, so a
  drop-in passes the check on the other hosts without effect; arch and alpine start without
  `PASS_*` lines; shadow 4.20 (arch) ignores `PASS_MIN_DAYS`; the `chpasswd` hash did not change
  on any host. 3.05: the check rejects `umask 0027` and accepts `TMOUT=0`; dash (`/bin/sh` on
  Debian/Ubuntu) ignores `TMOUT`; after the exercise Ansible's own commands run with umask `0027`
  on rocky, alma and fedora. The 3.05 README says that `TMOUT=0` switches the timeout off and that
  `readonly` is not inherited. L08 (EN and DE): no longer predicts that Ansible's own shell keeps
  its umask after 3.05. Rebuild: *none*
- Exercise 3.01 (EN and DE): deeper `EXPLANATION.md` with measured facts (what `check.sh` tests
  and what it leaves out, per-family notes, pitfalls); hint 3 is now a skeleton of the role's
  `tasks/main.yml` with `"..."`. The EXPLANATION now says that `ansible-lint --profile moderate`
  does not report missing FQCN or `changed_when` (only `production` does), that variables loaded
  with `include_vars` beat play vars and stay set for later plays of the same run, that
  `--skip-tags always` also skips the implicit handler flush, and that
  `--tags sysctl` fails on freshly reset rocky and alma because the directory task of the
  reference role carries only `section3`. Rebuild: *none*
- Exercises 2.01 to 2.03 (EN and DE): deeper `EXPLANATION.md` with measured facts (check
  scope, per-family notes, pitfalls), hint 3 is now a play skeleton with `"..."`. 2.01: who needs
  the group `shadow` (`unix_chkpwd` per family), the backups that start world-readable on four
  hosts (README bonus 1 says so), no `default` for the lookup. 2.02: the README table now lists
  `PermitRootLogin`, `PermitEmptyPasswords` and `X11Forwarding` (the check asserts them and the
  legacy drop-in sets them otherwise), the ClientAlive row and the crypto-policies hint of bonus 3
  are corrected, and the EXPLANATION says that a failed full `sshd -t` leaves the new file on
  disk. 2.03: the README rule lines no longer carry comments (the check rejects anything after
  `/bin/false`), a bonus question shows that on openSUSE vendor rules
  (`60-blacklist_fs-*.conf`) win over `cis-*.conf` for five of the six modules (kmod uses the
  first `install` line in file-name order; the check reads files only and still passes), and the
  EXPLANATION covers dash/underscore names and BusyBox on Alpine. L05 (EN and DE): BusyBox's
  `modprobe` ignores `install` lines (was "not verified"), and the openSUSE vendor rules. Rebuild:
  *none*
- Exercises 1.01 to 1.05 (EN and DE): deeper `EXPLANATION.md` with measured facts
  (check scope, per-family notes, pitfalls), hint 3 is now a play skeleton with `"..."` instead of
  the full solution. 1.02 README: the `stat` command greps ` mode:`, the lab check wants exactly
  `0644`; 1.04 README: `vsftpd` is on all eight hosts, a missing service fails only on some
  hosts. 1.03 and 1.05 explain what the checks leave
  untested. L03 (EN and DE): the sudo-rs sentence now says that the lab's Ubuntu image uses the
  original sudo. Rebuild: *none*
- Lesson template (`docs/lessons/TEMPLATE(.de).md`), lessons learned from L00: the header lists
  the CIS sections of the lesson's exercises (other ids may appear in the text), examples must
  run unchanged in the lab, exercises link to their README (the template's INDEX link is only a
  placeholder), platform tables may add columns but keep one row per `os_family`.
  Rebuild: *none*
- Static gate check `lessons`: every row of a lesson's Exercises table must link to the README
  of exactly the exercise it names (`README.de.md` in German lessons); before, any existing
  file passed. Rebuild: *none*
- `tools/static-check.sh` (*lint*): the ansible-lint warning "Directory expansion discovered N
  file(s)" is no longer shown - ansible-lint prints it for every directory argument and offers
  no setting to turn it off, while the gate lints the solution directories on purpose. Other
  messages and the exit code are unchanged. Rebuild: *none*
- Exercises 4.04 and 4.07 (EN and DE): deeper `EXPLANATION.md` in a fixed order (what the check
  verifies, how it works, per-family table, pitfalls with measured facts, real-world notes,
  further reading with links to the lessons L12 and L13) and a third hint that shows the
  skeleton of the play instead of only pointing to the solution. Corrected statements that
  measurements did not support: in 4.04 that `-v` prints the password hash (the `user` module
  masks it) and that Alpine's tools lack aging fields (the README now gives the real reason: no
  Python before 0.02); in 4.07 that `wait_for_connection` would reuse the old connection without
  `reset_connection`, and that `nohup` is needed for the rollback job. New: the hash of a stable
  salt depends on the control node's backend (libxcrypt or passlib), the `wait_for_connection`
  timeout must stay below the rollback delay, `default_ipv4` needs the network facts, the unit
  texts of `nftables` per family, and bonus questions on `update_password` and running 4.04 on
  Alpine. Rebuild: *none*
- Exercises 5.02 and 5.03 (EN and DE): deeper `EXPLANATION.md` in the same fixed order (what the
  check verifies, how it works, per-family table, pitfalls with measured facts, real-world
  notes, further reading with links to the lessons) and a third hint that shows the skeleton
  (the three plays of 5.02, the six answers of `review.md` in 5.03) instead of only pointing to
  the solution. Corrected in 5.02: a percentage in `serial` is a share of the hosts of the play,
  not of the remaining ones (in the lab the third play has six hosts, so `[1, "30%", "100%"]`
  gives batches of 1, 1 and 4), `max_fail_percentage: 0` matters only inside a batch with
  several hosts (strict threshold, share of the batch), and which mounts `ansible_facts.mounts`
  keeps (devices starting with `/` or `\`, or containing `:/`). New: what `lab check 5.02` and
  `5.03` verify and what not, what runs per batch, the per-family tool paths and `sshd -T`
  spelling, a measured example of two ansible-lockdown roles at pinned tags (switches,
  disruption flag, profiles by tag, audit tooling) and which lab platforms have a matching
  community role. 5.03: the README no longer asks for a playbook (the exercise writes
  `review.md`), and `check.sh` names the accepted answer formats correctly (`## 1.`, not
  `## 1`). L14: one sentence that 30 % is one host in the six-host batch play of 5.02.
  Rebuild: *none*
- Exercises 4.02 and 4.03 (EN and DE): deeper `EXPLANATION.md` in the same fixed order (what the
  check verifies and what not, how it works, pitfalls with measured facts, real-world notes,
  further reading with links to the lesson L11; 4.03 also a per-family table) and a third hint
  that shows the skeleton (the role's `tasks/main.yml` in both exercises) instead of only pointing
  to the solution. 4.02: the README now says what `expires` means (the first day the exception no
  longer applies, so today's date is already rejected), hint 1 trims the reason and checks that
  `expires` exists; the EXPLANATION lists what `lab check 4.02` does not test (output of the
  excepted controls, unknown id, missing `expires`, validation before the first control), that
  `-e cis_level=2` is a string, and how a looped task shows up in the JSON callback. 4.03: hint 3
  said ten earlier checks, it is fifteen (sixteen with `-e cis_level=2`); the EXPLANATION names the
  limits of the check's `grep` on fact comparisons, corrects "Alpine has no PAM" (it has
  `/etc/pam.d` and `faillock`, but no password stack and no pwquality), and measures that a partial
  `vars/Ubuntu.yml` leaves the other flags undefined with the one-file loader. The Ubuntu bonus
  of 4.03 now asks to find that out and to layer the loads. Rebuild: *none*
- Exercises 3.04 and 4.08 (EN and DE): deeper `EXPLANATION.md` in the same fixed order (what the
  check verifies and what it does not test, how it works, per-family table, pitfalls with
  measured facts, real-world notes, further reading with links to the lesson L09) and a third
  hint that shows the skeleton of the play (tasks list with `"..."`) instead of only pointing to
  the solution. 3.04: hint 1 corrected (a literal `\n` in a template stays two characters; the
  check does not notice, `augenrules` does), hint 2 names the case-sensitive check; README: the
  service sentence (the package install may already enable `auditd` on the RedHat family), the
  apt requirement (`update_cache: true`, do not rely on `cache_valid_time`) and bonus 1
  (`augenrules --check`: what it compares, its exit code). 4.08: the claim that `creates:`
  covers overlapping runs is corrected (it only covers the moment between check and start; a
  second run during a long scan starts a second scan) in the EXPLANATION, in L09 (EN and DE) and
  in the comment of `solution/playbook.yml`; `poll` wording based on the L09 measurements;
  bonus 2 (Debian drop-in directory vs. RedHat without an include line); new measured facts on
  init times, database paths, the exit code of the unit right after the init, and the timer.
  Rebuild: *none*
- Exercises 2.04, 2.05 and 2.06 (EN and DE): deeper `EXPLANATION.md` in the same fixed order
  (what the check verifies and what it does not test, how it works, per-family table, pitfalls
  with measured facts, real-world notes, further reading with links to the lessons L04, L05 and
  L06) and a third hint that shows the skeleton of the play instead of only pointing to the
  solution. 2.04: the README and hint 2 say that rocky and alma have no `/etc/sysctl.d` (the
  module fails instead of creating it); hint 1 no longer suggests strings (the module takes the
  value as text); the EXPLANATION drops the claim that OpenRC skips its `sysctl` service inside
  containers (the lab image does not enable it) and explains, from the module source, when
  `reload` runs `sysctl -p` on the whole file, that a misspelled key is persisted without an
  error, and which targets read `/etc/sysctl.d` at start. 2.05: what the allow and deny lists
  control, which files the daemons skip silently, the shipped `cron.deny` per family (measured
  for L06). 2.06: what the check does not catch (`\S`, `\l`, `\n`), who shows `issue`,
  `issue.net` and `motd` on each target (sshd `Banner none` everywhere), the generated message of
  the day on Debian and Ubuntu, and fedora's symlinked `issue` files. Rebuild: *none*
- Exercises 3.03, 4.05 and 4.06 (EN and DE): deeper `EXPLANATION.md` in the same fixed order
  (what the check verifies and what it does not test, how it works, per-family table, pitfalls
  with measured facts, real-world notes, further reading with links to the lessons L08 and L10)
  and a third hint that shows the skeleton of the play instead of only pointing to the solution.
  4.06: the claim that `pam_faillock` denies a locked account in the PAM account phase is
  corrected - it never denies there, a key login of a locked account succeeds, and on the lab's
  Red Hat hosts it even cleared the failure records (newer Linux-PAM builds keep them); measured
  that a second `authselect enable-feature` prints nothing and changes nothing. 3.03: README no
  longer says Alpine has no PAM (it has PAM for the shadow tools, but no password stack), the apt
  requirement says not to rely on `cache_valid_time`, the drop-in requirement says to create
  `pwquality.conf.d` (absent on Debian and Ubuntu), and the `chpasswd` bonus is reworded: as root
  `chpasswd` goes through `common-password` on Debian/Ubuntu (warning only without
  `enforce_for_root`, refused with it), not at all on the Red Hat hosts, and a ready-made hash
  bypasses pwquality everywhere; the EXPLANATION says that the check's PAM assertion is already
  true on fresh Red Hat hosts. 4.05: when facts are read, that `sshd -T` without root yields
  `unknown` (accepted by the check), and that `gather_timeout` does not limit executable facts
  (answer to bonus 2); the AWX/AAP paragraph no longer shows untested filter syntax. 3.02: the
  README lists the hosts that already default to `YESCRYPT` correctly (also Ubuntu 26.04 and
  Rocky/Alma 10; openSUSE uses `SHA512`, Alpine has no `ENCRYPT_METHOD` line). Rebuild: *none*
- Exercises 0.01, 0.02, 0.03 and 0.04 (EN and DE): deeper `EXPLANATION.md` in the same fixed
  order (what the check verifies and what it does not test, how it works, per-family table,
  pitfalls with measured facts, real-world notes, further reading with links to the lesson L00
  and the documentation) and a third hint that shows the skeleton (the commands of 0.01, the
  plays of 0.02-0.04, the template loop of 0.03) instead of only giving the answer. 0.02: the
  idempotency part of `lab check 0.02` runs `--check`, where `raw` is skipped, so it cannot see
  a missing guard or `changed_when` - the README comment and L00 (EN and DE) now say so and ask
  for two real runs; measured: what `raw` returns (`\r\n`, no stderr noise), how `become` wraps
  the command, what the missing index and Python cost on Alpine (14 packages, about 40 MB, not
  50 MB). 0.01: no longer says that Ansible copies a file to the target (pipelining feeds the
  module through the SSH session); the README says the failing host appears on a fresh lab only.
  0.03: a host without facts (failed or unreachable) has an empty `ansible_facts`; the
  `run_once` variant, a measured facts table, and that a hand-typed file passes the check.
  0.04: `mode: 644` ends up as `1204`, `copy` replaces fedora's symlinked `issue.net`, sshd
  sends the banner verbatim, and what the check misses (other escapes, version numbers, another
  distribution's name, and the shipped "Arch Linux" text). Rebuild: *none*
- 2.03, 3.01, 4.02, 4.03 and 5.01: the reference solutions write the module rules to
  `/etc/modprobe.d/00-cis-<module>.conf` instead of `cis-<module>.conf`, and the 2.03 check (also
  run by the checks of 3.01, 4.03 and 5.01) expects that name - **rename the `dest` of your own
  playbooks and roles**. The check also asks kmod which rule applies (`modprobe --show-depends
  <module>` on every target but alpine, whose BusyBox ignores `install`) and, with
  `-e cis_level=2`, checks the six Level 2 modules too. Old `cis-<module>.conf` files on the
  targets are harmless (`00-cis-` sorts first); `./lab.sh reset all` removes them. 2.03 README
  (requirement, bonus questions), hint 3 and EXPLANATION, the 3.01 EXPLANATION and the 4.02 hint
  are updated. Rebuild: *none*
- `lab-view` (and so `lab show`, `lab view`, `lab docs`, `md` and `less` on a Markdown file)
  shows a link by its text only, no longer followed by its target in brackets. A web link stays
  clickable in terminals that support OSC 8 hyperlinks (`less -R` passes them through); a link
  to another lab file is shown as styled text. Piped output (no terminal, or `LAB_PLAIN=1`) is
  unchanged. Rebuild: *none*
- `exercises/INDEX.md` has a *Lesson* column that links the lesson(s) preparing each exercise;
  `docs/LEARNING_PATH.md` has a *Lessons* section (what a lesson is, `lab lesson`, a table of all
  lessons with the exercises they prepare and their reading time), a *Lessons* row in the
  mechanism table and "read the lesson first" as step 1 of the working style. Both languages.
  The static gate builds the INDEX column (check `meta`) and the LEARNING_PATH table (check
  `lessons`) from the lesson headers and fails when they drift. Rebuild: *none*
- Static gate: the `parity` check compares a link to a heading by the heading's position, so a
  DE link may carry the translated anchor (`L02-safe-changes.de.md#check-modus-...`); the anchor
  of a heading with an underscore inside a word (`async_status`, `no_log`) keeps the underscore,
  as on GitHub - the gate used to drop it. Rebuild: *none*

### Fixed
- 5.01: `ansible-playbook site.yml --check` changed the targets in enforce mode. The
  reference role ran its controls with `apply: {check_mode: "{{ cis_mode == 'audit' }}"}`,
  which is `false` when enforcing and overrides `--check` - so the idempotency run of
  `lab check 5.01` was a real enforce run, not a dry run. The keyword is now
  `ansible_check_mode or cis_mode == 'audit'` (as in L10), and a dry run in enforce mode
  reports a deviation as `fail` instead of `fixed`. Hint 2 corrected. Rebuild: *none*
- 3.01 and 4.03: the directory helper tasks `Ensure /etc/sysctl.d exists` and `Ensure
  /etc/modprobe.d exists` of the reference roles carried only the section tag, so `--tags
  sysctl` failed on a host without the directory (fresh rocky and alma: `No such file or
  directory` from `ansible.posix.sysctl`). They now carry the topic tags `sysctl` and
  `modules`. The 3.01 EXPLANATION is updated, the 4.03 EXPLANATION lists the 6.3 dry-run
  case. Rebuild: *none*
- 5.01: a Level 2 audit (`-e cis_mode=audit -e cis_level=2`) or `--check` on fresh hosts
  failed on seven of eight hosts at 6.3: `lineinfile` on `/etc/audit/auditd.conf`, a file only
  the package install creates, fails in check mode. The task is skipped while the install is
  still pending (`cis_r_1 is changed` in a dry run), so the audit reports 6.3 as `fail`. Also,
  `include_vars` of the role is tagged `always`: any `--tags` selection failed at the apt index
  task (`cis_apt_cache_refresh` undefined) and is now a harmless no-op - select controls with
  `cis_controls_only`. EXPLANATION updated. Rebuild: *none*
- openSUSE: the module rules of 2.03, 3.01, 4.02, 4.03 and 5.01 did not apply to `cramfs`,
  `freevxfs`, `hfs`, `hfsplus` and `jffs2`. The vendor files
  `/usr/lib/modprobe.d/60-blacklist_fs-<fs>.conf` sort before `cis-...`, and their `install`
  line (`unblacklist`, which does nothing without a terminal, then `modprobe --ignore-install`)
  loads the module; the check read only the files and passed. With the `00-cis-` names (see
  *Changed*) `install /bin/false` applies on all seven kmod targets, and the check fails when
  another file wins. Rebuild: *none*
- Lesson L05 (EN and DE): self-check question 5 assumed that `modprobe -n -v` prints
  `install /bin/false` for a module that `lsmod` lists. kmod's dry run prints nothing for a
  module the kernel has loaded already (measured on the seven kmod targets with a module of the
  host kernel), so the question now starts from that output and the answer points to
  `modprobe --show-depends`. A pitfall row says the same, the openSUSE paragraph names the
  `00-...` file name and `--show-depends`, and `modprobe -c` is described as the merged
  configuration in reading order, not the effective one (it lists every `install` line). The
  catalogue note of control 1.1.1 in `cis/controls.yml` mentions the openSUSE vendor rules.
  Rebuild: *none*
- Link pass over all 115 external URLs (checked with curl on 2026-11-08: 114 answer 200, the
  Alpine wiki sends `curl` a bot challenge): the 57 links to the
  Ansible documentation now point to `docs.ansible.com/projects/ansible/latest/...`, where the
  old `docs.ansible.com/ansible/latest/...` addresses redirect. Lesson L06 (DE) linked the
  English `CONTAINER_LIMITS.md`, eight links in the German EXPLANATIONs of 4.04, 4.07, 5.02 and
  5.03 named the lessons by their English titles, and the 1.02 EXPLANATION did not link L02, one
  of its two lessons - fixed. The static gate (`links`) now fails when a German page links the
  English twin of a page or an English page links a German one (the language switch line
  excepted). Rebuild: *none*


## [1.4.0] - 2026-11-03

### Added
- `tools/static-check.sh`: static quality gate that needs no containers - `yamllint --strict`,
  `ansible-lint --profile production` on every `solution/` (4.04 with its vault password, 5.02
  against the 5.01 reference role), and `tools/static_check.py`:
  - *meta*: `meta.yml` schema (keys, types, id/slug/stage vs. directory, stage names), required
    files, three hints per language, `solve` file exists and runs on `hosts`, README header
    table and `exercises/INDEX*.md` rows match `meta.yml`;
  - *parity*: every EN Markdown file has a `.de.md` twin with the same headings, list items,
    table lines, code blocks and link targets (exceptions listed in the script, see G8).
    Code blocks with an info string (`bash`, `yaml`) must contain the same code - comments may
    be translated; a deliberate difference is marked with `<!-- parity: lang-specific -->` on the
    line before the DE block (used once: `lab lang de` in the quick start of `README.de.md`);
  - *links*: relative Markdown links and `#anchors` resolve;
  - *controls*: `cis/controls.yml` schema, referenced exercises exist, and every CIS id named
    in an exercise's `meta.yml` is a control that lists the exercise at a matching level.

  Run it on the host or in the control node (`docker compose exec control /lab/tools/static-check.sh`);
  `tools/static-check.sh lint links` runs single checks.
- GitHub Actions workflow `release-check`: new job `static` runs the gate on every pull request,
  push to `main` and tag.
- `control/requirements.txt`: pinned Python packages of the control node (ansible 14.5.0,
  ansible-lint 26.10.1, yamllint 1.38.0, ...), used by the image **and** the CI job, so
  `ansible-lint` in the lab reports exactly what CI reports. `.github/dependabot.yml` proposes
  weekly updates for these pins and for the GitHub Actions used.
- `LAB_WORK_DIR` overrides the work directory (default `/lab/work`): `lab` exports it together
  with a matching `ANSIBLE_ROLES_PATH` (`<work-dir>/roles`, unless already set), and every
  `check.sh`/`check.yml` and the solutions of 0.03, 4.01 and 4.05 that read or write files in
  `work/` follow it. Learners see no difference.
- `tools/stage-solution.sh <id> <work-dir>`: copies a reference solution into a work directory
  the way a learner lays it out (roles under `<work-dir>/roles/`), so `lab check` can verify the
  solution itself, including the idempotency run - groundwork for running the checks in CI.
  Rebuild: *none*
- `meta.yml` key `requires`: the exercises whose result an exercise technically builds on
  (target state or files in `work/`, not the suggested learning order) - e.g. 0.02 (Python on
  Alpine) for every exercise that gathers facts on Alpine, 3.01-3.05 for 4.03, 5.01 for 5.02.
  `lab start` warns (without blocking) when one of them is not passed yet; the static gate
  checks that the ids exist, are earlier than the exercise and sorted. Rebuild: *none*
- 3.01 starter: `lab start 3.01` also creates an empty role skeleton in `/lab/work/roles/cis`
  (the section task files, `defaults/`, `vars/default.yml`, `handlers/`, `templates/`,
  `meta/main.yml`) whose TODO comments say which exercise goes where. Generally, a
  `starter/roles/<name>/` directory goes to `work/roles/`; existing files are never
  overwritten. `docs/LEARNING_PATH` explains that later stages have no starters. Rebuild: *none*
- `docs/lessons/TEMPLATE.md` (+ `.de.md`): template for the upcoming self-study lessons - one
  lesson per topic with learning goals, theory, CIS background, platform differences, pitfalls,
  links to the exercises it prepares and self-check questions with folded answers. Lessons
  explain concepts before an exercise and never show its solution (that stays in
  `EXPLANATION.md`). Rebuild: *none*
- Static gate check `lessons` (`tools/static-check.sh lessons`): every file in `docs/lessons/`
  is named `LNN-slug(.de).md`, starts with `# LNN - <title>`, the language switch and the header
  table; exercises, CIS ids (`cis/controls.yml`) and prerequisite lessons in that table exist,
  are sorted and earlier; the eight sections of the template appear in order; the exercises
  table lists exactly the header's exercises; every self-check question has one folded answer
  and `<details>` appears nowhere else; EN and DE header values match. The template itself is
  checked for structure only. Rebuild: *none*

### Changed
- Control image installs its Python packages from `control/requirements.txt` instead of
  unpinned names; the build argument `ANSIBLE_VERSION` is gone (edit the file instead).

### Fixed
- 5.01 role report under `serial` (5.02 rollout): the report iterated over
  `ansible_play_hosts`, which in a batched play also lists the hosts of later batches - the
  first batch aborted with `has no attribute 'cis_summary'`. The report now lists every host
  that has a summary (canary and earlier batches included); the last batch writes the complete
  report, 5.01 is unchanged. 5.01 hint corrected, 5.02 EXPLANATION explains
  `ansible_play_hosts` vs. `ansible_play_batch`. Rebuild: *none*
- 5.02 reference preflight: "Enough free space on /" failed on every target with "only 0.0 MB
  free" - `ansible_facts.mounts` skips mounts whose device does not start with `/`, so the
  container's `overlay` root has no entry and `default(0)` applied. Free space now comes from
  `df -Pk /` (POSIX, busybox too); the hint suggested the facts and is corrected. 5.02
  EXPLANATION and CONTAINER_LIMITS explain the facts gap and thin provisioning (a VHDX/qcow2
  reports its virtual capacity, not the space left on the storage behind it). Rebuild: *none*
- 4.08: the reference solution was not idempotent - with `poll: 0` the init task reports
  `changed` as soon as the background job starts, `creates:` only acts inside the job. It now
  checks for the database with `stat` first and skips the init. EXPLANATION and hint corrected
  (they claimed `--check` shows `skipped`); TROUBLESHOOTING explains the harmless
  `junk after the JSON data: ]3008;...` warning of async tasks. Rebuild: *none*
- 4.04 on Arch: shadow 4.20 removed the minimum password age (`chage -m/--mindays`,
  `PASS_MIN_DAYS`, `sp_min`), so the reference solution failed in `ansible.builtin.user`
  (`password_expire_min`). Solution and check now ask `chage --help` and set/require the minimum
  age only where it still exists. 4.04 explains the feature detection, 3.02 and
  `cis/controls.yml` (5.4.1) mention the removal. Rebuild: *none*
- 4.03 / 5.01 checks also recognise a quoted level (`-e 'cis_level="2"'`,
  `-e '{"cis_level": "2"}'`); `lab help` no longer shows a fixed `/lab/work` for `lab start`;
  `tools/stage-solution.sh` prints its next commands shell-quoted. Rebuild: *none*
- 3.03, 3.04, 4.07, 4.08 reference solutions: the apt index refresh also runs under `--check`
  (`check_mode: false`, as in the 4.03/5.01 roles). Before, `--check` on a freshly reset
  Debian/Ubuntu host failed with `No package matching ...`, because the apt module skips the
  update in check mode. 4.01 German hint: "then" -> "dann". Rebuild: *none*
- Static gate (*meta*): a malformed exercise id (`x5.02`, `5.0x`, `5.3`) is reported instead of
  aborting the check with a Python `ValueError`. Rebuild: *none*
- `tools/stage-solution.sh` and `lab`: the exercise id must look like `3.01`. An id such as
  `../stage3-intermediate/3.01` used to resolve and made `stage-solution.sh` remove and write
  directories outside the work directory. Rebuild: *none*
- 3.02 check on openSUSE: with the vendor split there is no `/etc/login.defs`, the defaults
  (`ENCRYPT_METHOD SHA512`) live in `/usr/etc/login.defs`. The check read only `/etc` and
  reported `ENCRYPT_METHOD=NONE`; it now uses `/etc/login.defs` or else the vendor file, plus
  the drop-ins of both, as the README already describes. Rebuild: *none*
- Debian/Ubuntu: the target images ship without an apt package index, so every package
  install failed with `No package matching ...` (3.03, 3.04, 4.07, 4.08 and the roles of 4.03
  and 5.01 - in 4.03 the whole run aborted on the Debian family). The reference solutions now
  refresh the index when no `*_Packages*` file exists in `/var/lib/apt/lists` or it is older
  than a day (`cache_valid_time` alone treats the empty index as fresh, because apt judges the
  age by the directory's mtime), with `changed_when: false`; in the roles via the platform flag
  `cis_apt_cache_refresh`. 3.03/3.04 READMEs and TROUBLESHOOTING tell learners. Rebuild: *none*
- Alpine (OpenRC): `service_facts` reports no `status` for OpenRC services, only their
  `runlevels`. The 2.05 check therefore always failed on Alpine (cron never "enabled"), and
  the 1.04 check and the 4.01 solution could not notice an enabled vsftpd there. "Enabled" now
  means `status == 'enabled'` or the service is in the `default` runlevel. Rebuild: *none*
- 1.05 check and 5.02 reference preflight: openSUSE Leap 16 ships `/usr/etc/sudoers` with mode
  0444, so `visudo -c` exits 1 even on an untouched host and the check could never pass there.
  Exactly that message is now tolerated; syntax errors and bad permissions in `/etc` still fail.
  1.05 explains the `/usr/etc` vendor split, the 5.02 hint mentions it. Rebuild: *none*
- `sshd -T` keywords are compared case-insensitively. OpenSSH 10.6 (Arch) prints
  `PermitRootLogin no` instead of `permitrootlogin no`, which broke the checks of 1.03 and 2.02
  on Arch and would break the 4.01, 4.05 and 5.02 solutions. 1.03 explains the change; the
  4.01/4.05 hints show the case-insensitive variant. Rebuild: *none*
- 4.03 / 5.01: the regression checks now include 3.04 (auditd, CIS Level 2) when the check
  gets `-e cis_level=2` (`lab check 4.03 -e cis_level=2`), as the READMEs require; at level 1
  the check says that 3.04 was skipped. The READMEs show the level 2 run and check.
- 3.03 names the task file for the role (`section5_pam.yml`) that the 4.03 check expects.
  Rebuild: *none*
- `cis/controls.yml`: control 5.2 (privilege escalation) now lists exercise 4.04, which
  configures sudo for the break-glass account and names 5.2 in its CIS reference.

Rebuild: *control* (pins the linter versions in the image)

## [1.3.3] - 2026-10-27

### Removed
- Stray `ansible-cis-lab/` subdirectory: a complete, outdated copy of the repository
  (437 files) that had been committed by accident and was part of the 1.3.2 archive.
- Compiled Python bytecode `control/__pycache__/lab-viewcpython-313.pyc` (and its copy).

### Fixed
- Executable bit in git for `control/live-wrapper`, `targets/common/bootstrap.sh`,
  `targets/common/lab-keysync` and `exercises/_common/run_checks.sh`.

### Added
- `tools/release-check.sh`: fails on tracked bytecode, nested repository copies, archives or
  patch leftovers, missing executable bits and (with a tag argument) a missing CHANGELOG section.
- GitHub Actions workflow `release-check` runs it on every pull request, push to `main` and tag.

### Changed
- Shell prompt in the control node no longer shows the git branch and status of `/lab`
  (`SCM_CHECK=false` in `control/skel-bashrc`; set it to `true` to get it back). The lab
  repository is not what learners work on, so the information was noise and each prompt ran git.
- Control image sets `PYTHONDONTWRITEBYTECODE=1`, so nothing writes `__pycache__` into the
  mounted repository.
- `.gitignore`: also ignore `/ansible-cis-lab*/`, `*.zip`, `*.patch`, `*.orig`, `*.rej`.

Rebuild: *none* (optional *control* for `PYTHONDONTWRITEBYTECODE`)

## [1.3.2] - 2026-10-25

### Fixed
- Control node clock showed UTC instead of the host time: `lab.sh` / `lab.ps1` detect the host
  time zone (IANA name) and pass it as `TZ`; the image now contains `tzdata`. Targets stay on
  UTC on purpose (server best practice, consistent logs). Override with `LAB_TZ=Europe/Berlin`.
  Plain `docker compose up` without the wrappers keeps UTC.

Rebuild: *control*

## [1.3.1] - 2026-10-25

### Added
- `CHANGELOG.md`.

### Fixed
- `control/lab`, `control/lab-view`, `control/lab-lesspipe`, `control/bashrc.sh` in the
  repository were still pre-1.2.0 versions; since 1.3.0 the live wrapper runs them directly,
  so `lab docs`, `lab view` and `less *.md` failed (`unrecognized arguments: --render`).
- `less` on a markdown file silently falls back to the raw text if rendering fails,
  instead of printing a Python usage error.

### Changed
- `.gitignore`: ignore `__pycache__/` and `*.pyc`.

Rebuild: *none*

## [1.3.0] - 2026-10-25

### Added
- Live wrapper (`control/live-wrapper`): `/usr/local/bin/lab`, `lab-view` and `lab-lesspipe`
  run the current version from `/lab/control/`, falling back to the copy baked into the image.
  Interpreters are called explicitly, so lost execute bits (Windows, ZIP) do not matter.
- `~/.bashrc`, `/etc/bash.bashrc` and `/etc/vim/vimrc.local` load their configuration from the
  repository as well.
- Bash history is stored in `.lab/bash_history` and survives container recreation.
- README: section *Updating the lab* - what survives an update, what is reset, backup.

Rebuild: *control* (last rebuild needed for script changes)

## [1.2.0] - 2026-10-25

### Added
- Control node: full `vim` with lab defaults (syntax, 2-space YAML, cursor column, Jinja for `*.j2`).
- Control node: [oh-my-bash](https://github.com/ohmybash/oh-my-bash) system-wide (theme `font`,
  plugins git/colored-man-pages/sudo), tab completion for `lab`, aliases `md`, `ap`, `al`.
- `lab view <file.md>` and `lab docs [name]` (localized guides).
- `less <file.md>` renders markdown via a `LESSOPEN` filter (`control/lab-lesspipe`).
- Host: `./lab.sh view <file.md>` / `.\lab.ps1 view <file.md>` (paths relative to the caller).
- README: section *Control node comfort*.

Rebuild: *control*

## [1.1.0] - 2026-10-25

### Added
- `control/lab-view`: terminal renderer based on Rich - headings, tables, task-list checkboxes,
  highlighted code; solutions with syntax highlighting and line numbers; pager for long output;
  plain text when piped or with `LAB_PLAIN=1`.
- `lab placement` shows only the questions; `lab placement answers` shows the key.

### Fixed
- `less` reported exercise texts as binary files: the control image now sets a UTF-8 locale
  (`LANG`/`LC_ALL=C.UTF-8`, `LESSCHARSET=utf-8`).
- `lab status`, `lab.sh`/`lab.ps1` and exercise 0.01 no longer use `ansible -o`
  (oneline callback, deprecated in ansible-core 2.21, removed in 2.23). `lab status` uses the
  JSON callback: sorted, aligned, shows UNREACHABLE/FAILED with the reason, exit code 1 on problems.

Rebuild: *control*

## [1.0.1] - 2026-10-22

### Fixed
- `targets/common/bootstrap.sh`: create `/usr/local/sbin` and `/etc/systemd/system` before
  installing into them (missing on some minimal base images).

Rebuild: *targets*

## [1.0.0] - 2026-10-22

### Added
- Docker lab: control node (ansible 14 / ansible-core 2.21, ansible-lint, yamllint) and eight
  targets - Debian 13, Ubuntu 26.04, Rocky 10, AlmaLinux 10, Fedora 44, openSUSE Leap 16,
  Arch, Alpine 3.24 - with systemd/OpenRC and deliberately non-compliant starting state.
- 31 exercises in 6 stages (EN/DE): README, 3 graded hints, explanation, reference solution,
  automatic state + idempotency check; placement test; `lab` CLI; `lab.sh` / `lab.ps1`.
- Own CIS control catalogue `cis/controls.yml`, docs (learning path, container limits,
  troubleshooting).

[Unreleased]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.3...v1.4.0
[1.3.3]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/tokitaari/ansible-cis-lab/releases/tag/v1.0.0
