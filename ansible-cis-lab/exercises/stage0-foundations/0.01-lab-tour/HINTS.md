# 0.01 - Lab tour: inventory and connectivity

## Hint 1

`ansible-inventory` has `--graph`, `--list` and `--host <name>`. Ad-hoc syntax: `ansible <pattern> -m <module> [-a <args>]`.

## Hint 2

The failing host complains about the Python interpreter. Look at which distribution it is and what is *not* installed there.

## Hint 3

`ansible all -m ansible.builtin.ping` fails on `alpine`: there is no `/usr/bin/python3`. `ansible alpine -m ansible.builtin.raw -a 'cat /etc/os-release'` works because `raw` just sends a command over SSH.
