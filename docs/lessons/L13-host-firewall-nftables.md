# L13 - Host firewall with nftables: changing the rules you reach the host through

*[Deutsch](L13-host-firewall-nftables.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 4.07 | 4 | ~30 min | L02, L05, L09 |

A host firewall is the one hardening change that can cut the connection it is applied through. A
wrong SSH rule does not make a task fail; it makes the next task, and every later play,
unreachable. Three habits keep that manageable: the firewall lives in a table of its own, so
nobody else's rules are touched; the rules are loaded in a way that can be checked, repeated and
undone; and the change is made with a way back that does not depend on the connection it might
break. A fourth question follows: what is still there after a restart? This lesson covers all
four.

## Learning goals

After this lesson you can ...

- [ ] explain why a host firewall owns one table and never flushes the whole ruleset, and name who else writes rules
- [ ] say how several base chains on one hook combine, and why an accept in your table cannot override another table's drop
- [ ] use nft's check-only mode and say what it proves and what it cannot know
- [ ] predict what loading a rule file twice does, what a failed load leaves behind and what deleting a missing table reports
- [ ] describe a dead-man switch and name the requirements on the job that undoes the change
- [ ] tell a new SSH connection from a reused one, and say how to force and how to prove the difference
- [ ] choose the timeout of the connection test relative to the delay of the rollback
- [ ] name the three things that have to be right for a rule set to survive a restart: file, service and live ruleset

## Theory

### Who writes rules: tables, hooks and your own table

The kernel's packet filter is shared. Docker, Kubernetes, fail2ban, libvirt and firewalld all
write rules into the same network namespace, and none of them asks. nftables organises rules in
**tables**. A table belongs to an address family (`ip`, `ip6`, `inet` for both, and a few more)
and holds **chains**. A chain that is attached to a point in a packet's path is a **base chain**:
it names a **hook** (`input` for packets addressed to this host, `forward` for packets it routes,
`output` for packets it sends, plus `prerouting` and `postrouting`), a **priority** and a
**policy**, the verdict for packets that no rule decided. Rules inside a chain run in order.

The part that matters for coexistence: **the base chains of different tables on the same hook
all run**. An `accept` ends the evaluation of its own chain only; a `drop` ends it for good. A
packet gets through if no chain drops it, and your table has no say over what another table
drops. The first play shows it with two demo tables on port 65001 of the loopback interface, a
port nothing listens on. It also installs nftables, because the lab images ship without it (and
the Debian ones without a package index, as in L09):

```yaml
- name: Two tables on one hook
  hosts: targets:!suse_family
  become: true
  vars:
    probe: >-
      import socket; s = socket.socket(); s.settimeout(2);
      print('refused' if s.connect_ex(('127.0.0.1', 65001)) == 111 else 'timeout')
  tasks:
    - name: Refresh the apt index (the Debian images ship without one)
      ansible.builtin.apt:
        update_cache: true
      changed_when: false
      check_mode: false
      when: ansible_facts.os_family == 'Debian'
    - name: Install nftables
      ansible.builtin.package:
        name: nftables
        state: present
    - name: Table A accepts port 65001
      ansible.builtin.command:
        cmd: nft -f -
        stdin: |
          table inet lesson13_a {
            chain input {
              type filter hook input priority filter; policy accept;
              tcp dport 65001 accept
            }
          }
      changed_when: false
      check_mode: false
    - name: Connect to port 65001 with table A only
      ansible.builtin.command:
        argv: [python3, -c, "{{ probe }}"]
      register: only_a
      changed_when: false
      check_mode: false
    - name: Table B, someone else's, drops the same port
      ansible.builtin.command:
        cmd: nft -f -
        stdin: |
          table inet lesson13_b {
            chain input {
              type filter hook input priority filter; policy accept;
              tcp dport 65001 drop
            }
          }
      changed_when: false
      check_mode: false
    - name: Connect again with both tables
      ansible.builtin.command:
        argv: [python3, -c, "{{ probe }}"]
      register: both
      changed_when: false
      check_mode: false
    - name: Remove both demo tables
      ansible.builtin.command: "nft delete table inet {{ item }}"
      loop: [lesson13_a, lesson13_b]
      changed_when: false
      check_mode: false
    - name: Flush the whole ruleset, but only in a throw-away network namespace
      ansible.builtin.command:
        argv:
          - unshare
          - --net
          - sh
          - -c
          - nft add table ip lesson13_foreign && nft flush ruleset && nft list tables | wc -l
      register: flushed
      changed_when: false
      check_mode: false
    - name: Compare the results
      ansible.builtin.debug:
        msg:
          - "table A only: {{ only_a.stdout }}, with table B: {{ both.stdout }}"
          - "tables left after the flush in the throw-away namespace: {{ flushed.stdout }}"
```

The output is `table A only: refused, with table B: timeout`. *Refused* means the packet reached
the host, which answered with a reset because nothing listens; *timeout* means it was dropped
silently. Table A accepts the port in both runs, and table B's drop wins. The last task is the
reason for the rule "own your table": it uses the throw-away network namespace of L05, adds a
table that stands for someone else's, flushes the whole ruleset and lists what is left. Nothing
is left, because `flush ruleset` has no notion of ownership. Never run it in a target's own
namespace: the containers keep Docker's DNS rules there (see
[container limits](../CONTAINER_LIMITS.md)), and on the Arch target `nft list tables` shows a
table `ip nat` before you have configured anything.

