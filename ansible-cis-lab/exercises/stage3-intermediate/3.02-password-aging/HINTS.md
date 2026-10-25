# 3.02 - Password aging and inactive accounts

## Hint 1

`lineinfile` with `regexp: '^\s*{{ item.key }}\s'` and `line: "{{ item.key }}\t{{ item.value }}"` replaces the active line or appends one. A `stat` of `/etc/login.defs` decides between the two variants.

## Hint 2

Current ENCRYPT_METHOD: `slurp` the file, then `(content | b64decode | regex_findall('(?m)^\s*ENCRYPT_METHOD\s+(\S+)') | last | default('none'))`. For `useradd -D`: run it once read-only (`changed_when: false`, `check_mode: false`), then only run `useradd -D -f 45` `when: "'INACTIVE=45' not in result.stdout_lines"`.

## Hint 3

Full reference: `lab solution 3.02`. Notice how `check_mode: false` on the *read* tasks keeps `--check` runs meaningful.
