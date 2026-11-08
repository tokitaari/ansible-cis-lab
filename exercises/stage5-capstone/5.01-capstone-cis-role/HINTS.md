# 5.01 - Capstone: CIS role with audit and enforce mode

## Hint 1

Start from your 4.03 role. Move each section's tasks into small files under `tasks/controls/`, one per control id, and create the registry list. Everything that is not a control (vars loading, preflight, report) stays in `main.yml`.

## Hint 2

`include_tasks` + `apply: {check_mode: "{{ ansible_check_mode or cis_mode == 'audit' }}"}` runs a whole file in check mode. The `or` matters: `"{{ cis_mode == 'audit' }}"` alone is `false` when enforcing, and `false` overrides `--check` - the dry run would change the targets (see L10). A dry run in enforce mode reports a deviation as `fail`, not `fixed`. Read-only tasks keep `check_mode: false` - task keywords beat inherited ones. A finding is a registered result with `changed: true` or (for `command`) `msg` 'Command would have run if not in check mode'. Handlers need `when: cis_mode == 'enforce'`.

## Hint 3

The role's `tasks/control.yml`, which `tasks/main.yml` runs once per registry entry
(`include_tasks` with `loop: "{{ cis_controls }}"` and `loop_var: cis_control`):

```yaml
- name: "Decide whether the control applies | {{ cis_control.id }}"
  ansible.builtin.set_fact:
    cis_control_state: "..."      # excepted / out-of-profile / not-applicable / active
    cis_control_results: []

- name: "Execute control | {{ cis_control.id }}"
  ansible.builtin.include_tasks:
    file: "..."                   # controls/<file> from the registry entry
    apply:
      check_mode: "..."           # dry run for audit mode and for --check
  when: "..."                     # active controls only

- name: "Record the result | {{ cis_control.id }}"
  vars:
    cis_noncompliant: "..."       # any result or loop item changed, or 'would have run'
    cis_status: "..."             # the state, else fail / fixed / pass
  ansible.builtin.set_fact:
    cis_findings: "..."           # cis_findings + one dict: id, level, title, status, reason
```

Report: on `localhost` with `run_once` + `delegate_to: localhost`, `check_mode: false` and `changed_when: false`; collect every host that has a `cis_summary`: `groups['all'] | map('extract', hostvars) | selectattr('cis_summary', 'defined') | map(attribute='inventory_hostname')` - not `ansible_play_hosts`, which under `serial` (5.02) also lists hosts that have not run yet. The complete reference: `lab solution 5.01` - compare *after* you have your own version.
