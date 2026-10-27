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

[Unreleased]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.2...HEAD
[1.3.2]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/tokitaari/ansible-cis-lab/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/tokitaari/ansible-cis-lab/releases/tag/v1.0.0
