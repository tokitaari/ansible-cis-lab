# L14 - Production rollout: failure handling, preflight, batches and community roles

*[Deutsch](L14-production-rollout.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 5.02, 5.03 | - | ~35 min | L02, L07, L10, L13 |

A correct role can still cause an outage when it reaches every host at once, and a hardening role
reaches authentication, networking and services. Rolling it out is therefore its own piece of
engineering: decide in advance how far one failure may spread, check the hosts before anything
changes, widen the circle in steps and look at the result after each step. The second half of the
lesson is about the code you did not write. Community CIS roles exist and cover far more than a
team writes alone, but they run as root on every server, so you pin them, read them and test them
like your own.

## Learning goals

After this lesson you can ...

- [ ] predict what a failure on one host does to the other hosts, the later batches and the later plays, with and without `serial`, `max_fail_percentage` and `any_errors_fatal`
- [ ] work out the batch sizes of a `serial` list, percentages included, and read the recap of an aborted run correctly
- [ ] name what limits parallelism (`forks`, `serial`, `throttle`) and say which limit wins
- [ ] write a preflight whose read-only checks also run under `--check`, behind a gate that refuses without an explicit confirmation
- [ ] say why facts are not always the right source for what a host knows about itself, and why free space inside a host can mislead on thin-provisioned storage
- [ ] tell the host list of a play from the host list of a batch, and say what `run_once` and `post_tasks` do under `serial`
- [ ] pin a role or a collection from Galaxy or Git in `requirements.yml` and say what a second install run does and does not change
- [ ] read a third-party role without running it, and name the criteria for adopting, forking or building

## Theory

All demos run in one directory on the control node and change nothing on the targets except one
small file in `/tmp`. Alpine needs the Python of exercise 0.02 for the modules that run on the
host (`lab solve 0.02`).

```bash
mkdir -p /tmp/lesson14 && cd /tmp/lesson14
```

### Failure semantics: who stops when something fails

The same role that works on seven hosts can fail on the eighth, an OS version nobody tested. How
far the damage goes is decided by three keywords, and the default is not what most people expect.
Save the play below as `fleet.yml`. It breaks on purpose on the hosts named in a variable and
changes nothing else:

```yaml
- name: A change that breaks on chosen hosts
  hosts: targets
  gather_facts: false
  serial: "{{ lesson14_serial | default(0) }}"
  max_fail_percentage: "{{ lesson14_maxfail | default(100) }}"
  tasks:
    - name: Pretend to change the host
      ansible.builtin.fail:
        msg: "broken on purpose"
      when: inventory_hostname in lesson14_broken | default([])

    - name: Carry on with the next task
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} got through"

- name: A later play, for example the report
  hosts: targets
  gather_facts: false
  tasks:
    - name: Say who gets here
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} reached the later play"
```

```bash
ansible-playbook fleet.yml -e '{"lesson14_broken": ["ubuntu"]}'
ansible-playbook fleet.yml -e '{"lesson14_broken": ["debian"], "lesson14_serial": 3}'
ansible-playbook fleet.yml -e '{"lesson14_broken": ["debian"], "lesson14_serial": 3, "lesson14_maxfail": 0}'
```

The first run shows the default: the failed host drops out, the other seven finish the play and
go on to the later play, and the exit code is 2. A failure is a per-host event. The second run
splits the eight hosts into batches of three; the two healthy hosts of the first batch finish, and
the next batches and the later play run as if nothing had happened. Only the third run, with a
threshold of 0, stops: the other two hosts of the batch do not run the next task, and neither the
later batches nor the later play start. The table collects what was measured with one broken host:

| Setup | Other hosts of the batch | Later batches and plays | Recap lists |
|---|---|---|---|
| no keyword, no `serial` | finish the play | run, without the failed host | all hosts |
| `serial: 3` | finish the play | run | all hosts |
| `serial: 3`, `max_fail_percentage: 0` | stop before the next task | never start | only the hosts of the aborted batch |
| `serial: 1`, the one host fails | none left | never start | only that host |
| `any_errors_fatal: true`, no `serial` | stop before the next task | never start | all hosts (they all started) |

Three details decide whether you read this correctly:

- **The threshold is a share of the batch, and it is strict.** The run stops only when the failed
  share of the current batch is *greater* than the value. With batches of four and two failures,
  `max_fail_percentage: 50` goes on and 49 stops; with one failure, 25 goes on and 24 stops. An
  unreachable host counts as a failure (tested with a host that points at a closed port);
  without a threshold it simply drops out.
- **A batch in which every host fails ends the run** even without a threshold (tested with
  batches of one and of two). With `serial: 1` the first failing host therefore ends everything,
  including later plays such as a report.
- **The recap does not list hosts that never started.** After an abort it can show three hosts
  with `failed=0` and look green. The exit code (2) and the missing hosts are the signal.

`any_errors_fatal` is the binary version: one failure ends the play for everybody, also without
`serial` (tested). It is a keyword of the play and of a block; in a block, a failure ended the
whole play for all hosts, not only the block (tested). `max_fail_percentage: 0` behaved the same
way without `serial`, so the difference is mostly the dial: the percentage lets you tolerate a
failure in a batch of fifty, the binary keyword does not.

**Batch sizes.** `serial` takes a number, a percentage or a list of both. A percentage is a share
of the hosts of the play (after `--limit`), rounded down and at least one; the last element
repeats until all hosts are done. On the eight lab hosts: `[1, "50%", "100%"]` gives 1, 4 and 3
hosts, `["30%"]` gives four batches of two, `["10%"]` gives eight batches of one, `[3]` gives 3, 3
and 2, and `[1, 100]` gives 1 and 7. With `-l` the play has fewer hosts and the percentages shrink
with it.

**What limits parallelism.** Three settings cap how many hosts work at the same moment: `forks`
(the lab sets 10), the batch size of `serial`, and `throttle` on a single task. The strictest wins.
Eight hosts and a task that takes one second need one round with `forks` 10, four with `forks` 2,
two with `serial: 4`, four with `serial: 2`, four with `throttle: 2`, and four with `serial: 4`
and `throttle: 2` together (measured as run time, 2.2 s against 5.3 s). In the lab `forks` is
larger than the eight hosts and never binds; on a fleet it does.

### Preflight and gate: check before you change

A rollout should fail before it has changed anything, so the first play only looks. It checks what
the change needs: the hosts answer, the tools the change will touch pass their own validators
(think of `sh -n` for a shell script), there is room, and an operator has said yes. The play uses
`any_errors_fatal` because a broken host in a preflight is a reason for a human to look, not
something the rest of the fleet should step over.

The "yes" is a variable that has no default and an `assert` behind `run_once`. When a `run_once`
task fails, the run ends: no later task and no later play started, also without
`any_errors_fatal` (tested). `assert` also runs under `--check`, so a dry run cannot skip the
gate. The checks themselves need care under `--check`. Read-only modules such as `stat` run;
`command` is skipped unless `check_mode: false` is set (the kinds of check-mode result are in
[L10](L10-compliance-reporting.md)). A preflight whose checks were skipped is green and has checked
nothing. Save this as `gate.yml`; it also shows where the facts and the kernel disagree:

```yaml
- name: Gate before a change
  hosts: targets
  gather_subset: [hardware]
  any_errors_fatal: true
  tasks:
    - name: Operator confirmed
      ansible.builtin.assert:
        that: lesson14_go | default(false) | bool
        fail_msg: "refusing to go on: pass -e lesson14_go=true"
        quiet: true
      run_once: true

    - name: A probe without the keyword
      ansible.builtin.command: id -un
      register: lesson14_plain
      changed_when: false

    - name: Ask the kernel about the file system of /
      ansible.builtin.command: stat -f -c '%a %S' /
      register: lesson14_kernel
      changed_when: false
      check_mode: false

    - name: Compare the facts with the kernel
      vars:
        lesson14_fields: "{{ lesson14_kernel.stdout.split() }}"
      ansible.builtin.debug:
        msg:
          - "plain probe skipped: {{ lesson14_plain.skipped | default(false) }}"
          - "mount entries for / in the facts: {{ ansible_facts.mounts | selectattr('mount', 'equalto', '/') | list | length }}"
          - "MB available to non-root users on /: {{ (lesson14_fields[0] | int * lesson14_fields[1] | int / 1048576) | int }}"
```

```bash
ansible-playbook gate.yml --check
ansible-playbook gate.yml --check -e lesson14_go=true
```

The first run is refused, `--check` or not. The second prints `plain probe skipped: True` and a size.
On the lab targets the number of mount entries for `/` is **0**: the fact lists a mount only when
its device starts with `/` (or `\`, or looks like `host:/path`, which is how NFS appears), and the
root of a container is the device `overlay`. A check that reads `ansible_facts.mounts` and falls
back to 0 reports an empty disk on every host. The kernel does not have that blind spot. Mind
which number you ask for: `%a` is what non-root users may still use, `%f` also counts the reserve
for root.

Even the right number can mislead. A host sees the free space of its *virtual* disk, not of the
storage behind it. In the lab all eight targets report the capacity of the WSL2 or Docker Desktop
virtual disk (about a terabyte) while the Windows drive that holds it may have a few gigabytes
left. The same holds for qcow2 images, thin LVM pools, thin VMware disks and SAN volumes. A
preflight inside the host cannot see that; the capacity of the backing storage belongs to the
monitoring of the platform. Know what a check proves, and write what it cannot prove into the
runbook.

### Batches, batch lists and the check after each batch

`serial` runs the *whole play* once per batch: tasks, `post_tasks` and the handlers that were
notified, then the next batch (tested). That is what makes "role, then verification, then the next
batch" a single play.
Two special variables describe the situation, and they are easy to mix up. `ansible_play_batch`
holds the hosts of the current batch; `ansible_play_hosts` holds every host of the play that has
not failed, **including the batches that have not run yet**. A task with `run_once` runs once *per
batch*, on the first host of that batch, not once per play. Save this as `batches.yml`:

```yaml
- name: Batches and the lists that describe them
  hosts: targets
  gather_facts: false
  serial: [1, 3, "100%"]
  tasks:
    - name: Record a result for this host
      ansible.builtin.set_fact:
        lesson14_result: "done on {{ inventory_hostname }}"

    - name: Compare the two lists
      ansible.builtin.debug:
        msg: "this batch has {{ ansible_play_batch | length }} hosts, the play {{ ansible_play_hosts | length }}"
      run_once: true

    - name: Read the result of every host of the play
      ansible.builtin.debug:
        msg: "{{ ansible_play_hosts | map('extract', hostvars, 'lesson14_result') | list | length }} results"
      run_once: true
      ignore_errors: true

- name: A later play reads what the earlier play recorded
  hosts: debian
  gather_facts: false
  tasks:
    - name: Read the result of another host
      ansible.builtin.debug:
        msg: "{{ hostvars['alpine'].lesson14_result }}"
```

```bash
ansible-playbook batches.yml
```

The comparison prints `this batch has 1 hosts, the play 8`, then `3 hosts` and `4 hosts` against
the same 8: three batches, the last one with the four hosts that were left. The third task fails in the first two
batches with `object of type 'HostVarsVars' has no attribute 'lesson14_result'`, because it asks
hosts that have not run yet, and succeeds in the last one. A report that is written once per batch
needs a deliberate answer to two questions: which hosts belong in it, and what each batch should
do with what earlier batches wrote. One fact helps: variables set with `set_fact` stay in
`hostvars` for the rest of the run, also in later plays (the last play reads the result of a host
it never ran on), so a canary play and the batch plays can share data. A task that reads such a
variable must not be written as if every host in the list had it already.

**Canary and patterns.** A canary is the first play, with a small group chosen for variety (one
host per platform family is a good start). The rest is a second play with a pattern that
subtracts the canary: `targets:!redhat_family` reads "all targets except that group"
([L00](L00-lab-and-ansible-basics.md) covers patterns), and `--list-hosts` shows what a pattern
selects before anything runs. A canary that passes proves little if its check is "the task did
not fail". Check a property you care about: the service answers, the configuration is valid, and
a *new* SSH connection works ([L13](L13-host-firewall-nftables.md) shows why a reused connection
proves nothing and how `meta: reset_connection` forces a new one).

### Community roles: Galaxy, Git and what to read before you run

The ansible-lockdown project and others maintain CIS roles per distribution with several hundred
controls and a test matrix. Using one means installing code from a third party, so three
questions come first: where does it come from, which version is it, and what does it do.

**Where it comes from.** Roles on Galaxy are backed by a GitHub repository: `ansible-galaxy role
install geerlingguy.ntp` downloads the archive of a tag from GitHub and prints the URL it used. A
role can also be installed straight from a Git URL with `scm: git`. Collections are separate:
`ansible-galaxy collection install` fetches an artifact from the Galaxy server. The control node
needs access to both, and the lab's control container has it (`git` 2.47 is installed there, not
on the targets). Production environments often mirror both into an internal server and install
from there.

**Which version.** `requirements.yml` lists roles and collections, and `version:` pins them. A
tag is a promise of the maintainer and can be moved; a commit hash cannot. A branch name is not a
pin at all. The file below installs one role from Galaxy at a tag, the same role from GitHub at a
commit, and a collection within a range:

```bash
cat > requirements-galaxy.yml <<'EOF'
---
roles:
  - name: ntp_galaxy
    src: geerlingguy.ntp
    version: "4.0.1"
  - name: ntp_git
    src: https://github.com/geerlingguy/ansible-role-ntp
    scm: git
    version: "97e3451fc831c5d291addcce04599253cdca7a87"
collections:
  - name: ansible.posix
    version: ">=1.0.0,<2.0.0"
EOF
ansible-galaxy role info geerlingguy.ntp | head -n 8
ansible-galaxy role install -r requirements-galaxy.yml -p roles
ansible-galaxy collection install -r requirements-galaxy.yml -p collections
ansible-galaxy collection list ansible.posix
```

(`ntp` is only a small, well-known role to practise with, not a hardening recommendation.) The
role info names the GitHub user, repository and commit behind the role. The role install reports
`ntp_galaxy (4.0.1) was installed successfully` and the same for `ntp_git` with the hash; the
collection install reports `ansible.posix:1.6.2` and the path it went to. A second run of the role
install says `is already installed, skipping` for both. Your versions and dates will differ as the
projects move on; the pins above stay installable. Two traps are visible in this run. The
collection range `<2` installed 1.6.2 into `collections/`, while the lab's control node
already carries `ansible.posix` 2.2.2 as part of the Ansible package, and `ansible-galaxy
collection list ansible.posix` still shows only the 2.2.2: the new copy is invisible until its
directory is on the collections path (the install warns that it is not), and then the order of that path decides which one runs.
Roles have the same problem: which copy runs depends on where Ansible finds the name first
([L07](L07-roles-tags-project-structure.md) lists the places).

**What the install does with a pin.** The same behaviour is easier to see with a repository of your
own. This block builds a tiny role in a local Git repository and installs it from there. The
installer insists on a `meta/main.yml`, even a nearly empty one; without it the role is refused
with `this role does not appear to have a meta/main.yml file` (tested):

```bash
mkdir -p upstream/lesson14_stamp/tasks upstream/lesson14_stamp/defaults upstream/lesson14_stamp/meta roles
printf -- '---\nlesson14_stamp_text: hello\n' > upstream/lesson14_stamp/defaults/main.yml
printf -- '---\ndependencies: []\n' > upstream/lesson14_stamp/meta/main.yml
cat > upstream/lesson14_stamp/tasks/main.yml <<'EOF'
---
- name: Write the stamp
  ansible.builtin.copy:
    content: "{{ lesson14_stamp_text }}\n"
    dest: /tmp/lesson14_stamp
    mode: "0644"
  tags: [stamp]

- name: Show who runs
  ansible.builtin.command: id -un
  changed_when: false
  check_mode: false
  tags: [probe]
EOF
git -C upstream/lesson14_stamp init -q -b main
git -C upstream/lesson14_stamp add -A
git -C upstream/lesson14_stamp -c user.name=demo -c user.email=demo@example.invalid commit -q -m first
git -C upstream/lesson14_stamp tag v1.0.0
cat > requirements.yml <<'EOF'
---
roles:
  - name: lesson14_stamp
    src: /tmp/lesson14/upstream/lesson14_stamp
    scm: git
    version: v1.0.0
EOF
ansible-galaxy role install -r requirements.yml -p roles
ansible-galaxy role list -p roles
```

Now the maintainer publishes a new tag and you change the pin:

```bash
git -C upstream/lesson14_stamp -c user.name=demo -c user.email=demo@example.invalid commit -q --allow-empty -m second
git -C upstream/lesson14_stamp tag v1.1.0
sed -i 's/version: v1.0.0/version: v1.1.0/' requirements.yml
ansible-galaxy role install -r requirements.yml -p roles
ansible-galaxy role install --force -r requirements.yml -p roles
```

The first install only warns: `lesson14_stamp (v1.0.0) is already installed - use --force to change
version to v1.1.0`. A pin in the file is a statement about what you want, and the install does not
reconcile it with what is on disk unless you force it. A role installed without `version:` is
listed as `(unknown version)`, and with `version: main` you get whatever the branch holds on the
day you install, a different tree tomorrow. The installed copy holds no Git history; the version
and the date are in `meta/.galaxy_install_info`.

**What it does.** Read before you run, in this order. `ansible-playbook site.yml --list-tasks
--list-tags` prints what the play would do without doing it; `--syntax-check` catches a role that
does not load; and `--check --diff` against one freshly reset host shows what would change (with
the limits from [L10](L10-compliance-reporting.md): `command` tasks are skipped unless they are
marked read-only). Save this as `site.yml`:

```yaml
- name: Use the installed role
  hosts: targets
  gather_facts: false
  roles:
    - role: lesson14_stamp
```

```bash
ansible-playbook site.yml --list-tasks --list-tags
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --check --diff -l debian
```

The listing shows both tasks with their tags (`stamp`, `probe`); the check run reports the file as
a change with its content. Then read the role itself: `defaults/` shows which knobs exist and
their names, `tasks/` shows the structure, and a search for `command`, `shell` and `raw` finds the
tasks that do not know about idempotency or check mode. Look at `meta/` for dependencies that
install more roles, at the handlers for service restarts, at what it writes outside its own area,
and at the tests that ship with it (the Galaxy role above carries a `molecule` directory).
`ansible-lint` on the role is a cheap second opinion.

**Adopt, fork or build.** Adopting buys coverage and someone else's maintenance. It costs the
review of every release, a dependency on the maintainers' pace (benchmarks change versions), and
a tension between the role's design and your exceptions. Forking gives you control and a merge
job with every upstream change. Building gives full control over every line, for a scope you can
test yourself, and you own all the bugs. Many teams wrap an adopted role in a small role of their
own for settings, exceptions and reporting. The criteria are fit, review effort, test coverage and
who fixes what at three in the morning.

## CIS background

A rollout is not a benchmark section, which is why the header lists none: the recommendations say
what to configure, not how to get it onto two thousand servers. The benchmarks do warn, per
recommendation, about the impact of a change, and that is the input for the order of a rollout:
the controls that can lock someone out or break an application (access, authentication, network
filtering, mount options, mandatory access control) belong in an early canary on every platform
and in a small first batch ([L01](L01-cis-benchmarks.md) lists the pitfall for Level 2). A
community role gives you hundreds of recommendations at once; the benchmark version it targets
and the way it marks the disruptive ones tell you how much of the thinking was done for you.
The exact recommendation numbers differ per benchmark and version; look them up in the PDF of
your distribution.

## Platform differences

| os_family | Hosts | `sshd` binary | `df` binary | Missing in the image |
|---|---|---|---|---|
| Debian | debian, ubuntu | `/usr/sbin` | `/usr/bin` | `git` |
| RedHat | rocky, alma / fedora | `/sbin` / `/usr/sbin` | `/bin` / `/usr/sbin` | `git`; fedora also `hostname` |
| Suse | opensuse | `/usr/sbin` | `/usr/bin` | `git`, `hostname` |
| Alpine | alpine | `/usr/sbin` | `/bin` | `git`; Python before 0.02 |
| Archlinux | arch | `/usr/bin` | `/usr/bin` | `git`, `hostname` |

The binaries live in different directories per family (and `df` on fedora is under `/usr/sbin`),
so a preflight should not rely on one path or on the `hostname` command; `inventory_hostname` is
always there. `stat -f -c` works on all eight hosts, Alpine included. All eight report the file
system of `/` as `overlay` with the same capacity.

### In the lab containers

The eight targets are containers on one Docker host. A broken rollout can only break one container
at a time, and `./lab.sh reset <host>` restores it. Three things differ from a real fleet. With
eight hosts, percentages are coarse (10 % is one host, 30 % is two; in the six-host batch play of
[5.02](../../exercises/stage5-capstone/5.02-rollout-strategy/README.md) 30 % is one) and `forks` is
never the limit. `ansible_facts.mounts` has no entry for `/`, and free space is the capacity of the virtual
disk of Docker Desktop (see [container limits](../CONTAINER_LIMITS.md)). And a connection check
only proves the network path of the Docker bridge, not that of a production network.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The recap shows `failed=0` for the hosts it lists and the run ended early | an aborted batch leaves later hosts out of the recap | read the exit code and compare the recap with the host list |
| The rollout went on after a failure | the default tolerates failures in a batch with more than one host | set `max_fail_percentage` (and remember the comparison is strict) |
| A later play, such as the report, never ran | every host of a batch failed, so no host was left | run the report as a step of its own that does not depend on the rollout finishing |
| A percentage batch is larger than expected | the percentage counts the hosts of the play, not those that remain, rounded down | compute from the play size, `--limit` included |
| `object of type 'HostVarsVars' has no attribute '...'` in a report | `ansible_play_hosts` lists hosts of batches that have not run | decide which hosts the report is about and pick the list for that |
| The gate is green and nothing was checked | read-only `command` tasks are skipped under `--check` | `check_mode: false` on read-only probes, and look for `skipped` |
| "0 MB free" on every host | `ansible_facts.mounts` has no entry for the container's root | ask the kernel, and treat facts as a convenience |
| Plenty of space, writes fail | the host sees the virtual disk, not the storage behind it | monitor the backing storage; do not trust the number inside the guest |
| `does not appear to have a meta/main.yml file` | the installer needs the file, even a nearly empty one | add `meta/main.yml` to the role |
| A changed pin is not installed | an installed role is skipped without `--force` | `--force` after reading what changes, and look at `role list` |
| The role differs from last week | `version:` is a branch or missing | pin a tag, better a commit |
| `collection list` shows another version than the one installed | the new copy is not on the collections path, the bundled one is | install where the path finds it, or set the path deliberately |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [5.02](../../exercises/stage5-capstone/5.02-rollout-strategy/README.md) | failure semantics and their recap, `serial` lists, a gate and probes that also run under `--check`, what facts and free space can and cannot tell, per-batch verification and reports |
| [5.03](../../exercises/stage5-capstone/5.03-compare-with-community-role/README.md) | where community roles come from, pinning, reading a role without running it, criteria for adopt, fork or build |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. With eight hosts and `serial: 3`, one host of the first batch fails and nothing else is set.
   What happens to the other hosts and to the later plays?

   <details><summary>Answer</summary>

   The two healthy hosts finish the play, the next batches run, and later plays run without the
   failed host; only the exit code (2) and the recap mark the failure. A batch with more than one
   host tolerates failures unless a threshold or `any_errors_fatal` says otherwise.

   </details>

2. Batches of four, one host fails, `max_fail_percentage: 25`. Does the run go on? What if it is 24?

   <details><summary>Answer</summary>

   It goes on at 25 and stops at 24: one of four is 25 %, and the run stops only when the failed
   share of the batch is greater than the value.

   </details>

3. After an aborted rollout the recap shows three hosts with `failed=0`. Is the fleet fine?

   <details><summary>Answer</summary>

   No. Hosts that never started are not in the recap. Compare it with the host list and look at
   the exit code; the three listed hosts are those of the batch that was aborted.

   </details>

4. What are the batch sizes of `serial: [1, "50%", "100%"]` on eight hosts, and on six after `-l`?

   <details><summary>Answer</summary>

   Eight hosts: 1, 4 and 3. Six hosts: 1, 3 and 2. The percentage is a share of the hosts of the
   play, not of those that remain, and the last batch takes what is left.

   </details>

5. A preflight with a `command` task is green under `--check` on a host that is in fact broken.
   Why, and what do you change?

   <details><summary>Answer</summary>

   `command` is skipped in check mode, so nothing was checked. A read-only probe gets
   `check_mode: false`, and the gate should treat a skipped probe as a failure, not as a pass.

   </details>

6. A report task with `run_once` reads a variable of every host in `ansible_play_hosts` and fails in
   the first batch. Why, and why is `ansible_play_batch` not the whole answer?

   <details><summary>Answer</summary>

   Under `serial` the list holds all hosts that have not failed, including batches that have not
   run and therefore have no such variable. The batch list would not crash, but every batch would
   then see only its own hosts. Decide which hosts the report is for and choose the list for that.

   </details>

7. The facts say there is no mount for `/`, a command says there are 900 GB free, and the disk is
   full. Which statements are true?

   <details><summary>Answer</summary>

   The facts skip devices that do not look like a path or `host:/path`, so a container root is
   missing. The command reports the virtual disk, which can be larger than the storage it sits on.
   Both are true, and neither measures the backing storage.

   </details>

8. You changed `version:` in `requirements.yml` and ran the install; the old version is still
   there. Why, and how do you find out what is installed?

   <details><summary>Answer</summary>

   An installed role is skipped unless you force the install, and the install warns about it.
   `ansible-galaxy role list` shows the installed version and `meta/.galaxy_install_info` the date.
   A tag can be moved and a branch moves on its own; a commit hash pins.

   </details>

## Further reading

- [Controlling playbook execution](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_strategies.html) - `serial`, `throttle`, `run_once`, strategies
- [Error handling in playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html) - `any_errors_fatal`, `max_fail_percentage`, `ignore_errors`
- [Patterns: targeting hosts and groups](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_patterns.html) - subtracting a group, `--limit`
- [Special variables](https://docs.ansible.com/projects/ansible/latest/reference_appendices/special_variables.html) - `ansible_play_batch`, `ansible_play_hosts`
- [Galaxy user guide](https://docs.ansible.com/projects/ansible/latest/galaxy/user_guide.html) - installing roles and collections, `requirements.yml`
- [`ansible-galaxy`](https://docs.ansible.com/projects/ansible/latest/cli/ansible-galaxy.html) - `role install`, `role list`, `collection install`, `--force`
- [Validating tasks: check mode and diff mode](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html) - `check_mode: false` on read-only tasks
- [stat(1)](https://manpages.debian.org/unstable/coreutils/stat.1.en.html) - `-f` for the file system, `%a`, `%f`, `%S`
- [Glossary](../GLOSSARY.md) - terms of this lesson: `any_errors_fatal`, batch, canary,
  `delegate_to` / `run_once`, Galaxy, gate, `max_fail_percentage`, preflight, `serial`
