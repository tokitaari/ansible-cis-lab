# 6.01 - Testing a role: Molecule scenario with testinfra: Explanation

### What the check verifies
`lab check 6.01` runs `check.sh` in four steps. `meta.yml` says `idempotency: false`: the second
run is the `idempotence` step of your own sequence.

1. **The scenario:** `molecule.yml` names `testinfra` as verifier, `tests/` holds at least one
   `test_*.py`, and a `test_sequence`, if you set one, has `converge`, `idempotence` and `verify`
   in this order.
2. **`molecule test`** in `/lab/work/6.01` exits 0, and its junit report (the check sets
   `PYTEST_ADDOPTS=--junitxml=...`) has passed tests for each of the eight targets.
3. **The requirements**, checked by a playbook of the check itself: `stat` and `slurp` of the six
   files on every target, compared with R1-R3 - exact owner, group and mode, the banner text byte
   for byte.
4. **Your tests on broken targets:** one requirement is broken on each of six targets, then
   `molecule verify` must report a failed test on each of them and none on ubuntu and alma.
   `molecule converge` restores them afterwards.

| Target | What the check breaks |
|---|---|
| debian | `/etc/passwd` mode 0664 |
| arch | `/etc/group` owned by `ansible` |
| rocky | `/etc/shadow` mode 0640 (RedHat requires 0000) |
| opensuse | `/etc/shadow` group root (Suse requires shadow) |
| fedora | `/etc/issue` mode 0666 |
| alpine | `/etc/issue.net` says "Welcome to Alpine Linux" |

It does not test where your expected values come from (only their effect), nor the parts of the
requirements that no mutant breaks: `/etc/gshadow`, the shadow values of Debian, Alpine and
Archlinux, the group of R1 and R3, the content of `/etc/issue`. Step 3 still checks the role's
result for all of them. Measured with the reference on all eight targets: `molecule test` 65-69 s
(syntax 8 s, converge 28, idempotence 30, verify 15), the whole check 143 s.

### How it works

#### Molecule runs Ansible with a configuration of its own
Molecule writes an `ansible.cfg` into its ephemeral directory
(`~/.ansible/tmp/molecule.<x>.<scenario>/`) and points `ANSIBLE_CONFIG` at it. Everything that
`/lab/ansible/ansible.cfg` sets is gone: the inventory, `roles_path`, the SSH options, pipelining.
The connection variables survive, because `ansible_user` and the key live in the inventory's
`group_vars/targets.yml`. `molecule.yml` brings the rest back:

- `ansible.executor.args.ansible_playbook: [--inventory=...]` - added to every
  `ansible-playbook` call, next to Molecule's own (nearly empty) inventory;
- `ansible.cfg.ssh_connection` - merged into the generated `ansible.cfg`;
- `ansible.env` - environment variables for every run; `${MOLECULE_PROJECT_DIRECTORY}` is
  replaced, which makes the role path independent of where the work directory is (the CI runner
  uses `/tmp/lab-run-work`). The reference adds `${MOLECULE_PROJECT_DIRECTORY}/roles` as a second
  entry for `lab solve 6.01`, which runs in `solution/`, where `roles/` lies inside the project.

#### The default driver and hosts that already exist
Molecule 26 ships one driver, `default`. With `managed: false` it creates and destroys nothing;
without `platforms` the scenario is "ansible-native": the hosts are those of the inventory
(`molecule list` shows the eight). The price is state: `molecule test` changes the real targets,
and a target that an earlier exercise left in another state gives another first converge.
`./lab.sh reset all` brings the fresh state back.

#### testinfra: one test function, many hosts
Molecule calls `pytest` with `--connection=ansible` and `--ansible-inventory=<its own
inventory>`. That inventory has no hosts, hence `verifier.options.ansible-inventory`; `hosts:
targets` becomes `--hosts=targets`. pytest then runs every test function once per host (ids such
as `test_account_file[ansible://debian-/etc/passwd]`), and `parametrize` multiplies that by the
files. testinfra runs its own `ssh` per command (`stat`, `cat`) with the user, key and
`ssh_args` it finds in the inventory and in `ANSIBLE_CONFIG` - so the SSH options in
`molecule.yml` serve the tests as well.

