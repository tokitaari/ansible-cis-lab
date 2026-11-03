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
  it with `lab view docs/lessons/L00-lab-and-ansible-basics.md` (`lab lesson` follows).
  Rebuild: *none*
- Lesson L01 *CIS Benchmarks: structure, levels and the lab catalogue* in `docs/lessons/` (EN
  and DE): what a Benchmark is and how it is made (consensus process, licence, CIS Controls,
  CIS-CAT), the fields of a recommendation, *Automated* vs. *Manual*, why recommendation numbers
  move between versions, Level 1/2 and Server/Workstation profiles, mapping audit and
  remediation to Ansible tasks (and what does not automate), exceptions, and how
  `cis/controls.yml` and the exercises' `meta.yml` connect to the PDFs - with a tested play
  that queries the catalogue, container values, pitfalls and self-check questions. Background
  for all exercises, applied directly in 4.01, 4.02 and 5.03. Read it with
  `lab view docs/lessons/L01-cis-benchmarks.md`. Rebuild: *none*
- Lesson L02 *Safe changes: check mode, validate, handlers and conditionals* in
  `docs/lessons/` (EN and DE): what `--check --diff` can and cannot predict (skipped
  `command` tasks, `check_mode: false`, `diff: false`), what `validate` proves and what it
  does not, handlers (run once, `flush_handlers`, `listen`, `force_handlers`, lost handlers
  after a failure), conditionals with `package_facts`, `failed_when` instead of
  `ignore_errors`, and ordering a risky change (`--limit`, `--step`, `backup`,
  `block`/`rescue`) - with tested examples, platform table, pitfalls and self-check
  questions. Prepares 1.01-1.05. Read it with `lab view docs/lessons/L02-safe-changes.md`.
  Rebuild: *none*

### Changed
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
