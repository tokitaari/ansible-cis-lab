# L18 - Testing roles: Molecule, testinfra and tests that can fail

*[Deutsch](L18-testing-roles.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 6.01 | - | ~20 min | L02, L07 |

A hardening role touches every platform in a different way, and a change that is right on one
family can be wrong on another. `lab check` has told you so far whether your work is right; in a
real team nobody writes that check for you. This lesson shows how a role tests itself: Molecule
runs it, runs it again and hands the hosts to testinfra, whose tests in Python read the state and
compare it with the requirements. It also explains why a test is only worth something if it can
fail.

## Learning goals

After this lesson you can ...

- [ ] say what lint, syntax check, converge, the idempotence step and the verifier each find - and what each misses
- [ ] set up a Molecule scenario that runs against hosts that already exist
- [ ] name what Molecule's own `ansible.cfg` takes away, and bring it back in `molecule.yml`
- [ ] write testinfra tests with the `host` fixture, `parametrize` and per-family expectations
- [ ] take expected values from the requirements, not from the code under test, and show that a test can fail
- [ ] read Molecule's result from its exit code and `CRITICAL` line, not from its summary

## Theory

### A ladder of tests

Each kind of test answers one question, and each misses what the next one finds:

| Step | Command | Finds | Misses |
|---|---|---|---|
| lint | `ansible-lint` | risky patterns: `command` without `changed_when`, unquoted modes, missing FQCN (L07) | a wrong value in valid code |
| syntax | `ansible-playbook --syntax-check` | YAML and keyword errors, a role that is not found | everything that happens on a host |
| converge | run the role | module errors on real hosts, per platform | a wrong state that the modules accept |
| idempotence | run it again, expect `changed=0` | tasks that change on every run | a wrong state that stays the same |
| verify | read the state, compare | wrong values, a platform the role forgot | only what no test asks |

Check mode (L02) belongs to none of these steps: it predicts what a run would change, it does not
look at the result. A role can pass check mode, converge without error and be idempotent - and
still set the wrong mode on one family. Only the last step looks at the result, so most of this
lesson is about it.

### Molecule: scenarios and sequences

Molecule organises the steps. A *scenario* is a directory with a `molecule.yml`, a playbook
`converge.yml` that applies what you test, and - for testinfra - a `tests/` directory. The
scenario `default` lives in `molecule/default/` below the directory you run Molecule in (the
*project*). `molecule test` runs the scenario's *test sequence*; every step also runs on its own:

```bash
molecule --version
```

The lab's control node has Molecule 26.11.1 with one driver, `default`. A *driver* creates and
destroys test instances - containers or virtual machines in most setups. The control node has no
container runtime, and the lab has eight hosts already, so the scenario uses the default driver
with `managed: false` (Molecule creates and destroys nothing) and names no `platforms`: the hosts
are those of an inventory you pass. Molecule calls this an "ansible-native" scenario.

`molecule converge` applies the playbook; `molecule idempotence` runs it once more and fails if a
task reports a change; `molecule verify` runs the tests against the state the hosts have now;
`molecule test` runs the whole sequence; `molecule list` shows the hosts. An explicit
`test_sequence` keeps it short - the default sequence also runs dependency, create, prepare,
side_effect, cleanup and destroy, which here only print "Missing ..." warnings.

### Molecule writes its own `ansible.cfg`

Molecule does not run Ansible with your configuration. It writes an `ansible.cfg` into an
ephemeral directory below `~/.ansible/tmp/` and sets `ANSIBLE_CONFIG` to it. Everything that
`/lab/ansible/ansible.cfg` sets is gone for that run: the inventory, `roles_path`, the SSH options
and pipelining. What lives in the inventory itself survives - the lab's `ansible_user` and key are
in `group_vars/targets.yml`. Three keys of `molecule.yml` bring the rest back:

- `ansible.executor.args.ansible_playbook` - extra arguments for every `ansible-playbook` call,
  for example `--inventory=/lab/ansible/inventory/hosts.yml`;
- `ansible.cfg` - sections merged into the generated file, for example `ssh_connection`;
- `ansible.env` - environment variables for every run. Molecule replaces `${VAR}` in
  `molecule.yml` with the environment, including its own `MOLECULE_PROJECT_DIRECTORY`, so a path
  like `${MOLECULE_PROJECT_DIRECTORY}/../roles` does not depend on where the project lives.

A small scenario against all eight targets - not a role, one task and two tests:

```bash
mkdir -p /tmp/l18/molecule/default/tests && cd /tmp/l18
cat > molecule/default/molecule.yml <<'EOF'
---
driver:
  name: default
  options:
    managed: false
ansible:
  cfg:
    ssh_connection:
      pipelining: true
      ssh_args: -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR
  executor:
    args:
      ansible_playbook:
        - --inventory=/lab/ansible/inventory/hosts.yml
verifier:
  name: testinfra
  options:
    ansible-inventory: /lab/ansible/inventory/hosts.yml
scenario:
  test_sequence: [syntax, converge, idempotence, verify]
EOF
cat > molecule/default/converge.yml <<'EOF'
---
- name: Converge
  hosts: targets
  tasks:
    - name: A file that names the host that wrote it
      ansible.builtin.copy:
        content: "written by {{ inventory_hostname }}\n"
        dest: /var/tmp/l18-demo
        mode: "0640"
    - name: Which ansible.cfg this run uses
      ansible.builtin.debug:
        msg: "{{ lookup('ansible.builtin.env', 'ANSIBLE_CONFIG') }}"
      run_once: true
EOF
```

The debug task prints a path below `~/.ansible/tmp/`, not `/lab/ansible/ansible.cfg`. The tests
follow in the next section; then `molecule test` runs it all.

### testinfra: tests in Python against real hosts

testinfra is a plugin for pytest. pytest collects the functions named `test_*` in files named
`test_*.py`, runs each one and reports every failed `assert` with the values on both sides. The
plugin adds the *fixture* `host`: a test function that takes an argument `host` is run once per
host, and `host` gives access to testinfra's modules - `host.file()`, `host.service()`,
`host.package()`, `host.user()`, `host.run()`, `host.check_output()`, `host.sudo()` and more.
`pytest.mark.parametrize` runs a function once per value as well, so one function covers a list of
files on every host.

```bash
cat > /tmp/l18/molecule/default/tests/test_demo.py <<'EOF'
import pytest

# name of the SSH service per inventory group; all others: sshd
SSH_SERVICE = {"debian_family": "ssh"}


@pytest.mark.parametrize("path", ["/var/tmp/l18-demo"])
def test_demo_file(host, path):
    f = host.file(path)
    assert f.is_file
    assert oct(f.mode) == "0o640"
    assert f.content_string == f"written by {host.backend.get_hostname()}\n"


def test_ssh_service(host):
    groups = host.ansible.get_variables()["group_names"]
    name = next((SSH_SERVICE[g] for g in groups if g in SSH_SERVICE), "sshd")
    svc = host.service(name)
    assert svc.is_running
    assert svc.is_enabled
EOF
cd /tmp/l18 && molecule test
```

The verify step reports 16 passed tests: two per host, with ids such as
`test_demo_file[ansible://debian-/var/tmp/l18-demo]`. Two details make the run work. Molecule
calls pytest with `--connection=ansible` and its *own* inventory, which has no hosts - without
`ansible-inventory` in `verifier.options` testinfra stops with "No inventory was parsed".
(`hosts:` next to it would choose a group; the default is all hosts of the inventory.) And
testinfra does not use Ansible to reach the hosts: it reads user, key and `ssh_args` from the
inventory and from `ANSIBLE_CONFIG` and runs its own `ssh` for every command. The SSH options in
`molecule.yml` therefore serve the tests too, and so does the `control_path` that Molecule's
`ansible.cfg` sets: testinfra reuses one connection per host only when the configuration names a
control path.

The same test file runs without Molecule, with the lab's configuration:

```bash
cd /tmp/l18 && pytest -p no:cacheprovider -q --hosts=ansible://alpine --ansible-inventory=/lab/ansible/inventory/hosts.yml molecule/default/tests/test_demo.py
```

On alpine that takes a few seconds. `/lab/ansible/ansible.cfg` names no `control_path`, so
testinfra opens a new SSH connection for every command: a probe of about a dozen checks per host
took 38-48 s on each systemd target and 3 s on alpine. For many tests, `molecule verify` is the faster way.

### Expected values, and tests that can fail

A test compares the state with an expected value, and the expected value must come from somewhere
else than the code under test: from the requirements, the benchmark, a table someone wrote for
that purpose. A test that imports the role's own variables, or copies them, checks that the role
does what the role says - it passes on every wrong value in those variables. That is the most
common way for a test suite to be green and useless.

The second question is whether a test can fail at all. Break the state by hand and run the tests
again:

```bash
ansible debian -m ansible.builtin.file -a "path=/var/tmp/l18-demo mode=0644"
cd /tmp/l18 && molecule verify
```

Now `test_demo_file[ansible://debian-...]` fails with `AssertionError: assert '0o644' ==
'0o640'`, and the other fifteen pass. A test that stays green when you break what it claims to
check tests nothing. Breaking the state on purpose is *mutation testing* done by hand; Molecule's
sequence has a `side_effect` step for a playbook that does it in a scenario. `molecule converge`
puts the file back; `ansible targets -m ansible.builtin.file -a "path=/var/tmp/l18-demo
state=absent"` removes it when you are done.

Read the result of a run by its exit code and its `CRITICAL` line. A `molecule test` whose
idempotence step fails ends with exit code 1 and `CRITICAL Idempotence test failed`, followed by
the tasks that changed - and Molecule 26.11.1 then prints a summary that says `idempotence:
Executed: Successful` and `failed=0`.

## CIS background

The benchmarks describe the state of a host, not how to reach it, and they say nothing about
testing. For a role that implements them, tests answer three questions an audit cannot: does
the role reach the state on *every* platform it supports, does it stay quiet when nothing is
wrong, and does a change keep both true? The second matters more than it seems. The audit mode of
L10 reads a `changed` result as a deviation; a task that changes on every run puts a false
finding into every report and hides the real ones. When a new benchmark version changes a value,
a role with tests shows on which families the change landed, before the hosts do.

A scenario per profile keeps Level 1 and Level 2 apart - an L2 scenario expects more. And tests are
not an audit tool: OpenSCAP or CIS-CAT judge a host against the benchmark, the tests judge the
role against its own requirements.

## Platform differences

Measured with testinfra 10.2.2 on the eight targets (after 0.02):

| os_family | `host.system_info.distribution` | `host.service` | `host.package` | `stat` |
|---|---|---|---|---|
| Debian | debian, ubuntu | systemd (`ssh`) | dpkg | GNU coreutils (debian), uutils coreutils 0.10.0 (ubuntu) |
| RedHat | rocky, almalinux, fedora | systemd (`sshd`) | rpm | GNU coreutils |
| Suse | opensuse-leap | systemd (`sshd`) | rpm | GNU coreutils |
| Alpine | alpine | OpenRC (`sshd`) | apk | BusyBox |
| Archlinux | arch | systemd (`sshd`) | pacman (`openssh`) | GNU coreutils |

testinfra chooses the backend of a module from the host, and its file module worked with all
three `stat` implementations. Names still differ: the SSH service is `ssh` on the Debian family,
the package `openssh` on arch - a test needs per-family expectations exactly where the role needs
per-family data.

### In the lab containers

The targets are long-lived containers, not instances that Molecule creates for each run: a
scenario runs on whatever an earlier exercise left, and `molecule test` changes the real targets.
`./lab.sh reset all` gives every scenario the fresh state of the images. Molecule's usual drivers
would need a container runtime in the control node, which the lab does not have.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `The role '<name>' was not found in: .../molecule/default/roles:~/.ansible/roles:...` | Molecule's `ansible.cfg` has no `roles_path` | `ANSIBLE_ROLES_PATH` in `ansible.env` |
| `RuntimeError: No inventory was parsed (missing file ?), only implicit localhost is available` | testinfra gets Molecule's inventory, which has no hosts | `ansible-inventory` in `verifier.options` |
| `molecule verify` alone fails with `Host key verification failed`; after `molecule converge` it passes | without `ssh_args` testinfra checks host keys, and only Ansible's run wrote them to `~/.ssh/known_hosts` | the lab's `ssh_args` in `ansible.cfg.ssh_connection` |
| The summary says `idempotence: Executed: Successful` after `CRITICAL Idempotence test failed` | Molecule's summary does not record that failure | the exit code and the `CRITICAL` line decide |
| `assert 416 == 420` | pytest prints modes in decimal | compare `oct(f.mode)` with `"0o644"` |
| `WARNING ... The scenario config file (...) has been modified since the scenario was created` | you edited `molecule.yml` after a run | harmless; `molecule reset` clears the stored state |
| Standalone `pytest --hosts=ansible://...` takes seconds per test | no `control_path` in the lab's `ansible.cfg`: one SSH connection per command | `molecule verify`, or test one host |
| Every test passes, and the role is wrong | the expected values come from the role | write them from the requirements; break the state once and watch the test fail |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [6.01](../../exercises/stage6-beyond-the-benchmark/6.01-testing-the-role/README.md) | a scenario with the default driver against the lab inventory, what Molecule's configuration takes away, testinfra with `host` and `parametrize`, expected values from the requirements, a test that can fail |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A role sets every file right on all eight hosts and passes `molecule verify`, but `molecule
   test` fails. What kind of fault is left, and which step found it?

   <details><summary>Answer</summary>

   A task that reports a change on every run - for example `command` without `changed_when`, or a
   template with a time stamp. The state it leaves is right, so the verifier cannot see it; the
   idempotence step runs the role a second time and fails because `changed` is not 0. It matters
   in practice: in audit mode such a task reports a deviation on every host and every run.

   </details>

2. You run `molecule converge` and it says `The role 'cis' was not found`, although
   `ansible-playbook` finds the same role from the same directory. Why?

   <details><summary>Answer</summary>

   Molecule runs Ansible with its own `ansible.cfg` (`ANSIBLE_CONFIG` points into its ephemeral
   directory), so the `roles_path` of `/lab/ansible/ansible.cfg` does not apply. Set
   `ANSIBLE_ROLES_PATH` in `ansible.env` of `molecule.yml`, with `${MOLECULE_PROJECT_DIRECTORY}`
   if the path is relative to the project.

   </details>

3. A colleague's test reads the expected mode of `/etc/shadow` from the role's `vars/main.yml`.
   What does that test prove, and what does it not?

   <details><summary>Answer</summary>

   It proves that the role applied the value it holds, on every host - so a module error or a
   forgotten family would still show. It does not prove that the value is right: a wrong entry in
   `vars/main.yml` is the expected value and the actual value at the same time, and the test
   passes. Expected values must come from an independent source, such as the requirements or the
   benchmark.

   </details>

4. How do you find out whether a test can fail, and why is "all tests green" not enough?

   <details><summary>Answer</summary>

   Break the state it checks on one host - by hand, or in a `side_effect` playbook - and run
   `molecule verify`: the test must fail on that host and only there. A test that stays green
   tests nothing, and "all green" only says that no test failed, not that any test looked at the
   right thing.

   </details>

5. `pytest --hosts=ansible://targets` with the lab's configuration needs minutes, `molecule verify`
   with the same tests seconds. What is the difference?

   <details><summary>Answer</summary>

   testinfra opens its own SSH connection per command and reuses one only when the Ansible
   configuration it reads names a `control_path`. Molecule's generated `ansible.cfg` sets one, the
   lab's does not, and a new connection to a systemd target takes a few seconds.

   </details>

## Further reading

- [Molecule documentation](https://docs.ansible.com/projects/molecule/) - scenarios, commands, the test sequence
- [Molecule: ansible-native configuration](https://docs.ansible.com/projects/molecule/ansible-native/) - `ansible.executor`, `ansible.cfg`, `ansible.env`, scenarios without `platforms`
- [testinfra: modules](https://testinfra.readthedocs.io/en/latest/modules.html) - `file`, `service`, `package`, `user`, `ansible`
- [testinfra: connection backends](https://testinfra.readthedocs.io/en/latest/backends.html) - `ansible://`, `--ansible-inventory`, how SSH settings are read
- [pytest: parametrizing tests](https://docs.pytest.org/en/stable/how-to/parametrize.html) - `@pytest.mark.parametrize`
- [Glossary](../GLOSSARY.md) - terms of this lesson: default driver (Molecule), fixture (pytest), idempotence step
  (Molecule), Molecule, mutation testing, scenario (Molecule), test oracle, test sequence (Molecule),
  testinfra, verifier (Molecule)