Three consequences follow. A firewall manages **its own table** and nothing else. A rule in it
that allows SSH is not a guarantee of reachability, because another table can still drop. And a
`drop` policy in your base chain drops what your rules do not accept even if another table would
have let it pass, so the policies of `input`, `forward` and `output` are a design decision, not a
default.

### Loading rules: check, transaction, repetition

Three questions decide how rules reach the kernel: is the file acceptable, what does a failed load
leave behind, and what does loading again do? The next play answers them on a demo table, using
`nft -c`, the check-only mode (nftables 1.0.9 in the session, the lab's targets bring their own
version), and `-f -` to read the rules from standard input. It assumes the previous play has
installed nftables:

```yaml
- name: What nft does with a rule file
  hosts: targets:!suse_family
  become: true
  vars:
    good_table: |
      table inet lesson13_demo {
        chain input {
          type filter hook input priority filter; policy accept;
          tcp dport 65002 counter
        }
      }
  tasks:
    - name: Check a file with a syntax error
      ansible.builtin.command:
        cmd: nft -c -f -
        stdin: "table inet lesson13_demo {\n  chain input { foo }\n}\n"
      register: syntax
      changed_when: false
      failed_when: false
      check_mode: false
    - name: Check a file that names a set which does not exist
      ansible.builtin.command:
        cmd: nft -c -f -
        stdin: |
          table inet lesson13_demo {
            chain input {
              type filter hook input priority filter; policy accept;
              ip saddr @nosuchset accept
            }
          }
      register: reference
      changed_when: false
      failed_when: false
      check_mode: false
    - name: Check a good file
      ansible.builtin.command:
        cmd: nft -c -f -
        stdin: "{{ good_table }}"
      register: good
      changed_when: false
      check_mode: false
    - name: Is the table loaded after the checks?
      ansible.builtin.command: nft list tables
      register: after_check
      changed_when: false
      check_mode: false
    - name: Load a good table and a broken one in one file
      ansible.builtin.command:
        cmd: nft -f -
        stdin: |
          table inet lesson13_good {
            chain input {
              type filter hook input priority filter; policy accept;
            }
          }
          table inet lesson13_bad {
            chain input {
              type filter hook input priority filter; policy accept;
              ip saddr @nosuchset accept
            }
          }
      register: atomic
      changed_when: false
      failed_when: false
      check_mode: false
    - name: Is the good table there?
      ansible.builtin.command: nft list tables
      register: after_atomic
      changed_when: false
      check_mode: false
    - name: Load the same good file twice
      ansible.builtin.command:
        cmd: nft -f -
        stdin: "{{ good_table }}"
      loop: [1, 2]
      changed_when: false
      check_mode: false
    - name: Show the chain
      ansible.builtin.command: nft list chain inet lesson13_demo input
      register: chain
      changed_when: false
      check_mode: false
    - name: Delete a table that is not there
      ansible.builtin.command: nft delete table inet lesson13_missing
      register: missing
      changed_when: false
      failed_when: false
      check_mode: false
    - name: Remove the demo table
      ansible.builtin.command: nft delete table inet lesson13_demo
      changed_when: false
      check_mode: false
    - name: Summary
      ansible.builtin.debug:
        msg:
          - "syntax error: rc {{ syntax.rc }}, {{ syntax.stderr_lines[0] }}"
          - "unknown set: rc {{ reference.rc }}, {{ reference.stderr_lines[0] }}"
          - "good file: rc {{ good.rc }}, table loaded afterwards: {{ 'lesson13_demo' in after_check.stdout }}"
          - "good + broken table: rc {{ atomic.rc }}, good table loaded: {{ 'lesson13_good' in after_atomic.stdout }}"
          - "rules in the chain after two loads: {{ chain.stdout_lines | select('search', 'dport 65002') | list | length }}"
          - "delete of a missing table: rc {{ missing.rc }}, {{ missing.stderr_lines[0] }}"
```

