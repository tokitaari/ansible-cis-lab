# 5.01 - Capstone: CIS role with audit and enforce mode

## Hint 1

Start from your 4.03 role. Move each section's tasks into small files under `tasks/controls/`, one per control id, and create the registry list. Everything that is not a control (vars loading, preflight, report) stays in `main.yml`.

## Hint 2

`include_tasks` + `apply: {check_mode: "{{ cis_mode == 'audit' }}"}` runs a whole file in check mode. Read-only tasks keep `check_mode: false` - task keywords beat inherited ones. A finding is a registered result with `changed: true` or (for `command`) `msg` 'Command would have run if not in check mode'. Handlers need `when: cis_mode == 'enforce'`.

## Hint 3

Report: on `localhost` with `run_once` + `delegate_to: localhost`, `check_mode: false`; collect every host that has a `cis_summary`: `groups['all'] | map('extract', hostvars) | selectattr('cis_summary', 'defined') | map(attribute='inventory_hostname')` - not `ansible_play_hosts`, which under `serial` (5.02) also lists hosts that have not run yet. The complete reference: `lab solution 5.01` - compare *after* you have your own version.
