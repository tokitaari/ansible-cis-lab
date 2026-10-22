# 4.05 - Custom facts: hosts that describe their own hardening: Explanation

### Static vs executable facts
| | static `.fact` | executable `.fact` |
|---|---|---|
| content | JSON/INI written by Ansible | script output |
| answers | "what did we apply?" | "what is true right now?" |
| cost | none | runs on *every* fact gathering |

### No timestamps
`"last_run": "{{ now() }}"` makes the file change every run → never `changed=0`, and
your drift reports become noise. If you need run history, send it to a log or the
report on the control node, not into managed state.

### Facts run as root
Fact gathering runs with the play's privileges (`become: true` here). That is why the
executable fact can call `sshd -T`. It also means: a writable `facts.d` = code
execution as root on the next Ansible run. Keep it `0755 root:root`.

### Using them
`ansible targets -m ansible.builtin.setup -a filter=ansible_local` shows the data.
In AWX/AAP these facts are stored per host (fact caching) and can drive smart
inventories such as "all hosts where `ansible_local.cis.version` < 1.0.0".

## Reference solution

Show it with `lab solution 4.05`, apply it with `lab solve 4.05`.
