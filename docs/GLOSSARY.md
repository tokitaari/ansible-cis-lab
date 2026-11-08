# Glossary

*[Deutsch](GLOSSARY.de.md)*

Short explanations of the terms that the lessons and exercises use, sorted by the English
term as it appears in Ansible, in the code and in the manual pages. Each entry links to the
lesson section that explains it in depth. In the lab, `lab lesson <n>` opens a lesson and
`lab docs glossary` this page.


## A

- **ad-hoc command** - `ansible <pattern> -m <module> -a <arguments>`: one module on many hosts, without a playbook. Good for looking at the current state. ([L00](lessons/L00-lab-and-ansible-basics.md#inventory-and-patterns))
- **AIDE** - Advanced Intrusion Detection Environment: stores checksums and attributes of files in a database (the baseline) and reports later what differs from it. ([L09](lessons/L09-auditing-and-integrity.md#aide-baseline-check-update))
- **allow and deny lists** - `cron.allow` / `cron.deny` and `at.allow` / `at.deny` decide who may use `crontab` and `at`. An existing allow file wins; they do not touch jobs that already exist. ([L06](lessons/L06-job-schedulers.md#who-may-schedule-allow-and-deny-lists))
- **`always` (tag)** - Special tag: the task runs even when `--tags` selects other tags. Only `--skip-tags always` stops it. ([L07](lessons/L07-roles-tags-project-structure.md#tags-choosing-what-runs))
- **`any_errors_fatal`** - Play keyword: a failure on one host ends the play for all hosts. ([L14](lessons/L14-production-rollout.md#failure-semantics-who-stops-when-something-fails))
- **`assert`** - `ansible.builtin.assert` fails when a condition is false - the tool to check input before the first change. ([L11](lessons/L11-profiles-exceptions-and-data-driven-roles.md#exceptions-are-records-and-input-is-validated-before-anything-runs))
- **`async` / `poll` / `async_status`** - Run a task in the background on the target: `async` is the maximum run time in seconds, `poll: 0` returns at once, `async_status` asks for the result later. ([L09](lessons/L09-auditing-and-integrity.md#long-running-tasks-async-poll-and-async_status))
- **at** - Schedules a job that runs once at a given time (`atd` runs it). ([L06](lessons/L06-job-schedulers.md#where-jobs-come-from-and-whose-authority-they-run-under))
- **attack surface** - Everything an attacker can reach or misuse. Hardening reduces it in layers: installed, running, enabled at boot. ([L03](lessons/L03-base-hardening.md#attack-surface-in-layers-installed-running-enabled))
- **audit mode** - A run of the role that only checks and reports, and changes nothing. In the lab it uses the same tasks as the enforce mode, run as a dry run. ([L10](lessons/L10-compliance-reporting.md#one-code-path-for-audit-and-enforce))
- **auditd** - The daemon that writes the records of the kernel's audit subsystem to disk. Which events are recorded is set by audit rules; `augenrules` merges the files in `/etc/audit/rules.d/` and loads them. ([L09](lessons/L09-auditing-and-integrity.md#the-audit-subsystem-kernel-records-daemon-stores))
- **authselect** - The Red Hat family's tool that writes the PAM stack from a profile. Hand edits of the generated files are overwritten. ([L08](lessons/L08-accounts-and-pam.md#pam-types-controls-and-who-writes-the-stack))
- **Automated / Manual** - Assessment status of a CIS recommendation: an *Automated* one can be checked by a tool and counts in the CIS-CAT score, a *Manual* one needs a person. Before November 2020: Scored / Not Scored. ([L01](lessons/L01-cis-benchmarks.md#anatomy-of-a-recommendation))

## B

- **batch** - One group of hosts in a rollout with `serial`. The next batch starts when the previous one has finished. ([L14](lessons/L14-production-rollout.md#batches-batch-lists-and-the-check-after-each-batch))
- **`become`** - Ansible's privilege escalation: the task runs as another user on the target, as root by default (in the lab via sudo). ([L00](lessons/L00-lab-and-ansible-basics.md#the-lab-one-control-node-eight-targets))
- **`blacklist` (modprobe)** - Tells `modprobe` to ignore a module's own aliases. It does not stop an explicit load by name; `install <module> /bin/false` does. ([L05](lessons/L05-kernel-modules-and-sysctl.md#kernel-modules-who-loads-them-and-what-modprobed-can-stop))
- **`block` / `rescue` / `always`** - Groups tasks. `rescue` runs when a task in the block fails, `always` runs in every case - a way back after a failed change. ([L02](lessons/L02-safe-changes.md#a-way-back-order-the-risk))

## C

- **canary** - The first, small batch of a rollout, chosen for variety. A problem shows there before the whole fleet has changed. ([L14](lessons/L14-production-rollout.md#batches-batch-lists-and-the-check-after-each-batch))
- **capability flag** - A value in the platform data that says what a platform can do (`..._supported: false`). Tasks ask about the capability, not about the operating system. ([L11](lessons/L11-profiles-exceptions-and-data-driven-roles.md#platform-data-and-capability-flags))
- **`changed` / `ok`** - Task results: `changed` means the module changed the system, `ok` that it was already in the described state. A second run of a correct playbook reports only `ok`. ([L00](lessons/L00-lab-and-ansible-basics.md#idempotency-describe-the-state-not-the-steps))
- **`changed_when` / `failed_when`** - Override how Ansible judges a task result. `raw`, `command` and `shell` cannot know whether they changed something, so you tell them. ([L00](lessons/L00-lab-and-ansible-basics.md#how-a-module-runs))
- **check mode** - `--check`: modules report what they would change without changing it. Some cannot predict (`raw`, `command`) and are skipped unless `check_mode: false` is set. ([L02](lessons/L02-safe-changes.md#check-mode-what-it-can-and-cannot-predict))
- **CIS Benchmark** - A configuration guide for one platform, written in a consensus process by the Center for Internet Security, made of numbered recommendations. ([L01](lessons/L01-cis-benchmarks.md#what-a-cis-benchmark-is))
- **CIS Controls** - CIS's prioritised list of safeguards for a whole organisation (version 8.1). Not the same as the Benchmarks, which configure single systems. ([L01](lessons/L01-cis-benchmarks.md#what-a-cis-benchmark-is))
- **CIS-CAT** - CIS's assessment tool: checks a system against a Benchmark and computes a score. ([L01](lessons/L01-cis-benchmarks.md#what-a-cis-benchmark-is))
- **collection** - The unit in which modules, plugins and roles are shipped, for example `ansible.posix` or `community.general`. Its name is the first part of the FQCN. ([L05](lessons/L05-kernel-modules-and-sysctl.md#collections-where-ansibleposixsysctl-comes-from))
- **compliance report** - The per-host results of an audit, collected into one document (in the lab JSON and Markdown) that shows which control passes where. ([L10](lessons/L10-compliance-reporting.md#from-per-host-results-to-one-report))
- **control (lab catalogue)** - One entry of `cis/controls.yml`: a CIS section the lab automates, with its level, platforms and exercises. ([L01](lessons/L01-cis-benchmarks.md#the-lab-catalogue-controlsyml-and-metayml))
- **control node** - The machine on which Ansible runs and from which it connects to the targets - in the lab the `control` container. ([L00](lessons/L00-lab-and-ansible-basics.md#the-lab-one-control-node-eight-targets))
- **cron** - The daemon that runs recurring jobs from the crontabs, `/etc/crontab`, `/etc/cron.d` and the periodic directories. It ignores files whose owner or mode it does not accept. ([L06](lessons/L06-job-schedulers.md#where-jobs-come-from-and-whose-authority-they-run-under))
- **custom facts** - Files in `/etc/ansible/facts.d/*.fact` on a target: static JSON or INI, or an executable that prints JSON. They appear under `ansible_local`. ([L10](lessons/L10-compliance-reporting.md#custom-facts-hosts-that-describe-themselves))

## D

- **dead-man switch** - A timed job that undoes a risky change unless you confirm it in time. If the change cuts your connection, the host repairs itself. ([L13](lessons/L13-host-firewall-nftables.md#a-change-you-may-not-survive-the-dead-man-switch))
- **`defaults/` and `vars/`** - Two variable directories of a role: `defaults/` has the lowest precedence and is the interface for users, `vars/` has a high precedence and holds internal data. ([L07](lessons/L07-roles-tags-project-structure.md#defaults-and-vars-an-interface-and-internal-data))
- **`delegate_to` / `run_once`** - `delegate_to` runs a task on another host (often `localhost`, the control node), `run_once` runs it for the first host of the batch only. ([L10](lessons/L10-compliance-reporting.md#from-per-host-results-to-one-report), [L14](lessons/L14-production-rollout.md#preflight-and-gate-check-before-you-change))
- **diff mode** - `--diff`: shows changes to files line by line. With `--check` it is a preview of the change. ([L00](lessons/L00-lab-and-ansible-basics.md#idempotency-describe-the-state-not-the-steps), [L02](lessons/L02-safe-changes.md#check-mode-what-it-can-and-cannot-predict))
- **drop-in** - A file in a `.d` directory that the main configuration includes (`sshd_config.d`, `sudoers.d`, `sysctl.d`). The order of the files decides which value wins. ([L03](lessons/L03-base-hardening.md#sshd-several-files-one-effective-value))

## E

- **enforce mode** - The run of the role that changes the targets to the described state. It shares its code path with the audit mode. ([L10](lessons/L10-compliance-reporting.md#one-code-path-for-audit-and-enforce))
- **exception** - A documented deviation from a control: a record with control id, reason and expiry date, validated before anything runs. ([L11](lessons/L11-profiles-exceptions-and-data-driven-roles.md#exceptions-are-records-and-input-is-validated-before-anything-runs))

## F

- **facts** - Data Ansible gathers about a host (module `setup`), for example `ansible_facts.os_family`. In the lab the families are `Debian`, `RedHat`, `Suse`, `Alpine` and `Archlinux`. ([L00](lessons/L00-lab-and-ansible-basics.md#facts))
- **faillock** - PAM module (`pam_faillock`) that locks an account after a number of failed logins; settings in `faillock.conf`, the `faillock` command shows and resets the counter. ([L08](lessons/L08-accounts-and-pam.md#two-modules-on-the-stack-pwquality-and-faillock))
- **finding** - The result of one control on one host, kept as data with a status - not a failed task that stops the run. ([L10](lessons/L10-compliance-reporting.md#findings-are-data-not-failures))
- **`first_found`** - Lookup that returns the first existing file from a list - written from the most specific name (distribution) to a generic one. ([L07](lessons/L07-roles-tags-project-structure.md#defaults-and-vars-an-interface-and-internal-data), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.md#platform-data-and-capability-flags))
- **FQCN** - Fully qualified collection name of a module, such as `ansible.builtin.copy`. The `production` profile of ansible-lint demands it. ([L05](lessons/L05-kernel-modules-and-sysctl.md#collections-where-ansibleposixsysctl-comes-from))

## G

- **Galaxy** - Ansible's hub for roles and collections. `ansible-galaxy install -r requirements.yml` installs them; pin a version or a commit. ([L14](lessons/L14-production-rollout.md#community-roles-galaxy-git-and-what-to-read-before-you-run))
- **gate** - A check at the start of a rollout that refuses to go on without an explicit confirmation: a variable without default and an `assert`. ([L14](lessons/L14-production-rollout.md#preflight-and-gate-check-before-you-change))
- **`group_vars` / `host_vars`** - Directories next to the inventory or the playbook; a file named like a group or host sets variables for it. ([L04](lessons/L04-platform-differences-as-data.md#where-variables-come-from))

## H

- **handler** - A task that runs only when a changed task notifies it (`notify`), once, at the end of the play or at `meta: flush_handlers`. ([L02](lessons/L02-safe-changes.md#handlers-act-only-when-something-changed))
- **hook (netfilter)** - A point in the kernel's packet path (`input`, `output`, `forward`, ...) where an nftables chain is attached. ([L13](lessons/L13-host-firewall-nftables.md#who-writes-rules-tables-hooks-and-your-own-table))
- **`hostvars`** - The variables and facts of every host in the inventory, readable from any host - the way to build one report from many hosts. ([L00](lessons/L00-lab-and-ansible-basics.md#facts))

## I

- **idempotency** - Running the same playbook again changes nothing once the state is reached. You describe the state, not the steps. ([L00](lessons/L00-lab-and-ansible-basics.md#idempotency-describe-the-state-not-the-steps))
- **immutable audit configuration** - `-e 2` as the last audit rule locks the rules until the next reboot; nothing can change them, not even root. ([L09](lessons/L09-auditing-and-integrity.md#rule-files-load-order-and-the-lock))
- **`import_tasks` / `include_tasks`** - Static and dynamic inclusion: `import_tasks` is resolved when the playbook is read, `include_tasks` at run time (file name from a variable, in a loop). ([L07](lessons/L07-roles-tags-project-structure.md#import_tasks-and-include_tasks-static-and-dynamic))
- **`include_vars`** - Loads a variables file at run time; its values have a high precedence. ([L07](lessons/L07-roles-tags-project-structure.md#defaults-and-vars-an-interface-and-internal-data), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.md#platform-data-and-capability-flags))
- **interpreter discovery** - How Ansible picks the Python on a target. A host without Python (Alpine before 0.02) can only be reached with `raw`. ([L00](lessons/L00-lab-and-ansible-basics.md#how-a-module-runs))
- **inventory** - The list of hosts and groups Ansible works on. The lab groups its eight targets by family (`debian_family`, `redhat_family`, ...). ([L00](lessons/L00-lab-and-ansible-basics.md#inventory-and-patterns))

## J

- **Jinja2** - The template language of Ansible: `{{ expression }}`, filters such as `| default(...)`, and `{% ... %}` statements. ([L04](lessons/L04-platform-differences-as-data.md#jinja2-in-ansible-expressions-filters-undefined-values))

## L

- **Level 1 / Level 2** - CIS profiles: Level 1 is the practical base with little impact, Level 2 adds defence in depth that may cost function. The lab selects with `cis_level`. ([L01](lessons/L01-cis-benchmarks.md#profiles-and-levels), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.md#a-profile-is-a-value))
- **lint profile** - ansible-lint's rule sets, each extending the previous one: `min`, `basic`, `moderate`, `safety`, `shared`, `production`. ([L07](lessons/L07-roles-tags-project-structure.md#linting-a-role))
- **`login.defs`** - Defaults of the shadow tools for new accounts: password aging (`PASS_MAX_DAYS`, ...) and the hash method (`ENCRYPT_METHOD`). Existing accounts keep their values. ([L08](lessons/L08-accounts-and-pam.md#aging-hashing-and-where-defaults-come-from))
- **loop** - `loop:` repeats a task for every item of a list; `item` is the current element. ([L04](lessons/L04-platform-differences-as-data.md#loops-over-data))

## M

- **management channel** - The way you administer a host - SSH and sudo. A mistake there locks you out, so these changes need the most care. ([L03](lessons/L03-base-hardening.md#sudo-drop-ins-order-and-the-management-channel))
- **`max_fail_percentage`** - Play keyword: ends the run when more than this percentage of the hosts in the current batch has failed. ([L14](lessons/L14-production-rollout.md#failure-semantics-who-stops-when-something-fails))
- **mode (file)** - The permission bits of a file. Write it as a quoted string (`"0644"`): YAML reads `644` as a decimal number. A CIS mode is a maximum - stricter passes. ([L03](lessons/L03-base-hardening.md#modes-bits-notation-and-why-compliance-is-a-bound))
- **`modprobe.d`** - Configuration directories of `modprobe`. `install <module> /bin/false` stops a load by name; kmod reads the files in name order and uses the first `install` line it finds. ([L05](lessons/L05-kernel-modules-and-sysctl.md#kernel-modules-who-loads-them-and-what-modprobed-can-stop))
- **module** - The unit of work: Ansible copies it to the target and runs it with Python (except `raw`), and it reports `ok`, `changed` or `failed`. ([L00](lessons/L00-lab-and-ansible-basics.md#how-a-module-runs))

## N

- **namespaced parameter** - A sysctl key with one copy per namespace (most `net.*` keys): a container can set its own. A global key belongs to the host kernel and is shared. ([L05](lessons/L05-kernel-modules-and-sysctl.md#one-kernel-many-views-namespaced-and-global-parameters))
- **nftables** - The Linux packet filter (`nft`): tables hold chains, chains hold rules. A file loaded with `nft -f` is applied as one transaction - all or nothing. ([L13](lessons/L13-host-firewall-nftables.md#who-writes-rules-tables-hooks-and-your-own-table))
- **`no_log`** - Hides a task's arguments and result from the output. It does not stop a secret that a template writes into a file. ([L12](lessons/L12-secrets-with-ansible-vault.md#no_log-what-it-hides-and-what-it-does-not))

## P

- **PAM** - Pluggable Authentication Modules: per service a stack of modules with a type (`auth`, `account`, `password`, `session`) and a control (`required`, `sufficient`, ...). ([L08](lessons/L08-accounts-and-pam.md#pam-types-controls-and-who-writes-the-stack))
- **pattern** - An expression that selects hosts from the inventory: `targets:!alpine_family` (all but a group), `debian_family:redhat_family` (union). ([L00](lessons/L00-lab-and-ansible-basics.md#inventory-and-patterns))
- **platform data** - Values that differ per platform (package names, paths, groups), kept in data files instead of a `when` at every task. ([L04](lessons/L04-platform-differences-as-data.md#one-task-many-platforms-data-instead-of-conditions), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.md#platform-data-and-capability-flags))
- **preflight** - The first play of a rollout: it only checks what the change needs and fails before anything has changed. ([L14](lessons/L14-production-rollout.md#preflight-and-gate-check-before-you-change))
- **profile (CIS)** - A set of recommendations for one purpose: level (1 or 2) and kind of system (Server or Workstation). In a role a profile is simply a value. ([L01](lessons/L01-cis-benchmarks.md#profiles-and-levels), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.md#a-profile-is-a-value))
- **pwquality** - PAM module (`pam_pwquality`) that checks a new password against rules such as minimum length and character classes; settings in `pwquality.conf`. ([L08](lessons/L08-accounts-and-pam.md#two-modules-on-the-stack-pwquality-and-faillock))

## R

- **`raw`** - Module that sends a command over SSH without Python on the target - for the bootstrap. It cannot tell whether it changed something and is skipped in check mode. ([L00](lessons/L00-lab-and-ansible-basics.md#how-a-module-runs))
- **recommendation (CIS)** - A numbered item of a Benchmark with profile, assessment status, description, rationale, audit and remediation. Numbers can move between Benchmark versions. ([L01](lessons/L01-cis-benchmarks.md#anatomy-of-a-recommendation))
- **`register`** - Stores a task's result in a variable that later tasks use, for example in a `when`. ([L02](lessons/L02-safe-changes.md#conditionals-skip-what-does-not-apply))
- **`requires` (meta.yml)** - Lab: the exercises whose target state an exercise builds on. `lab start` warns when you have not passed them. ([L01](lessons/L01-cis-benchmarks.md#the-lab-catalogue-controlsyml-and-metayml))
- **reset (lab)** - `./lab.sh reset <host|all>` on the host recreates targets in their original, non-compliant state. ([L00](lessons/L00-lab-and-ansible-basics.md#the-lab-one-control-node-eight-targets))
- **role** - A directory with a fixed layout (`tasks/`, `handlers/`, `defaults/`, `vars/`, `templates/`, `files/`, `meta/`) that a play uses as one unit. ([L07](lessons/L07-roles-tags-project-structure.md#a-role-is-a-directory-with-a-contract))

## S

- **salt** - A random value mixed into a password hash so that equal passwords give different hashes. A fixed salt makes `password_hash` idempotent. ([L12](lessons/L12-secrets-with-ansible-vault.md#hashing-a-password-salt-and-idempotency))
- **`serial`** - Play keyword: runs the play in batches - a number, a percentage or a list such as `[1, "50%", "100%"]`. ([L14](lessons/L14-production-rollout.md#batches-batch-lists-and-the-check-after-each-batch))
- **shadow** - `/etc/shadow` holds the password hashes and the aging fields of the accounts; ordinary users may not read it. The hash starts with `$id$`, which names the algorithm. ([L08](lessons/L08-accounts-and-pam.md#account-databases-passwd-shadow-and-what-the-password-field-says))
- **sshd effective value** - sshd reads its main file and drop-ins in order and, for almost every keyword, uses the first value. `sshd -T` prints what is in effect. ([L03](lessons/L03-base-hardening.md#sshd-several-files-one-effective-value))
- **sudoers** - The sudo configuration (`/etc/sudoers` and `sudoers.d`). A broken file can cost you root, so a new one is tested before it is used (`validate`). ([L03](lessons/L03-base-hardening.md#sudo-drop-ins-order-and-the-management-channel))
- **sysctl** - Kernel parameters under `/proc/sys`. The running value is what counts; files in the `sysctl.d` directories set it at boot, in the order of their names. ([L05](lessons/L05-kernel-modules-and-sysctl.md#sysctl-running-value-file-and-the-order-of-files))
- **systemd timer** - A unit that starts a service on a schedule - one of the places jobs run outside of cron. ([L06](lessons/L06-job-schedulers.md#other-places-jobs-hide))

## T

- **tag** - A label on tasks, blocks or roles; `--tags` and `--skip-tags` choose what runs. `always` and `never` are special. ([L07](lessons/L07-roles-tags-project-structure.md#tags-choosing-what-runs))
- **target** - A host Ansible manages (managed node). The lab has eight: debian, ubuntu, rocky, alma, fedora, opensuse, arch, alpine. ([L00](lessons/L00-lab-and-ansible-basics.md#the-lab-one-control-node-eight-targets))
- **template** - `ansible.builtin.template` renders a Jinja2 file with the variables of the host and writes the result to the target. ([L04](lessons/L04-platform-differences-as-data.md#templates-files-rendered-from-variables))
- **`TMOUT`** - Shell variable: an idle interactive shell exits after this many seconds. Set in a profile script, so a non-interactive Ansible task does not see it. ([L08](lessons/L08-accounts-and-pam.md#login-shells-where-umask-and-tmout-live))

## U

- **`umask`** - The mask that removes permission bits from new files. Login shells set it in their profile scripts. ([L08](lessons/L08-accounts-and-pam.md#login-shells-where-umask-and-tmout-live))

## V

- **`validate`** - Parameter of `copy`, `template` and others: a command that tests the new file (`%s`) before it replaces the old one. ([L02](lessons/L02-safe-changes.md#validate-test-the-file-before-it-exists))
- **variable precedence** - The rules for which of several definitions of a variable wins: `-e` beats everything, role defaults lose to every other variable. ([L04](lessons/L04-platform-differences-as-data.md#where-variables-come-from))
- **Vault** - Ansible Vault encrypts files or single values with a password; vault ids tell several passwords apart. ([L12](lessons/L12-secrets-with-ansible-vault.md#vault-files-passwords-ids))

## W

- **`wait_for_connection`** - Waits until a host answers again - after a change that may have broken the connection. ([L13](lessons/L13-host-firewall-nftables.md#a-change-you-may-not-survive-the-dead-man-switch))
- **`when`** - A condition on a task; the task is skipped when it is false. On a looped task it is evaluated per item. ([L02](lessons/L02-safe-changes.md#conditionals-skip-what-does-not-apply))
