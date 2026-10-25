# 4.01 - Audit-only compliance report

## Hint 1

Collect raw data first (one task per source, all read-only, `check_mode: false` on `command` tasks so they also run under `--check`). Then build the result list in **one** `set_fact` using inline conditionals: `status: "{{ 'pass' if 'telnet' not in ansible_facts.packages else 'fail' }}"`.

## Hint 2

For effective sshd values reuse the parsing trick from the checks: `sshd -T` → `dict(lines | map('regex_replace', '^(\\S+)\\s+(.*)$', '\\1\\t\\2') | map('split', '\\t'))`. Aggregation: second play on `localhost`, iterate `groups['targets']`, read `hostvars[h].cis_results`.

## Hint 3

Score: `(pass_count / (pass_count + fail_count) * 100) | round(1)`. Write JSON with `copy: content="{{ report | to_nice_json }}"`. Full reference: `lab solution 4.01`.