The summary reads (the last line continues on the next one):

```
syntax error: rc 1, /dev/stdin:2:21-21: Error: syntax error, unexpected '}'
unknown set: rc 1, /dev/stdin:4:14-23: Error: No such file or directory
good file: rc 0, table loaded afterwards: False
good + broken table: rc 1, good table loaded: False
rules in the chain after two loads: 2
delete of a missing table: rc 1, Error: Could not process rule: No such file or directory
```

Read it as five facts.

- **The check catches more than syntax.** A reference to a set that does not exist fails too, but
  the text is the same `No such file or directory` that a missing table produces; the position
  range after the file name points at the guilty word. The check changes nothing: the good file
  checked fine and no table exists afterwards.
- **What the check cannot know** is whether the rules let you in. A file that drops everything,
  SSH included, passes. This is the lesson of `validate` in L02, once more: the checker judges the
  file, not the effect.
- **A load is one transaction.** The file with a good and a broken table loaded neither. A half
  applied firewall cannot come from a single `nft -f`.
- **A table declaration with content adds to what exists.** Loading the same file twice left two
  copies of the rule in the chain. A bare declaration, `table inet name` without a body, is
  different: it is not an error whether the table exists or not (tested), and it changes
  nothing.
- **A delete needs something to delete.** Deleting a table that does not exist is an error with
  rc 1.

From these facts you can work out what a rule file must contain, and what a task has to do around
it, to be loaded once or a hundred times with the same result. That is what 4.07 asks for. The
exercise's own rule set is not shown here, and neither is a task ordering that solves it.

### A change you may not survive: the dead-man switch

A firewall change can cut the connection that makes it. If the play fails afterwards, there may
be no connection left to repair anything with. The professional answer is a **dead-man switch**:
arm an undo first, make the change, test the result through a *new* connection, and cancel the
undo only if that test succeeds. If it never does, the undo fires by itself. The idea is simple;
it works only if four pieces behave, and each can be tested separately with something harmless.

**Piece 1: the undo job lives on the target and outlives the task.** The next play starts a job
that needs five seconds and shows that the start task does not wait for it:

```yaml
- name: A job that outlives the task that started it
  hosts: targets:!suse_family
  gather_facts: false
  tasks:
    - name: Remove the marker of an earlier run
      ansible.builtin.command: rm -f /tmp/lesson13-job
      changed_when: false
      check_mode: false
    - name: Clock before the job
      ansible.builtin.command: date +%s
      register: t0
      changed_when: false
      check_mode: false
    - name: Start a job that needs five seconds
      ansible.builtin.shell: "sh -c 'sleep 5; touch /tmp/lesson13-job' >/dev/null 2>&1 & echo started"
      changed_when: false
      check_mode: false
    - name: Clock after the start task
      ansible.builtin.command: date +%s
      register: t1
      changed_when: false
      check_mode: false
    - name: Wait for the marker
      ansible.builtin.wait_for:
        path: /tmp/lesson13-job
        timeout: 20
      check_mode: false
    - name: Clock after the marker appeared
      ansible.builtin.command: date +%s
      register: t2
      changed_when: false
      check_mode: false
    - name: Compare
      ansible.builtin.debug:
        msg: "the start task took {{ t1.stdout | int - t0.stdout | int }} s, the marker appeared after {{ t2.stdout | int - t0.stdout | int }} s"
```

