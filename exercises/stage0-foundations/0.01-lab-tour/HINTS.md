# 0.01 - Lab tour: inventory and connectivity

## Hint 1

`ansible-inventory` has `--graph`, `--list` and `--host <name>`. Ad-hoc syntax: `ansible <pattern> -m <module> [-a <args>]`.

## Hint 2

The failing host complains about the Python interpreter. Look at which distribution it is and what is *not* installed there.

## Hint 3

The commands in order - replace every `...`. The `ping` error names the interpreter that is missing; `raw` needs no Python on the target.

```
ansible-inventory --graph
ansible-inventory --host ...
ansible ... -m ansible.builtin.ping
ansible ... -m ansible.builtin.raw -a '...'
```

Reference: `lab solution 0.01`.
