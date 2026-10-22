# 4.02 - Profiles (Level 1/2) and documented exceptions: Explanation

### The pattern
```yaml
- name: L2-modules | Level 2 kernel modules
  when:
    - cis_level | int >= 2
    - "'l2-modules' not in cis_exception_ids"
  block:
    - name: L2-modules | Disable squashfs and udf
      ansible.builtin.copy: ...
```
`when` on a block is inherited by each task → skipped tasks show up as *skipped* in
the output and in the JSON callback, which is exactly what the check inspects.

### Validate input before touching anything
Hardening roles receive input from many people (inventory, CI variables, `-e`). A
typo in an exception id silently disables nothing - or worse, the wrong thing. Fail
fast with a clear message. The date check turns a forgotten exception into a failed
pipeline instead of a permanent hole.

### YAML dates
`expires: 2027-01-31` is parsed as a `date` object by YAML; `"2027-01-31"` stays a
string. `| string | to_datetime('%Y-%m-%d')` normalises both.

### Contract testing
The check never looks at your files. It runs the playbook with `ANSIBLE_STDOUT_CALLBACK=ansible.posix.json`
and evaluates which tasks were skipped. That is how you test infrastructure code from
the outside - and why stable task names matter.

### Real world
Keep exceptions in Git next to the inventory (`group_vars/<env>/cis_exceptions.yml`),
changed only via reviewed merge requests, with the ticket number in `reason`. The
compliance report (5.01) lists them so auditors see the full picture.

## Reference solution

Show it with `lab solution 4.02`, apply it with `lab solve 4.02`.