The first number includes two clock reads over SSH and stays below the job's five seconds (two to
three seconds on the lab targets); the marker appears after about eight: the job runs on its own. Whether it also survives the loss of the
connection depends on how it was started. In a test over the `ssh` connection to a local sshd
(ansible-core 2.21.6, one machine), the connection was killed two seconds after the start: jobs
started by `shell` (plain `&` and `nohup`) and by an `async` task with `poll: 0` still finished,
a job started by `raw` did not run to the end (the cause was not investigated). The lesson for a
rollback is to test it, deliberately and on every platform you use, and not to assume it.

**Piece 2: `async` starts a job, but nothing cancels it.** L09 introduced `async` and
`async_status`. `async_status` has two modes, `status` and `cleanup`, and no way to stop a job:
`cleanup` on a running job deleted the job's state file, the job kept running and finished (a
marker file appeared), and a later `status` read `finished: true` with no result. A job that may
have to be cancelled needs an identity the play keeps, such as a process id. How you hold on to
it is part of 4.07.

**Piece 3: a new connection is not the same as a new task.** The lab's `ansible.cfg` sets
`ControlPersist=60s`: the first task opens an SSH connection and later tasks reuse it. That is
efficient, and it is a trap for a lock-out test, because packets of an established connection are
usually exempt from a new rule. The environment variable `SSH_CONNECTION` of the remote session
(client address, client port, server address, server port) tells connections apart:

```yaml
- name: Is it the same connection?
  hosts: targets:!suse_family
  gather_facts: false
  tasks:
    - name: Read the client side of the SSH connection
      ansible.builtin.command: printenv SSH_CONNECTION
      register: first
      changed_when: false
      check_mode: false
    - name: Read it again in the same play
      ansible.builtin.command: printenv SSH_CONNECTION
      register: second
      changed_when: false
      check_mode: false
    - name: Close the connection that Ansible keeps open
      ansible.builtin.meta: reset_connection
    - name: Read it on the new connection
      ansible.builtin.command: printenv SSH_CONNECTION
      register: third
      changed_when: false
      check_mode: false
    - name: Compare the client ports
      ansible.builtin.debug:
        msg: "first {{ first.stdout.split()[1] }}, second {{ second.stdout.split()[1] }}, after the reset {{ third.stdout.split()[1] }}"
```

The first two ports are equal, the third differs: `meta: reset_connection` closed the kept
connection and the next task opened a new one. The play runs without `become` on purpose; with
`become` the variable was `unset` on all eight targets (the privilege escalation does not pass
it on). In a test where the firewall dropped *new* connections to sshd, an ordinary `ping` task
still answered over the old connection. So a task that merely succeeds proves nothing about
whether you could connect anew.

**Piece 4: `wait_for_connection` is the test.** The module keeps trying until a connection works
and a ping through it succeeds. Its defaults in ansible-core 2.21.6: `timeout` 600 seconds,
`connect_timeout` 5, `sleep` 1, `delay` 0. When it gives up, the task fails with
`timed out waiting for ping module test` followed by the connection error. It opens a connection
of its own for every attempt: in the same lock-out test it failed both with and without a
`meta: reset_connection` before it. The explicit reset is therefore for what comes *after* the
test, for tasks that should not silently keep using the old connection. The test also has a
timeout, and the timeout has a rule: it must be shorter than the delay of the rollback. If the
rollback fires first, it repairs the host while the test is still waiting, and the test reports
success on a host that has just been rolled back. With the default of 600 seconds that is the
normal case, not a corner case. Check the live state after the test, too.

What the test cannot prove: it shows that the control node can open a new connection from its
own address. It says nothing about other administrators, monitoring or backup hosts, and it
cannot show a lock-out unless the rule under test really blocks the control node. How these four
pieces fit together around a rule set is exercise 4.07.

### What survives a restart: file, service and live ruleset

Rules loaded with `nft` live in kernel memory. A reboot, or the restart of a container, empties
them. Persistence means a service that loads a file at boot, so three things have to be right,
and each can be wrong alone:

- the **file** is the recipe; an unchanged file says nothing about the kernel;
- the **service** is what runs the recipe, at boot, and possibly at stop and reload;
- the **live ruleset** is the truth; `nft list table ...` shows it.

An unchanged file with an empty kernel is the usual surprise after a restart, which is why a
task that decides "does this need loading?" should look at the live state and not only at the
file. On systemd hosts the unit tells you what the service does; on OpenRC the init script does.
Read them, do not guess:

