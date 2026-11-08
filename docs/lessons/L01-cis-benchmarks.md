# L01 - CIS Benchmarks: structure, levels and the lab catalogue

*[Deutsch](L01-cis-benchmarks.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| - | - | ~25 min | L00 |

Every exercise of this lab names a CIS section in its header; this lesson explains what is
behind that reference - how a CIS Benchmark is made and organised, what Level 1 and Level 2
mean, how a recommendation turns into an Ansible task and how the lab's own catalogue
connects the exercises to the official PDFs.

## Learning goals

After this lesson you can ...

- [ ] explain what a CIS Benchmark is, who writes it and why you cannot copy it into a repository
- [ ] read a recommendation: find its profile, its audit and remediation part and its impact
- [ ] tell *Automated* from *Manual* recommendations and say why both matter
- [ ] choose between Level 1 and Level 2 and between the Server and Workstation profiles
- [ ] map the audit and remediation parts of a recommendation to Ansible tasks and know what does not automate
- [ ] use `cis/controls.yml` and the CIS reference of an exercise to find the matching chapter of a benchmark

## Theory

### What a CIS Benchmark is

The Center for Internet Security (CIS) is a non-profit organisation. Its **Benchmarks** are
secure configuration baselines for one product in one version: "Ubuntu Linux 24.04 LTS",
"Red Hat Enterprise Linux 9", but also browsers, databases, cloud accounts and network devices.
A Benchmark does not describe *what* to protect in general; it says *which setting* to choose
on that product and how to verify it.

Benchmarks are written in a **consensus process**: CIS and volunteer subject-matter experts
draft the document, the community tests and comments on it, CIS works the feedback in, and
after a final review round the Benchmark is published. New versions follow when the product
or the threat picture changes. The result is a baseline many organisations accept as
"reasonable", which is why auditors, insurers and security questionnaires ask for it.

Three related things are easily mixed up:

| Name | What it is | Relation to the Benchmarks |
|---|---|---|
| CIS Controls (v8.1) | 18 product-independent security measures, grouped into Implementation Groups IG1-IG3 | each recommendation of a Benchmark refers to the Controls safeguards it supports |
| CIS-CAT | assessment tool (Lite free, Pro for members) | evaluates the *Automated* recommendations of a Benchmark and produces a score |
| CIS Hardened Images | pre-hardened cloud images | a Benchmark profile applied by CIS, sold through cloud marketplaces |

The PDFs are free after registration, but their terms do not allow redistribution. That is why
this lab ships no CIS text: download the Benchmarks yourself as described in
[the CIS README](../../cis/README.md), keep them in `cis/pdf/` (ignored by Git) and write
your own wording in code, comments and documentation.

### Anatomy of a recommendation

A Linux Benchmark is organised in sections. Since 2024 the Linux Benchmarks share this
top-level structure, which [the control catalogue](../../cis/controls.yml) uses:

| Section | Topic | Examples in the lab |
|---|---|---|
| 1 | Initial setup | kernel modules, process hardening, banners |
| 2 | Services | server and client services, cron |
| 3 | Network | network kernel modules and parameters |
| 4 | Host based firewall | nftables |
| 5 | Access control | SSH, sudo, PAM, shadow suite, accounts |
| 6 | Logging and auditing | AIDE, logging, auditd |
| 7 | System maintenance | file permissions, users and groups |

Below that, sections nest (5 Access control → 5.1 SSH server → 5.1.x one sshd parameter). The
leaf is a **recommendation**, and every recommendation has the same fields:

| Field | Content | Why you care |
|---|---|---|
| Title | the target state in one line, with the assessment status | what to achieve |
| Profile applicability | Level 1 / Level 2, Server / Workstation | whether it applies to you |
| Description, Rationale | what the setting does, which attack it limits | the argument for an exception discussion |
| Impact | what may break | the risk of applying it |
| Audit | commands and expected output | what your check has to prove |
| Remediation | how to reach the state | what your enforcing task does |
| Default value | the distribution's default | what a fresh host shows |
| References, CIS Controls | man pages, mapping to Controls safeguards | context, reporting |

The **assessment status** in the title is either *Automated* or *Manual* (before late 2020
they were called *Scored* and *Not Scored*). *Automated* means a tool can compare the system
with the expected state and return pass or fail. *Manual* means a person has to judge it - for
example whether the list of allowed SSH users is the right one for this host. CIS-CAT leaves
Manual recommendations out of its score, but they are not optional: an empty or wrong allow-list
is as much a finding as a wrong file mode.

**Numbers move.** Recommendation numbers differ between distributions and change between
versions of the same Benchmark. Older Linux Benchmarks, for example, had logging and auditing
in section 4 and system maintenance in section 6; the 2024 structure gave the host firewall its
own section 4 and moved those two to sections 6 and 7.
The lab therefore references only the stable upper levels (`5.1`, `6.3`) and leaves the exact
number to the PDF of your distribution and version.

### Profiles and levels

Not every hardening measure suits every system. Each recommendation states the **profiles**
it belongs to. Linux Benchmarks typically have four:

| | Server | Workstation |
|---|---|---|
| **Level 1** | practical baseline for servers: clear security benefit, little impact on operation | the same idea for desktops (graphical session, removable media in use) |
| **Level 2** | adds defence-in-depth measures for environments with high protection needs; may restrict functionality or cost performance | the same for desktops |

Level 2 *extends* Level 1: a Level 2 system applies all Level 1 recommendations plus the
Level 2 ones. Typical Level 2 material is extensive auditing, disabling rarely used network
protocols or stricter mount options - useful where the protection need justifies the cost,
harmful where nobody reads the audit logs and the disk fills up.

The lab uses **Level 1 Server** as baseline. Level 2 appears only where an exercise says so;
in the catalogue those are 3.2 (rare network protocols) and 6.3 (auditd). Exercises with
Level 2 content take the level as the variable `cis_level` (default 1), and the checks of the
cumulative role accept it too:

```bash
lab check 4.03 -e cis_level=2
```

How a role honours such a switch - and how it records deliberate exceptions - is the topic of
exercise 4.02 and lesson L11.

### From recommendation to automation

The two practical fields of a recommendation map directly to two kinds of Ansible tasks:

| Recommendation | Ansible | Lab |
|---|---|---|
| Audit | read-only tasks that report a deviation (`register`, `assert`, check mode) | every `lab check`, exercise 4.01 (audit-only report) |
| Remediation | tasks that describe the target state (`lineinfile`, `template`, `file`, `package`) | every hardening exercise |
| Impact | `--check --diff` before applying, staged rollout | 1.x (safe changes), 5.02 (rollout) |
| Default value | what a fresh target shows | `./lab.sh reset <host>` |

The remediation text of a Benchmark is written for a person at a shell: "edit the file and set
...", "run ...". Copying those commands into `shell` tasks gives you a playbook that changes
something on every run. Translate the *target state* instead, so that Ansible can decide
whether a change is needed (lesson L00, idempotency).

Some recommendations do not automate fully:

- **Manual** recommendations need a decision - which users may log in, which services are
  needed. Ansible can enforce the decision once it is written down as data, not make it.
- **Site-specific values** (allowed networks, log servers, banner text) belong into variables,
  not into tasks.
- **Exceptions** are normal: no organisation applies a Benchmark at 100 %. What matters is that
  every deviation is written down with a reason, an owner and an expiry date - and that the
  automation knows about it instead of someone reverting the change by hand.

Finally: compliance is not security. A host can pass every Automated recommendation and still
run an unpatched service on a public port. A Benchmark is a baseline to start from, not proof
that a system is safe.

### The lab catalogue: `controls.yml` and `meta.yml`

[`cis/controls.yml`](../../cis/controls.yml) is the lab's own catalogue, in its own words.
One entry per control:

```yaml
- id: "5.1"
  section: 5 Access control / SSH server
  title: SSH hardened (no root login, limited auth tries, strong crypto, allow-list, timeouts, banner)
  level: 1
  container: full
  exercises: ["1.03", "2.02", "3.01", "5.01"]
  platforms: ssh vs sshd service name; first match wins; EL crypto-policies included after drop-ins
```

`id` and `section` point to the Benchmark structure, `level` to the profile, `exercises` to
the exercises that implement it and `platforms` to differences between the distributions.
`container` says how far the lab can show the effect (see *In the lab containers* below).

The other direction is in each exercise: its `meta.yml` has a `cis` entry with section and
level, which appears as *CIS reference* in the README header and in `lab list`. So the way
from an exercise to the Benchmark is: CIS reference of the exercise → entry in `controls.yml`
(platform notes) → chapter in the PDF of your distribution.

The catalogue is plain YAML, so Ansible can query it. This play runs on the control node
only and changes nothing:

```yaml
- name: Query the lab control catalogue
  hosts: localhost
  gather_facts: false
  vars:
    catalogue: "{{ lookup('ansible.builtin.file', '/lab/cis/controls.yml') | from_yaml }}"
  tasks:
    - name: List the Level 2 controls
      ansible.builtin.debug:
        msg: "{{ catalogue.controls | selectattr('level', '==', 2) | map(attribute='id') | list }}"

    - name: List the controls the containers cannot reproduce
      ansible.builtin.debug:
        msg: "{{ catalogue.controls | selectattr('container', '==', 'no') | map(attribute='id') | list }}"

    - name: Show which exercises implement section 5.1
      ansible.builtin.debug:
        msg: "{{ (catalogue.controls | selectattr('id', '==', '5.1') | first).exercises }}"
```

Save it as `/lab/work/demo/catalogue.yml` and run `ansible-playbook catalogue.yml` there. The
first task prints `3.2` and `6.3`, the second `1.1.2`, `1.3` and `1.4`. The ids are strings in
the catalogue - compare them with `'5.1'`, not with the number `5.1`. Do not worry about
`selectattr` and the other filters yet; lesson L04 covers them. The static gate
(`tools/static-check.sh controls`) keeps both directions consistent: an exercise whose `cis`
section names a catalogue id must be listed in that control's `exercises`.

## CIS background

Why do Benchmarks matter beyond the lab? Because they are the common language between
administrators and auditors. "We follow CIS Level 1 Server with these 12 documented exceptions"
is a statement a reviewer can check; "our servers are hardened" is not. Standards such as
PCI DSS require a configuration standard for system components and name industry baselines
like CIS as one source; internal policies often reference a Benchmark by name and version.

Other baselines cover the same ground: the DISA STIGs (US Department of Defense) are stricter
and more prescriptive, and in Germany the BSI IT-Grundschutz-Kompendium describes requirements
for Linux servers in the module SYS.1.3. They overlap with CIS in content but differ in
numbering, wording and strictness. If your organisation follows one of them, the techniques of
this lab stay the same - only the catalogue changes.

The value of a Benchmark lies in the *Rationale* and *Impact* fields as much as in the
settings: they let you argue for a measure, and against it where it does not fit.

## Platform differences

| os_family | Hosts | Benchmark to use | Note |
|---|---|---|---|
| Debian | debian, ubuntu | Debian Linux, Ubuntu Linux (per LTS) | separate Benchmarks, numbering differs |
| RedHat | rocky, alma, fedora | Rocky Linux, AlmaLinux OS, Red Hat Enterprise Linux | no current Fedora Benchmark: use the RHEL one as the closest reference |
| Suse | opensuse | SUSE Linux Enterprise | openSUSE Leap shares the code base |
| Alpine | alpine | none | map the controls yourself; many are not applicable (no PAM, busybox) |
| Archlinux | arch | none | map the controls yourself |

The exact versions to download are listed in [the CIS README](../../cis/README.md). Mapping
controls to a platform without a Benchmark is part of the training: the intent of a
recommendation (the Rationale) carries over, the commands and file names do not.

### In the lab containers

The targets are containers on a shared kernel (lesson L00), so not every control can be
practised the same way. The `container` field of each catalogue entry says how far it goes:

| Value | Meaning | Examples |
|---|---|---|
| `full` | configure and verify inside the containers | SSH, sudo, file permissions |
| `config` | write the configuration; the effect is kernel- or host-wide and is not activated | kernel modules, global sysctls, auditd |
| `no` | not reproducible in containers - theory or a real VM | partitions, MAC (SELinux/AppArmor), bootloader |

See [container limits](../CONTAINER_LIMITS.md) for the details per control.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The number from a scanner report does not match your PDF | different Benchmark version or distribution | compare titles, not numbers; note Benchmark name and version in reports and code |
| A Level 2 rollout breaks an application or fills a disk | Level 2 applied without reading *Impact* | choose the level per system class, test on a canary first |
| 100 % score, but a reviewer still finds problems | score covers *Automated* recommendations only | review the Manual ones and record the decisions as data |
| A playbook reports `changed` on every run | remediation commands copied into `shell` tasks | describe the target state with state modules |
| Benchmark text in your repository or wiki | licence terms forbid redistribution | own wording, reference by section number and title |
| A change made on a host is reverted by the next run | the exception exists only in someone's head | record exceptions with reason, owner and expiry where the automation reads them |

## Exercises

This lesson has no exercise of its own: it is the background for all of them. Each exercise
names its CIS section and level in the README header and in `lab list`; look the section up
in `cis/controls.yml` before you start. Three exercises work with the concepts directly:
[4.01](../../exercises/stage4-advanced/4.01-audit-only-report/README.md) (audit without
remediation),
[4.02](../../exercises/stage4-advanced/4.02-profiles-and-exceptions/README.md) (Level 1/2 and
documented exceptions) and
[5.03](../../exercises/stage5-capstone/5.03-compare-with-community-role/README.md) (reviewing a
community CIS role).

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A scanner reports "5.2.4 failed" for an Ubuntu host. Your PDF lists something else under
   5.2.4. Who is wrong?

   <details><summary>Answer</summary>

   Probably nobody: the scanner and your PDF use different Benchmark versions (or the scanner
   uses another distribution's Benchmark). Numbers are only meaningful together with
   Benchmark name and version. Compare the titles and the audit procedure, and record the
   version in reports.

   </details>

2. Your manager wants "100 % CIS compliance" proven by a CIS-CAT report. Why is the report
   not enough?

   <details><summary>Answer</summary>

   The score covers only the *Automated* recommendations. *Manual* ones (allow-lists, which
   services are needed) need a documented human decision, and every deliberate deviation needs
   a recorded exception. Also, compliance with a baseline does not prove security - patching and
   exposure are outside a configuration Benchmark.

   </details>

3. A database server and a jump host for administrators - which profile would you start from
   for each, and why?

   <details><summary>Answer</summary>

   Both are servers, so a Server profile. Level 1 is the default for the database server;
   Level 2 measures (extensive auditing, stricter restrictions) are worth their cost on the jump
   host, which is a high-value target, provided someone evaluates the audit logs. The decision
   follows the protection need and the *Impact* of the Level 2 recommendations.

   </details>

4. The Remediation of a recommendation says: "Run the following command and edit the file to
   set ...". Why do you not put that command into an `ansible.builtin.shell` task?

   <details><summary>Answer</summary>

   A shell command cannot tell whether the state is already reached, so the task changes
   something (or at least reports `changed`) on every run, and `--check` cannot predict it.
   Translate the target state into a state module (`lineinfile`, `template`, `file`, ...); then
   the second run reports no change and the playbook doubles as a compliance check.

   </details>

5. Control 6.3 (auditd) has `container: config` in the catalogue. What does that mean for the
   exercises that implement it?

   <details><summary>Answer</summary>

   The exercises write the audit rules and settings and check the files, but they do not load
   the rules or start auditd: the audit subsystem belongs to the shared host kernel, so
   activating it in a container would affect the Docker host and all other containers.

   </details>

6. Arch Linux has no CIS Benchmark. How do you decide what to apply to the `arch` target?

   <details><summary>Answer</summary>

   Start from a Benchmark of a similar distribution (or the lab catalogue) and take over the
   *intent* of each recommendation from its Rationale, then find the Arch-specific package
   names, file locations and tools. Document where a control does not apply or is implemented
   differently - the same work you do for any platform without a Benchmark.

   </details>

## Further reading

- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) - list of all Benchmarks and download
- [The CIS Benchmarks community consensus process](https://www.cisecurity.org/insights/blog/the-cis-benchmarks-community-consensus-process)
- [Changes to CIS Benchmark assessment/recommendation scoring](https://www.cisecurity.org/insights/blog/changes-to-cis-benchmark-assessment-recommendation-scoring) - Automated and Manual
- [CIS Critical Security Controls](https://www.cisecurity.org/controls)
- [Working with lookups](https://docs.ansible.com/projects/ansible/latest/plugins/lookup.html) and [Using filters to manipulate data](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_filters.html)
- [Glossary](../GLOSSARY.md) - terms of this lesson: Automated / Manual, CIS Benchmark,
  CIS Controls, CIS-CAT, control (lab catalogue), Level 1 / Level 2, profile (CIS),
  recommendation (CIS), `requires` (meta.yml)
