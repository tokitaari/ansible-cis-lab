# 3.01 - Refactor everything into a role: Explanation

### Layout of the reference role
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

### defaults vs vars
| | `defaults/` | `vars/` |
|---|---|---|
| precedence | lowest - anything overrides it | high - beats inventory |
| purpose | user-facing knobs (`cis_level`, sshd values) | facts about platforms |
Rule of thumb: if a user might want a different value, it is a default.

### import vs include
- `import_tasks` - static, resolved at parse time; tags/when are copied to every task;
  `--list-tasks` shows everything.
- `include_tasks` - dynamic, resolved at run time; tags apply to the include only
  (unless `apply:`); needed when the file name comes from a variable.
Sections are fixed → `import_tasks`.

### Why `always` on include_vars
With `--tags ssh` Ansible skips untagged tasks. Without the platform vars the handler
would not know `cis_sshd_service` - `always` keeps the role consistent under any tag
selection.

### Testing the refactor
The checks of 0.04-2.06 *are* your regression test suite: reset all hosts, run once,
run all checks. If they pass, the refactor preserved behaviour. That is exactly how
larger hardening roles are developed (Molecule automates the same idea).

### ansible-lint
It catches non-FQCN modules, unquoted modes, missing `changed_when`, unnamed tasks,
role variables without the role prefix - all things that bite later.

## Reference solution

Show it with `lab solution 3.01`, apply it with `lab solve 3.01`.