```
systemctl cat nftables.service        # systemd: ExecStart, ExecReload, ExecStop, Type
systemctl show -p ExecStop nftables   # the stop command, if there is one
rc-service -l | grep nftables         # OpenRC: is there a service at all?
cat /etc/init.d/nftables              # OpenRC: what start, stop and save do
```

On the Arch target the unit was found to be `Type=oneshot` and disabled by default. A
`oneshot` unit runs a command and is finished; whether systemd keeps showing it as active
afterwards depends on `RemainAfterExit`, and either way the ruleset is kernel state that the
unit's status does not describe. The `Exec` lines name the file the service loads and say what
happens at stop and reload. Anything a stop command does to the ruleset, it does to **all**
tables, not only yours; before restarting a firewall service on a host with other writers, read
what it does on the way down. The Ansible side of the same distinction: `enabled: true` of the
`service` module changes what happens at boot, `state: started` acts now, and `state: restarted`
always stops first and then starts.

## CIS background

Section 4 of the benchmarks (id `4` in [the control catalogue](../../cis/controls.yml)) asks for
one working host firewall with a default-deny stance towards inbound traffic and explicit
allowances for what the host really offers. It protects against the services that every package
manager install and every developer tool quietly opens: a database bound to all interfaces, a
debug port, a management daemon. A firewall does not make these safe; it makes them unreachable
from where nobody should reach them, and it buys time when one of them has a vulnerability.

"One" is the key word. The benchmarks accept nftables, firewalld, iptables or ufw, but not two
at the same time: two writers with different ideas about the default policy produce rules that
nobody designed. That is also why firewalld, the default frontend on full installations of the
RedHat and Suse families (distribution documentation, not verified in the lab), is an either-or
with a hand-written nftables rule set. The usual baseline accepts traffic on the loopback
interface, replies to connections the host started, and the management ports from a known range,
and drops the rest. Filtering outbound traffic is a design decision that needs knowledge of what
the server talks to; many baselines leave it open and the exercise offers it as a bonus. The
exact recommendation numbers differ per benchmark and version; look them up in the PDF of your
distribution.

## Platform differences

| os_family | nftables in the lab image | Other frontends in the image | Init | Notes |
|---|---|---|---|---|
| Debian | not installed | none | systemd | Package index missing in the image: refresh it before installing |
| RedHat | not installed | none | systemd | firewalld is the usual frontend on a full install |
| Suse | not installed | none | systemd | firewalld is the usual frontend; 4.07 excludes this family |
| Alpine | not installed | none | OpenRC | needs Python from 0.02 for the Ansible modules |
| Archlinux | installed (v1.1.7) | `iptables` with the nf_tables backend | systemd | `nftables.service` exists and is disabled; `nft list tables` shows `ip nat` |

The package is called `nftables` in all families. The version differs between the images (1.1.3 on Debian to 1.1.7 on Arch); the error texts of the
load example were identical on all seven targets (the session test used 1.0.9).

### In the lab containers

Each target has its own network namespace, so the firewall of one container does not touch
another one or the host. Docker keeps its DNS rules in that namespace, which is the reason for
the rule "own table, never flush" in [container limits](../CONTAINER_LIMITS.md). The seven
targets of 4.07 are on one subnet (`172.31.250.0/24` on this installation). The address and
prefix come from the fact `default_ipv4`, which exists only when the network facts were
gathered: with `gather_subset: min` the fact is missing and a template that uses it fails with
`object of type 'dict' has no attribute 'default_ipv4'`, with `min,network` the fact is there (the
prefix is a string, `'24'`). Broken a host? `./lab.sh reset <host>` restores it.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The check passes and SSH is gone | the check judges syntax and references, not what the rules do | roll out with a way back and test through a new connection |
| `Error: No such file or directory` for a rule that names a set | a missing set and a missing table give the same text | read the position range after the file name; list what exists with `nft list tables` |
| The same rule appears twice after a second run | a table declaration with content adds to an existing table | make the load start from a defined state (the facts of the loading section) |
| `delete table` fails on a fresh host | there is no table yet (rc 1) | the delete has to be safe when nothing exists |
| Docker's or fail2ban's rules vanish | `flush ruleset` removes every table in the namespace | manage one table and nothing else |
| `'dict object' has no attribute 'default_ipv4'` | `gather_subset: min` leaves the network facts out | gather the network subset |
| A test task succeeds after the lock-out | ordinary tasks reuse the open connection | test with a task that opens a new connection, such as `wait_for_connection` |
| The test passes on a host that has just been rolled back | the rollback fired while the test was still waiting | a test timeout shorter than the rollback delay; check the live state afterwards |
| The rollback never fires | the job died with its session (a `raw` job did in a test) | start the job so that it survives, and test that on each platform |
| The table is gone after a restart, the file is unchanged | the file is a recipe, the kernel holds the state | check the live state, and persist through the service |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [4.07](../../exercises/stage4-advanced/4.07-nftables-safe-rollout/README.md) | owning a table, checking and repeating a load, the dead-man switch with a new connection as the test, what a restart keeps |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. Why does a firewall for a shared host manage one table instead of loading a complete ruleset
   that starts with a flush?

   <details><summary>Answer</summary>

   A flush removes every table in the namespace, including the rules of Docker, fail2ban or
   Kubernetes, and nothing puts them back. A table of your own can be replaced as a unit without
   touching the others.

   </details>

