# 4.02 - Profiles (Level 1/2) and documented exceptions

## Hint 1

Preflight first: an `assert` task looping over `cis_exceptions` with `that:` checks for `item.id in known_ids`, `item.reason | default('') | length > 0`, `(item.expires | string | to_datetime('%Y-%m-%d')) > now()`. Note `| string`: YAML turns `2027-01-31` into a date object.

## Hint 2

Compute `cis_exception_ids: "{{ cis_exceptions | map(attribute='id') | list }}"`. Wrap each control in a `block:` with `when: cis_level | int >= N and 'id' not in cis_exception_ids` - blocks pass `when` to every task inside. Task names inside the block start with the id.

## Hint 3

Reference: `lab solution 4.02` (role `cis_profile`). To see what the check does: `cat $(dirname $(ls -d /lab/exercises/*/4.02-*))/4.02-*/check.sh`.