#### Expected values that can disagree with the role
The role came with two faults. A `command: chmod` task reports `changed` on every run: only the
idempotence step sees it (its `CRITICAL` message lists `* => cis_mini : Make sure the banners are
world-readable`), because the state the task leaves is right. And the role's own table gives the
RedHat family mode 0640: only a test with its *own* expected values sees that - measured, six
failures, `/etc/shadow` and `/etc/gshadow` on rocky, alma and fedora, each `assert ('root',
'root', 416) == ('root', 'root', 0)`. A test that reads `vars/main.yml` of the role passed on all
eight hosts with the fault in place; the check stopped it in step 3. A test is worth only as much
as the chance that it fails: the mutants of step 4 make that chance visible.

### Per-family notes

| os_family | Hosts | What the tests meet |
|---|---|---|
| Debian | debian, ubuntu | group `shadow` exists; ubuntu's `stat` is uutils coreutils 0.10.0 - testinfra's file module works with it |
| RedHat | rocky, alma, fedora | no group `shadow`; fedora's `/etc/issue` and `/etc/issue.net` are symbolic links before the first run (`stat` shows 0777, see 2.06); `copy` replaces them |
| Suse | opensuse | no `/etc/gshadow` - the gshadow test skips |
| Alpine | alpine | no `/etc/gshadow`; BusyBox `stat` - the file module works; services are OpenRC |
| Archlinux | arch | no group `shadow`, hence root and 0600 |

On a fresh lab (after 0.02) the starter role's first converge changed 4 tasks on every host.

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `The role 'cis_mini' was not found in: .../molecule/default/roles:~/.ansible/roles:...` | Molecule's `ansible.cfg` has no `roles_path` | `ANSIBLE_ROLES_PATH` in `ansible.env` |
| `RuntimeError: No inventory was parsed (missing file ?), only implicit localhost is available` | testinfra gets Molecule's own inventory, which has no hosts | `ansible-inventory` in `verifier.options` |
| `molecule verify` alone: `Host key verification failed` on every test; after a `molecule converge` the same tests pass | without the lab's `ssh_args` testinfra checks host keys; Ansible (`host_key_checking = False`) wrote them to `~/.ssh/known_hosts` | `ssh_args` in `ansible.cfg.ssh_connection` |
| `molecule test` exits 1 with `CRITICAL Idempotence test failed`, but the summary says `idempotence: Executed: Successful` and `failed=0` | the summary does not record that failure (measured with Molecule 26.11.1; `successful=` never counts the idempotence step) | trust the exit code and the `CRITICAL` line |
| `assert 416 == 0` | pytest prints modes in decimal | compare `oct(f.mode)` |
| A test passes with the wrong mode in the role | its expected value comes from the role | expected values from the requirements |
| `molecule idempotence` says `Instances not converged` | a failed `molecule test` ran cleanup and destroy, which reset Molecule's state | `molecule converge` first |

### Real-world notes
- Most Molecule setups create fresh instances per run (containers or VMs, driver plugins or
  `create.yml`), so the first converge always meets the same state. Against long-lived hosts, as
  here, the tests run on whatever the hosts hold - reset them before a run that must prove the
  first converge.
- In a role repository the scenario lives in the role (`roles/<name>/molecule/default/`) and CI
  runs `molecule test` on every change; the project layout here only fits `lab start`.
- One scenario per profile or level keeps the expectations apart (an L2 scenario expects more).
- Testinfra checks the state; it does not replace an audit tool. OpenSCAP or CIS-CAT judge a host
  against the benchmark, the tests judge the role against its own requirements.

### Further reading
- Lesson [L18 - Testing roles](../../../docs/lessons/L18-testing-roles.md): the test ladder, Molecule's configuration, testinfra, expected values - the concepts before this exercise.
- Exercise [2.01 - /etc/shadow: correct permissions per OS family](../../stage2-building-blocks/2.01-shadow-permissions-per-family/README.md): where the values of R2 come from.
- Exercise [2.06 - All login banners from one template](../../stage2-building-blocks/2.06-banners-template-loop/README.md): the symbolic links on fedora.
- [Molecule: ansible-native configuration](https://docs.ansible.com/projects/molecule/ansible-native/) - `ansible.executor`, `ansible.cfg`, `ansible.env`.

## Reference solution

Show it with `lab solution 6.01`, apply it with `lab solve 6.01` (it runs `molecule test` in the
solution directory and leaves the targets converged).
