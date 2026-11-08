# 3.02 - Password aging and inactive accounts

## Hint 1

`lineinfile` with `regexp: '^\s*{{ item.key }}\s'` and `line: "{{ item.key }}\t{{ item.value }}"` replaces the active line or appends one. A `stat` of `/etc/login.defs` decides between the two variants.

## Hint 2

Current ENCRYPT_METHOD: `slurp` the file, then `(content | b64decode | regex_findall('(?m)^\s*ENCRYPT_METHOD\s+(\S+)') | last | default('none'))`. For `useradd -D`: run it once read-only (`changed_when: false`, `check_mode: false`), then only run `useradd -D -f 45` `when: "'INACTIVE=45' not in result.stdout_lines"`.

## Hint 3

```yaml
- name: CIS 5.4.1 - password aging and inactive accounts
  hosts: "..."
  become: "..."
  vars:
    cis_login_defs: {PASS_MAX_DAYS: "...", PASS_MIN_DAYS: "...", PASS_WARN_AGE: "..."}
    cis_strong_hash_methods: ["...", "..."]
  tasks:
    - name: Check whether /etc/login.defs exists
      ansible.builtin.stat:
        path: "..."
      register: cis_login_defs_file

    - name: Set password aging in /etc/login.defs
      ansible.builtin.lineinfile:
        path: /etc/login.defs
        regexp: "..."            # the key at the start of an active line
        line: "..."
      loop: "{{ cis_login_defs | dict2items }}"
      when: "..."                # only where the file exists

    - name: Vendor-split systems - create the drop-in directory
      ansible.builtin.file: "..."            # /etc/login.defs.d, 0755 root:root

    - name: Vendor-split systems - set password aging in a drop-in
      ansible.builtin.lineinfile: "..."      # 50-cis.defs, create: true, same loop

    - name: Read the current login.defs
      ansible.builtin.slurp:
        src: /etc/login.defs
      register: cis_login_defs_content
      when: "..."

    - name: Determine the current hashing method
      ansible.builtin.set_fact:
        cis_current_hash: "..."  # last ENCRYPT_METHOD value, upper case, 'none' if missing

    - name: Use SHA512 only when nothing strong is configured
      ansible.builtin.lineinfile: "..."
      when: "..."                # file exists and the method is not in the strong list

    - name: Read useradd defaults
      ansible.builtin.command: useradd -D
      register: cis_useradd_defaults
      changed_when: "..."
      check_mode: "..."          # it only reads: let it run under --check too

    - name: Lock accounts after the inactivity period
      ansible.builtin.command: "..."
      when: "..."                # INACTIVE=45 not yet in the output
      changed_when: true
```

`check_mode: false` on the *read* tasks keeps `--check` runs meaningful. Full reference: `lab solution 3.02`.