2. Your table accepts TCP port 8080 and another table on the same hook drops it. What happens to
   a connection to that port, and what if the other table only accepts it?

   <details><summary>Answer</summary>

   The packet is dropped: all base chains on the hook run, and a drop is final. If the other
   table only accepts, it is still your chain's policy and rules that decide whether the packet
   passes. An accept ends the evaluation of one chain, not of the hook.

   </details>

3. `nft -c` returns 0 for your rule file. Name two things it does not tell you.

   <details><summary>Answer</summary>

   Whether the rules let your SSH connection in (it checks the file, not the effect), and whether
   the state of the kernel is what you expect after the load, such as an earlier table that is
   still there. It also does not tell you whether the rules fit your network.

   </details>

4. A file declares one table with one rule. After two loads the chain holds the rule twice, and
   a `delete table` on a fresh host fails. What do these two facts tell you about a rule file
   that has to be loaded again and again?

   <details><summary>Answer</summary>

   Declaring an existing table with content adds to it, so the load has to start from a defined
   state. A plain delete needs the table to exist. Together they say that the file has to
   prepare the ground for itself in a way that works whether the table exists or not.

   </details>

5. The rollback fires after 60 seconds. Why is `timeout: 600` for the connection test a bad
   choice?

   <details><summary>Answer</summary>

   If the new rules block the control node, the rollback repairs the host at second 60 while the
   test is still waiting. The next attempt succeeds, and the play reports a healthy firewall on a
   host that has been rolled back. The test has to give up before the rollback can fire.

   </details>

6. A task after the change succeeds. Why is that no proof that you can still connect, and how do
   you prove that a new connection works?

   <details><summary>Answer</summary>

   With `ControlPersist` later tasks reuse the open connection, whose packets are usually allowed
   as established traffic. A test must open a new connection: `wait_for_connection` does, and
   `meta: reset_connection` forces it for whatever follows. The client port of `SSH_CONNECTION`
   shows which connection a task runs on.

   </details>

7. `systemctl status nftables` says the unit ran successfully. What does that tell you about
   the live ruleset, and how do you find out what a restart of the service does to it?

   <details><summary>Answer</summary>

   Nothing about the live ruleset: the unit's state is not the kernel's state, so look at `nft
   list table ...`. To know what a restart does, read the unit (`systemctl cat`) or the init
   script and look at what its stop, start and reload commands do to the ruleset.

   </details>

## Further reading

- [`ansible.builtin.meta`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/meta_module.html) - `reset_connection`
- [`ansible.builtin.wait_for_connection`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/wait_for_connection_module.html) - `timeout`, `connect_timeout`, `sleep`, `delay`
- [`ansible.builtin.async_status`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/async_status_module.html) - the modes `status` and `cleanup`
- [nft(8)](https://manpages.debian.org/unstable/nftables/nft.8.en.html) - the command line, `-c`, `-f`, and the verbs for tables and chains
- [Netfilter hooks](https://wiki.nftables.org/wiki-nftables/index.php/Netfilter_hooks) - hooks, priorities and how base chains combine
- [Atomic rule replacement](https://wiki.nftables.org/wiki-nftables/index.php/Atomic_rule_replacement) - why one file is one transaction
- [systemd.service(5)](https://manpages.debian.org/unstable/systemd/systemd.service.5.en.html) - `Type=oneshot`, `RemainAfterExit`, `ExecStop`
