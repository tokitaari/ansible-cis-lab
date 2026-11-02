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

### Changed
- Control image installs its Python packages from `control/requirements.txt` instead of
  unpinned names; the build argument `ANSIBLE_VERSION` is gone (edit the file instead).

### Fixed
- Debian/Ubuntu: the target images ship without an apt package index, so every package
  install failed with `No package matching ...` (3.03, 3.04, 4.07, 4.08 and the roles of 4.03
  and 5.01 - in 4.03 the whole run aborted on the Debian family). The reference solutions now
  refresh the index (`apt: update_cache`, `cache_valid_time: 86400`, `changed_when: false`;
  in the roles via the platform flag `cis_apt_cache_refresh`). 3.03/3.04 READMEs and
  TROUBLESHOOTING tell learners. Rebuild: *none*
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

[Unreleased]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.3...HEAD
[1.3.3]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/tokitaari/ansible-cis-lab/releases/tag/v1.0.0
