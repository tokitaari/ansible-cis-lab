# 4.02 - Profiles (Level 1/2) and documented exceptions

## Hint 1

Preflight first: an `assert` task looping over `cis_exceptions` with `that:` checks for `item.id | default('') in known_ids`, `item.reason | default('') | string | trim | length > 0`, `item.expires is defined` and `(item.expires | string | to_datetime('%Y-%m-%d')) > now()`. Note `| string`: YAML turns `2027-01-31` into a date object. `to_datetime` gives midnight at the start of the day, so `expires` is the first day on which the exception no longer applies.

## Hint 2

Compute `cis_exception_ids: "{{ cis_exceptions | map(attribute='id') | list }}"`. Wrap each control in a `block:` with `when: cis_level | int >= N and 'id' not in cis_exception_ids` - blocks pass `when` to every task inside. Task names inside the block start with the id.

## Hint 3

The role's `tasks/main.yml` as a skeleton - fill in every `"..."`:

```yaml
- name: Preflight | profile level is 1 or 2
  ansible.builtin.assert:
    that: "..."                       # the level as a number: | int
    fail_msg: "..."
    quiet: true

- name: Preflight | every exception is known, justified and not expired
  ansible.builtin.assert:
    that:
      - "..."                         # known id
      - "..."                         # reason is not blank
      - "..."                         # expires is defined
      - "..."                         # expires lies in the future
    fail_msg: "..."
    quiet: true
  loop: "{{ cis_exceptions | default([]) }}"
  loop_control:
    label: "{{ item.id | default('?') }}"

- name: Preflight | collect exception ids
  ansible.builtin.set_fact:
    cis_exception_ids: "..."          # hint 2

- name: Preflight | show active exceptions
  ansible.builtin.debug:
    msg: "..."                        # id, expiry date and reason
  loop: "{{ cis_exceptions | default([]) }}"
  loop_control:
    label: "{{ item.id }}"

- name: L1-telnet | Insecure client packages
  when: "..."                         # id not in the exceptions
  block:
    - name: L1-telnet | Remove telnet
      ansible.builtin.package:
        name: telnet
        state: absent

- name: L1-ssh-maxauthtries | SSH authentication attempts
  when: "..."
  block:
    - name: L1-ssh-maxauthtries | Limit authentication attempts
      ansible.builtin.copy:
        dest: /etc/ssh/sshd_config.d/01-cis-maxauthtries.conf
        content: "..."
        owner: root
        group: root
        mode: "0600"
        validate: "..."               # syntax check of the sshd config, %s is the temporary file

- name: L2-modules | Level 2 kernel modules
  when:
    - "..."                           # level 2 or higher, as a number
    - "..."                           # id not in the exceptions
  block:
    - name: L2-modules | Disable squashfs and udf
      ansible.builtin.copy:
        dest: "/etc/modprobe.d/00-cis-{{ item }}.conf"
        content: "..."                # install <module> /bin/false and blacklist <module>
        owner: root
        group: root
        mode: "0644"
      loop: [squashfs, udf]

- name: L2-audit-identity | Audit identity files
  when:
    - "..."
    - "..."
  block:
    - name: L2-audit-identity | Rules directory
      ansible.builtin.file:
        path: /etc/audit/rules.d
        state: directory
        owner: root
        group: root
        mode: "0750"

    - name: L2-audit-identity | Identity rules
      ansible.builtin.copy:
        dest: /etc/audit/rules.d/50-cis-identity.rules
        content: "..."                # a watch rule per identity file, key identity
        owner: root
        group: root
        mode: "0640"
```

The list of known ids belongs in the role's `vars/`. Reference: `lab solution 4.02`. What the check does: `cat /lab/exercises/stage4-advanced/4.02-*/check.sh`.
