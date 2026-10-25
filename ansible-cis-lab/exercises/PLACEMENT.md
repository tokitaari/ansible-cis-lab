# Placement test

*[Deutsch](PLACEMENT.de.md)*

Ten questions, about ten minutes. Answer honestly without looking anything up, then check
the key at the bottom. The score tells you where to start - you can always go back.

**1.** What does `ansible all -m ansible.builtin.ping` actually test?
a) ICMP reachability b) SSH login + Python module execution c) only DNS resolution

**2.** Why should a file mode be written as `mode: "0644"` and not `mode: 644`?

**3.** A task copies a file. On the second run it reports `ok` instead of `changed`. What is this property called, and why does it matter?

**4.** You need `telnet` removed on Debian, Rocky and Alpine with one task. Which module?

**5.** What is the difference between a handler and a normal task?

**6.** A playbook must use `apt` on Debian and `dnf` on Rocky. Name two ways to express that, and which one scales better to eight distributions.

**7.** What is the difference between `defaults/main.yml` and `vars/main.yml` in a role?

**8.** `import_tasks` vs `include_tasks` - when do you need the dynamic one?

**9.** A `command` task only reads data. What do you add so that it does not report `changed` and still runs under `--check`?

**10.** How would you roll out a firewall change to 500 servers without risking a fleet-wide lock-out? Name at least three techniques.

---

<details>
<summary>Answer key and recommendation</summary>

1. b) - 1 point
2. YAML reads `644` as a decimal integer (= octal 1204). - 1 point
3. Idempotency; repeated runs must not change a compliant system (drift detection, safe re-runs). - 1 point
4. `ansible.builtin.package` with `state: absent`. - 1 point
5. A handler runs only when notified, once, at the end of the play (or on `flush_handlers`). - 1 point
6. `when` conditions per family vs. a variable/dict lookup by `ansible_facts.os_family` (or `package` + vars files). Data-driven scales better. - 1 point
7. defaults = lowest precedence, user-facing knobs; vars = high precedence, internal/platform data. - 1 point
8. When the file name or the loop is only known at run time (variables, loops, per-host decisions). - 1 point
9. `changed_when: false` and `check_mode: false`. - 1 point
10. Any three of: validate before activating, dead-man switch / automatic rollback, canary hosts, `serial` batches, `max_fail_percentage`, preflight with `any_errors_fatal`, post-checks with a fresh connection. - 1 point

| Score | Start with | Tip |
|---|---|---|
| 0-3 | **0.01** | Do every exercise in order, use the hints freely. |
| 4-6 | **1.01** | Skim stage 0, run its solutions (`lab solve 0.02`, `lab solve 0.03`). |
| 7-8 | **2.01** | Do 0.02 (Alpine bootstrap is needed later), then stage 2. |
| 9-10 | **3.01** | Run `lab solve` for 0.02 ... 2.06, then build the role. Avoid the hints. |

Whatever your start: exercise 0.02 must be applied once (Python on Alpine), otherwise many
checks fail on the Alpine host.
</details>
