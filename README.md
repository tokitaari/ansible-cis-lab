# Ansible CIS Hardening Lab

*[Deutsch](README.de.md)*

A self-contained training environment for hardening Linux systems with Ansible along the
CIS Benchmarks - from the first ad-hoc command to a production-grade multi-distro role with
audit mode, exceptions and staged rollout.

```
              ┌─────────────────────────── network "lab" 172.31.250.0/24 ───────────────────────────┐
  you ──► control  ──ssh──►  debian · ubuntu · rocky · alma · fedora · opensuse · arch · alpine
         (ansible-core 2.21,     systemd as PID 1 ................................ OpenRC (busybox init)
          lint, lab CLI)         deliberately non-compliant on first start
```

| | |
|---|---|
| **Targets** | Debian 13, Ubuntu 26.04, Rocky 10, AlmaLinux 10, Fedora 44, openSUSE Leap 16, Arch (rolling), Alpine 3.24 |
| **Exercises** | 31 in 6 stages, ~28 h, each with goal, background, requirements, 3 graded hints, bonus, reference solution, explanation, automatic check |
| **Languages** | English (default) and German: `lab lang de` |
| **CIS** | Level 1 Server profile (+ selected Level 2); own control catalogue in [`cis/controls.yml`](cis/controls.yml); PDFs: see [`cis/README.md`](cis/README.md) |

## Quick start

Requirements: Docker Engine 24+ or Docker Desktop with Compose v2, ~8 GB free disk, 4 GB RAM.
On Windows use WSL2 and clone the lab **inside the Linux file system** (e.g. `~/ansible-cis-lab`, not `/mnt/c/...`).

```bash
./lab.sh up          # build + start (first build takes a while)
./lab.sh shell       # shell in the control node
lab placement        # 10-question placement test → where to start
lab list             # all exercises with your progress
lab start 0.01       # begin
```
Windows PowerShell: `.\lab.ps1 up`, `.\lab.ps1 shell`.

## How an exercise works

```bash
lab show 1.03        # read the task
lab start 1.03       # creates /lab/work/1.03 (= ./work/1.03 on your host - edit with your IDE)
ansible-playbook playbook.yml
lab check 1.03       # state checks + idempotency (--check run must change nothing)
lab hint 1.03 1      # gentle hint ... lab hint 1.03 3 almost the answer
lab explain 1.03     # after passing: pitfalls, alternatives, real-world notes
```
Broke a host? `./lab.sh reset debian` (or `reset all`) recreates it in its original state.

## Control node comfort

| | |
|---|---|
| Shell | bash with [oh-my-bash](https://github.com/ohmybash/oh-my-bash) (theme `font`; change `OSH_THEME` in `~/.bashrc`, themes in `/opt/oh-my-bash/themes`), tab completion for `lab` |
| Editor | `vim` (syntax, 2-space YAML indentation, cursor column for YAML), `nano`; `EDITOR=vim` |
| Markdown | rendered everywhere: `lab view <file.md>`, `md <file.md>`, `less <file.md>`, `lab docs [name]`; from the host `./lab.sh view <file.md>` / `.\lab.ps1 view <file.md>` |
| Aliases | `ap` = ansible-playbook, `al` = ansible-lint --offline |

## Updating the lab

```bash
git pull --ff-only
docker compose build && docker compose up -d     # only needed when Dockerfiles changed
```
Scripts in `control/` (`lab`, `lab-view`, shell and vim config) run **live from the repository** -
a `git pull` is enough. Image changes (packages, oh-my-bash, base images, `targets/`) need the build.

**What survives an update** (all in gitignored folders of your clone):

| Kept | Where |
|---|---|
| your solutions | `./work/` |
| progress (`lab progress`), language, shell history | `./.lab/` |
| SSH key of the lab | Docker volume `lab-keys` (only `./lab.sh destroy` removes it) |

**What is reset:** the targets, whenever their image changes or you run `./lab.sh reset` - they start
non-compliant again (your progress record is kept, `lab check` would fail until you re-apply).
Lost only by `git clean -fdx`, deleting the clone, or a fresh clone elsewhere - back up with
`tar czf lab-backup.tgz work .lab`.

## Learning path

| Stage | Focus | Exercises |
|---|---|---|
| 0 Foundations | inventory, ad-hoc, raw bootstrap, facts, first playbook | 0.01-0.04 |
| 1 Beginner | package, file, copy + validate, handlers, service | 1.01-1.05 |
| 2 Building blocks | variables, loops, templates, per-family data, collections | 2.01-2.06 |
| 3 Intermediate | roles, PAM, password policy, auditd, account audit | 3.01-3.05 |
| 4 Advanced | audit reports, profiles/exceptions, data-driven multi-platform, vault, custom facts, faillock, firewall with rollback, async | 4.01-4.08 |
| 5 Capstone | role with audit/enforce mode, rollout strategy, review of a community role | 5.01-5.03 |

Details: [`docs/LEARNING_PATH.md`](docs/LEARNING_PATH.md) · index: [`exercises/INDEX.md`](exercises/INDEX.md)

## Layout

```
compose.yaml          control + 8 targets (privileged, see docs/CONTAINER_LIMITS.md)
lab.sh / lab.ps1      host wrapper: up, down, reset, shell, and forwarding to 'lab'
control/              control node image, 'lab' CLI
targets/              one Dockerfile per distribution + common bootstrap (plants the findings)
ansible/              ansible.cfg, inventory (grouped by OS family), shared roles
exercises/            stage*/<id>-<slug>/ README, HINTS, EXPLANATION (EN+DE), solution/, check
cis/                  control catalogue + place for your CIS PDFs
docs/                 getting started, learning path, container limits, troubleshooting
work/                 YOUR solutions (mounted to /lab/work)
```

## Important

- Targets run **privileged** with a real init system so that most controls are realistic.
  Some kernel features are shared with your host - the exercises tell you exactly what not
  to activate inside containers. Read [`docs/CONTAINER_LIMITS.md`](docs/CONTAINER_LIMITS.md).
- The lab is for training only: shared SSH host keys per image, key-based passwordless sudo
  for the `ansible` account, deliberately insecure starting state.
