# 0.02 - Bootstrap Python on Alpine with raw: Explanation

### The pattern
```yaml
- name: Bootstrap Python on Alpine
  hosts: alpine_family
  gather_facts: false          # setup module needs Python
  become: true
  tasks:
    - name: Install python3 if missing
      ansible.builtin.raw: test -e /usr/bin/python3 || { apk add --no-cache python3 && echo INSTALLED; }
      register: bootstrap
      changed_when: "'INSTALLED' in bootstrap.stdout"
    - name: Verify module execution
      ansible.builtin.ping:
```
- The shell guard (`test -e ... ||`) makes the *command* idempotent.
- `changed_when` makes the *report* honest. Both are needed.
- `raw` is skipped in check mode (`--check`) - it cannot predict its effect.

### Pitfalls
- Forgetting `gather_facts: false` → the play dies before your first task.
- `raw` output contains `\r\n` and SSH noise; match with `in`, not `==`.
- `apk add` without `--no-cache` leaves the index in `/var/cache/apk`.

### Hardening perspective
CIS repeatedly asks to "remove unnecessary packages". Python is necessary *for
Ansible*, so it is a conscious trade-off: document it. On appliances where that is
not acceptable you can stay with `raw`/`script` modules or use pull-based tools.
On Alpine, Python is ~50 MB of extra attack surface - small, but not zero.

## Reference solution

Show it with `lab solution 0.02`, apply it with `lab solve 0.02`.
