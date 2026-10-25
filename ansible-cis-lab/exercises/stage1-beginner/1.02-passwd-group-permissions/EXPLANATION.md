# 1.02 - Permissions on /etc/passwd and /etc/group: Explanation

### Solution
```yaml
- name: Fix account file permissions
  hosts: targets
  become: true
  tasks:
    - name: /etc/passwd is 0644 root:root
      ansible.builtin.file:
        path: /etc/passwd
        owner: root
        group: root
        mode: "0644"
    - name: /etc/group is 0644 root:root
      ansible.builtin.file:
        path: /etc/group
        owner: root
        group: root
        mode: "0644"
```

### The octal pitfall (bonus)
| You write | YAML sees | Result |
|---|---|---|
| `mode: "0644"` | string | `rw-r--r--` ✔ |
| `mode: 0644` | octal int (YAML 1.1) | works, but ansible-lint warns |
| `mode: 644` | **decimal** 644 = octal 1204 | `-w----r-T` ✘ |
`ansible-lint` has the rule `risky-octal` for exactly this.

### Symbolic modes
`mode: "u=rw,go=r"` is equivalent and self-documenting. Symbolic modes can also
*remove* bits without touching others (`go-w`), which is handy for "at most 0644"
requirements - but then the result depends on the starting state.

### `state: touch` would be wrong
`touch` updates timestamps every run → never idempotent, and it would create
missing files. For the bonus backup files use `stat` + `when` (stage 2) or
`state: file` and accept a failure... better the former.

## Reference solution

Show it with `lab solution 1.02`, apply it with `lab solve 1.02`.
