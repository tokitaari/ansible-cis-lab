# 3.01 - Refactor everything into a role

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 3 - Intermediate | ★★★☆☆ | ~90 min | Sections 1, 2, 3, 5, 7 (L1) | `targets` |

**Concepts:** `roles`, `defaults vs vars`, `include_vars + first_found`, `import_tasks`, `tags`, `ansible-lint`

## Goal

Turn the playbooks of stages 0-2 into one reusable role `cis` that hardens all eight hosts in one run.

## Background

Twelve separate playbooks do not scale. A role bundles tasks, defaults, variables,
templates and handlers behind a clear interface: *defaults* are the knobs a user may
turn, *vars* are internal platform data. Tags let you run one CIS section or one
topic (`--tags ssh`). From now on every exercise extends this role.

## Requirements

- [ ] Role at `/lab/work/roles/cis` (that path is in `roles_path`) with at least `tasks/`, `defaults/`, `vars/`, `handlers/`, `templates/`, `meta/`.
- [ ] `tasks/main.yml` loads `vars/<os_family>.yml` (fallback `vars/default.yml`) and imports one task file per CIS section: `section1_initial_setup.yml`, `section2_services.yml`, `section3_network.yml`, `section5_access_control.yml`, `section7_maintenance.yml`.
- [ ] Each import is tagged `section1` ... `section7`; tasks additionally carry topic tags (`ssh`, `sudo`, `cron`, `sysctl`, `modules`, `banners`, `packages`, `services`, `permissions`).
- [ ] All tunables live in `defaults/main.yml` with the prefix `cis_` (ansible-lint enforces role prefixes). Platform differences (service names, shadow group/mode, cron.allow support) live in `vars/`.
- [ ] Playbook `/lab/work/3.01/site.yml` applies the role to `targets`.
- [ ] The role content covers exercises 0.04-2.06; all their checks pass after **one** run on freshly reset hosts (`./lab.sh reset all`, then 0.02 for Alpine).
- [ ] `ansible-lint --offline /lab/work/roles/cis` passes (moderate profile or better).

## How to work

```bash
lab start 3.01            # creates /lab/work/3.01/
cd /lab/work/3.01
# write site.yml, then run it:
ansible-playbook site.yml
lab check 3.01            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 3.01 1` (gentle) ... `lab hint 3.01 3` (almost the answer).  
Passed? Read `lab explain 3.01` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- `ansible-galaxy role init --init-path /lab/work/roles cis` creates the skeleton - compare it with what you really need.
- Run only SSH: `ansible-playbook site.yml --tags ssh`. List everything: `--list-tags`, `--list-tasks`.
- Make Alpine's Python bootstrap (0.02) a `pre_tasks` block in `site.yml` - why not inside the role?
