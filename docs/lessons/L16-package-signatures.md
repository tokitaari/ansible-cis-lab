# L16 - Package signatures: apt, dnf, zypper, pacman and apk

*[Deutsch](L16-package-signatures.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| 4.10 | 1.2 | ~25 min | L04, L15 |

Every package a target installs arrives over the network, and the signature check is the only
thing that tells the real package from a forged one. All five package managers of the lab check
signatures by default - and all five have a switch that turns the check off, often for one
repository only and without a warning. This lesson explains what each manager signs and checks,
where its switches are, how to ask it for the values in effect, and two Ansible tools for the
clean-up: comparing lists of files and removing a section from an INI file.

## Learning goals

After this lesson you can ...

- [ ] explain what a repository signature proves and which key a manager uses to check it
- [ ] find the global switch and the per-repository switch of apt, dnf, dnf5, zypper, pacman and apk, and say which one wins
- [ ] ask each manager for the values in effect instead of reading its files
- [ ] tell a source bound to its own key (`Signed-By`, `gpgkey`) from one that trusts every key on the host
- [ ] pick per-manager data with `ansible_facts.pkg_mgr`
- [ ] compute "files without a key" with list filters and remove an INI section with `ini_file`

## Theory

### What a signature proves

A repository publishes an index - the list of its packages with their checksums - and signs it,
or signs each package, with a private key. The host holds the matching public key. When the
signature over the index checks out, every checksum in it is trusted, and so is every package that
matches its checksum. When the packages are signed themselves, each one is checked on its own.
Either way the chain ends at a public key on the host, so two questions matter for every
repository: is the check on, and *which* keys does the host accept for it?

A key that the host accepts for every repository is a wide door: whoever holds the private key
can sign packages for any source. A key bound to one repository only signs for that repository.
The managers differ exactly here.

| Manager | What is signed | Where the public keys are | Bound to one repository? |
|---|---|---|---|
| apt | the release file (`InRelease`) with the checksums of the indexes | the file named by `Signed-By`, else every key in `/etc/apt/trusted.gpg.d/` | yes, with `Signed-By` |
| dnf, dnf5, zypper | each package (rpm), optionally the metadata (`repomd.xml`) | the rpm key database, imported from `gpgkey=` | the repository names its key, but rpm trusts every imported key |
| pacman | each package; databases optional | the pacman keyring (`pacman-key`) | no |
| apk | the index (`APKINDEX.tar.gz`) and each package | `/etc/apk/keys` | no |

### apt: signed release files and `Signed-By`

The sources of debian and ubuntu are deb822 files, one stanza per group of suites:

```bash
ansible debian -m ansible.builtin.command -a "cat /etc/apt/sources.list.d/debian.sources"
```

Each stanza ends with `Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp`: apt accepts
only that key for these suites. The one-line format says the same with an option,
`deb [signed-by=/path/key.gpg] http://... suite main`. A source without `Signed-By` falls back to
every key in `/etc/apt/trusted.gpg.d/`, and that directory is not empty: the lab measured nine
Debian archive keys on debian and two Ubuntu keys on ubuntu. For a third-party repository the key
belongs in `/etc/apt/keyrings/` and the source names it; `ansible.builtin.deb822_repository` writes
such a source with its `signed_by` parameter. The old way, `apt-key` and `ansible.builtin.apt_key`,
puts the key into the shared keyring and is deprecated.

Two kinds of switch turn the check off. Per source, `trusted=yes` (one-line) or `Trusted: yes`
(deb822) makes apt accept the source unsigned. Globally, options in `/etc/apt/apt.conf.d/` such
as `Acquire::AllowInsecureRepositories` let unsigned repositories through. `apt-config dump` prints
the merged configuration:

```bash
ansible debian,ubuntu -m ansible.builtin.shell -a "apt-config dump | grep -E 'Allow(Insecure|Weak|DowngradeToInsecure)Repositories|AllowUnauthenticated'"
```

On a fresh target the three `Acquire::Allow...` options are `"0"` and `AllowUnauthenticated` does
not appear. The difference between the switches is how loud they are. Measured with a small
unsigned repository: without a switch, `apt-get update` failed with exit code 100 and "The
repository ... is not signed"; with `Acquire::AllowInsecureRepositories "true"` it printed that
line as a warning (`W:`) and exited 0; with `trusted=yes` it said nothing at all - only an
`Ign: ... Release.gpg` line hints that no signature was looked for. A clean `apt-get update` does
not prove that every source was checked; the sources do. debian 13 (apt 3.0) checks with `sqv`,
ubuntu 26.04 (apt 3.2) with `gpgv`; the result is the same.

### dnf and dnf5: `gpgcheck` in two places

dnf reads `[main]` of `/etc/dnf/dnf.conf` and one section per repository from
`/etc/yum.repos.d/*.repo`. `gpgcheck` (dnf5 calls it `pkg_gpgcheck` and keeps `gpgcheck` as an
alias) switches the package check, `repo_gpgcheck` the check of the metadata, `localpkg_gpgcheck`
the check of a package file installed from disk. `gpgkey=` names the key of a repository; dnf
imports it into the rpm database when it first needs it. In the lab images the keys were already
imported (`rpm -q gpg-pubkey`).

A value in a repository section wins over `[main]`. Measured on rocky and alma: with
`gpgcheck=0` in `[main]`, every repository still reported `gpgcheck` on, because each of them sets
`gpgcheck=1` itself; a repository with `gpgcheck=0` is unchecked whatever `[main]` says. And a
default needs no line: fedora's `dnf.conf` holds only `tsflags=nodocs`, yet the check is on. The
manager tells you what is in effect. dnf5 has dump options:

```bash
ansible fedora -m ansible.builtin.shell -a "dnf5 --dump-main-config | grep gpgcheck"
```

They print `gpgcheck = 1`, `pkg_gpgcheck = 1`, `repo_gpgcheck = 0` and `localpkg_gpgcheck = 0`
(and `gpgcheck_policy`); `dnf5 --dump-repo-config='*'` does the same per repository, one block
per repository, headed by its id. dnf 4 on rocky and alma has no such option without a plugin
(`dnf config-manager --dump` answered on alma, not on rocky), but its Python API is installed:

```bash
ansible rocky -m ansible.builtin.command -a "python3 -c 'import dnf; b = dnf.Base(); b.conf.read(); print(b.conf.gpgcheck, b.conf.repo_gpgcheck, b.conf.localpkg_gpgcheck)'"
```

`True False False`: packages are checked, metadata and local files are not. Note one more
difference between the two: an enabled repository whose metadata cannot be fetched stops `dnf
makecache` on rocky (`skip_if_unavailable=False`) and is skipped on fedora (`skip_if_unavailable
= 1`).

### zypper: three switches and a service

zypper uses the same rpm key database and the same three ideas: `gpgcheck`, `repo_gpgcheck`,
`pkg_gpgcheck`, in `[main]` of `/etc/zypp/zypp.conf` and per repository in
`/etc/zypp/repos.d/*.repo`. On opensuse the files set none of them - the defaults apply - and the
vendor repositories are generated by a service (`service=openSUSE`, defined in
`/etc/zypp/services.d/`). `zypper --xmlout lr` lists each repository with the values in effect;
`raw_gpgcheck` appears only where a file sets the value itself:

```bash
ansible opensuse -b -m ansible.builtin.shell -a "zypper -n --xmlout lr | grep 'repo-oss (16.0)'"
ansible opensuse -b -m ansible.builtin.command -a "zypper -n refresh"
ansible opensuse -b -m ansible.builtin.shell -a "zypper -n --xmlout lr | grep 'repo-oss (16.0)'"
```

Run on a fresh target, the first line shows `gpgcheck="1" repo_gpgcheck="1" pkg_gpgcheck="1"`, the
second (after the refresh) `pkg_gpgcheck="0"`. Nothing was switched off: when `pkg_gpgcheck` is not
set, libzypp checks package signatures only while the metadata are not validly signed, because
signed metadata already carry the checksums of the packages. "On" for zypper therefore means
`gpgcheck` and `repo_gpgcheck`.

### pacman: `SigLevel` and one keyring

pacman's `/etc/pacman.conf` has an `[options]` section and one section per repository. `SigLevel`
takes words: `Required`, `Optional` or `Never` for the strength, `TrustedOnly` or `TrustAll` for
which keys count, each optionally prefixed with `Package` or `Database`. Arch sets `SigLevel =
Required DatabaseOptional`: every package must be signed by a trusted key, the databases need not
be (Arch does not sign them). `LocalFileSigLevel = Optional` applies to `pacman -U` with a file.
`pacman-conf` prints the values in effect:

```bash
ansible arch -m ansible.builtin.command -a "pacman-conf SigLevel"
ansible arch -m ansible.builtin.command -a "pacman-conf -r core SigLevel"
```

The first prints `PackageRequired PackageTrustedOnly DatabaseOptional DatabaseTrustedOnly`, the
second nothing: `-r` shows only what a repository section sets itself, and `[core]` sets nothing,
so the global value applies. A repository section with its own `SigLevel = Optional TrustAll`
lowers the check for that repository alone. The keys live in one keyring under
`/etc/pacman.d/gnupg` (183 public keys in the lab image, from `archlinux-keyring`), shared by all
repositories. Because the databases are not signed, `pacman -Sy` proves nothing about signatures -
and `-Sy` without `-u` is the classic way to a partial upgrade.

### apk: signed indexes and a global options file

apk checks the signature of every repository index against the keys in `/etc/apk/keys` (three in
the lab image, owned by the package `alpine-keys`) and of every package. apk-tools 3 also reads
global options from `/etc/apk/config`, one long option per line - `allow-untrusted` there accepts
unsigned indexes and packages for every command, not only for one `apk add --allow-untrusted`.
Only the first file of `/etc/apk/config` and `/lib/apk/config` that exists is read (apk(8)).

```bash
ansible alpine -m ansible.builtin.command -a "apk --version"
ansible alpine -m ansible.builtin.shell -a "ls /etc/apk/keys; cat /etc/apk/repositories"
```

A repository whose index fails the check does not stop apk: measured with an unsigned local index,
`apk update` printed `WARNING: opening ...: UNTRUSTED signature`, dropped that repository and
exited 0. Read the output, not only the exit code.

### One question, six answers: data by `pkg_mgr`

L04 chose platform data by `os_family`. For signatures the better key is the fact `pkg_mgr`,
because the manager decides the files and commands - and fedora (`dnf5`) differs from rocky and
alma (`dnf`) although all three are `RedHat`:

```bash
ansible targets -m ansible.builtin.setup -a 'gather_subset=min filter=ansible_pkg_mgr'
```

It prints `apt` for debian and ubuntu, `dnf` for rocky and alma, `dnf5` for fedora, `zypper`,
`pacman` and `apk` for the others. A dict keyed by this value, guarded by an `assert`, works as in
L15: a new manager stops the play instead of skipping every block.

### Comparing lists and editing INI sections

Two helpers do most of the clean-up work in this area. The list filters `difference`, `union`
and `intersect` compare lists, for example the paths that two `find` runs returned. And
`community.general.ini_file` edits one option, or one whole section, of an INI file - the format
of `dnf.conf`, `zypp.conf`, the `.repo` files and `pacman.conf`. A small demo on the control node:

```yaml
- name: List filters and INI sections
  hosts: localhost
  gather_facts: false
  vars:
    all_files: [/tmp/a.conf, /tmp/b.conf, /tmp/c.conf]
    signed_files: [/tmp/a.conf, /tmp/c.conf]
  tasks:
    - name: In the first list, not in the second
      ansible.builtin.debug:
        msg: "{{ all_files | difference(signed_files) }}"

    - name: A scratch INI file with a section
      community.general.ini_file:
        path: /tmp/l16-demo.ini
        section: demo
        option: enabled
        value: "1"
        no_extra_spaces: true
        mode: "0644"

    - name: The whole section goes
      community.general.ini_file:
        path: /tmp/l16-demo.ini
        section: demo
        state: absent
        create: false
```

The first task prints a list with `/tmp/b.conf` only. The second writes `[demo]` and `enabled=1` (without the
spaces around `=`, the style of `dnf.conf`), the third removes the header and every line up to
the next header. The demo is not idempotent on purpose: each run adds the section and removes it
again. With only `section:` and `state: absent`, `ini_file` removes the whole section; with
`option:` as well, only that line. `create: false` keeps it from creating a missing file.

One detail of `ansible.builtin.find` matters for such lists: `contains:` is matched with
`re.match` against each line, that is from the start of the line. A pattern that may stand in the
middle of a line needs a leading `.*`.

## CIS background

Section 1.2 of the benchmarks covers package management ([the control
catalogue](../../cis-catalogue/controls.yml): 1.2, Level 1). In our own words, the
recommendations want: the signing keys of the package manager configured and known; the
signature check switched on globally, and not off for any repository; only repositories
configured that the organisation trusts; and updates applied. The key and repository items are
often *manual*: a tool can list keys and sources, but only you know which ones belong there. The
automated items read the configuration files - an audit typically greps `gpgcheck` in
`dnf.conf` and in every `.repo` file, so a default that is on but not written down can still fail
it. Some benchmarks list the metadata check (`repo_gpgcheck`) separately.

The threat is a forged package: from a compromised mirror, a man in the middle on a plain-HTTP
mirror, or an "internal mirror" that someone added in a hurry. A signature check closes all
three, but only for repositories whose key is right; a key trusted for every source widens the
door again. The trade-offs are small - a signed internal repository costs a key and a signing step
in its build - which is why the benchmarks ask for the check without exceptions.

## Platform differences

| os_family | Hosts | `pkg_mgr` | Global switch | Per-repository switch | Keys | Values in effect |
|---|---|---|---|---|---|---|
| Debian | debian, ubuntu | `apt` | `Acquire::Allow...`, `APT::Get::AllowUnauthenticated` in `apt.conf.d` | `trusted=yes`, `allow-insecure=yes` | `Signed-By` file; else `trusted.gpg.d` (9 / 2 keys) | `apt-config dump`; the sources |
| RedHat | rocky, alma / fedora | `dnf` / `dnf5` | `gpgcheck` in `[main]` (fedora: no line, on by default) | `gpgcheck=` per repository | `gpgkey=`, rpm database (imported) | dnf Python API / `dnf5 --dump-*-config` |
| Suse | opensuse | `zypper` | `gpgcheck` in `[main]` of `zypp.conf` (not set) | `gpgcheck=` per repository (not set) | `gpgkey=`, rpm database (6 keys) | `zypper --xmlout lr` |
| Alpine | alpine | `apk` | `allow-untrusted` in `/etc/apk/config` | - | `/etc/apk/keys` (3, `alpine-keys`) | the files; `apk update` output |
| Archlinux | arch | `pacman` | `SigLevel` in `[options]` | `SigLevel` per section | `/etc/pacman.d/gnupg` (183 keys) | `pacman-conf` |

Versions measured: apt 3.0.4 (debian 13) and 3.2.1 (ubuntu 26.04); dnf 4.20 with rpm 4.19 (rocky,
alma 10.3); dnf5 5.4.6 with rpm 6.0.2 (fedora 44); zypper 1.14.101 with rpm 4.20 (Leap 16.0);
pacman 7.1; apk-tools 3.0.9 (Alpine 3.24).

### In the lab containers

Signatures behave as on a virtual machine; nothing here depends on the host kernel. Each image
comes with an "internal mirror" that a previous admin trusted without a key - a local, empty
repository in `/opt/lab/legacy-repo`, so that removing it breaks nothing and nothing can ever be
installed from it: an apt source with `trusted=yes`, a disabled dnf and zypper repository with
`gpgcheck=0` and no key, a pacman section with `SigLevel = Optional TrustAll`, and an apk
repository line plus `allow-untrusted` in `/etc/apk/config`. `./lab.sh reset` brings it back. A
refresh needs the network, as every package installation in the lab does.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `apt-get update` is clean, yet a source is unchecked | `trusted=yes` switches the check off silently | read the sources, not the update output |
| `gpgcheck=0` in `[main]`, every repository still checks (or the other way round) | the repository value wins | check and set both levels |
| An audit fails on fedora, the check is on | the default needs no line; the audit reads the file | write `gpgcheck=1` into `[main]` |
| zypper shows `pkg_gpgcheck="0"` after a refresh | unset, it follows the metadata signature | judge zypper by `gpgcheck` and `repo_gpgcheck` |
| `pacman-conf -r core SigLevel` prints nothing | `-r` shows only the section's own value | fall back to the global `SigLevel` |
| `apk update` exits 0 with `UNTRUSTED signature` | apk drops the repository and continues | look at the output |
| `find` with `contains: signed-by=` finds nothing | `re.match` from the start of the line | `.*signed-by=` |
| A third-party key in `trusted.gpg.d` | it is trusted for every source | `/etc/apt/keyrings/` + `Signed-By` |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [4.10](../../exercises/stage4-advanced/4.10-package-signatures/README.md) | the switches and key locations of the five managers, the views in effect, data by `pkg_mgr`, list filters, `ini_file` sections |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. A source line reads `deb [trusted=yes] http://mirror.example/debian trixie main`, and
   `apt-get update` runs without a single warning. Is the repository checked?

   <details><summary>Answer</summary>

   No. `trusted=yes` tells apt to accept the source without a valid signature, and apt does not
   warn about it; only an `Ign: ... Release.gpg` line hints at it. A global
   `Acquire::AllowInsecureRepositories` would at least print a `W:` line. The way to know is to
   read the sources (or `apt-config dump` for the global options), not the update output.

   </details>

2. Why is a source with `Signed-By` safer than the same source without it, even if both are
   signed by the right key?

   <details><summary>Answer</summary>

   Without `Signed-By` apt accepts a signature by any key in `/etc/apt/trusted.gpg.d/`. Whoever
   holds the private key of any of them can then sign packages for this source too. With
   `Signed-By` only the named key counts for the source, and a third-party key added for one
   repository cannot sign for the others.

   </details>

3. On rocky, `[main]` of `dnf.conf` says `gpgcheck=1`. A repository file says `gpgcheck=0`. Which
   value is in effect for that repository, and how do you find out without reading the files?

   <details><summary>Answer</summary>

   `gpgcheck=0`: the repository value wins over `[main]`. dnf itself tells you - with its Python
   API on dnf 4 (the repository's `gpgcheck` attribute) or with `dnf5 --dump-repo-config` on
   dnf5. That is why a hardening play has to look at both levels.

   </details>

4. On opensuse a script reports "package signature check off" for every repository right after
   a `zypper refresh`. What is going on?

   <details><summary>Answer</summary>

   The script reads `pkg_gpgcheck`. When it is not set, libzypp checks package signatures only
   while the repository metadata are not validly signed; after a refresh the metadata are signed
   and carry the package checksums, so `pkg_gpgcheck` reads `0`. Nothing is switched off. The
   values that say whether zypper checks are `gpgcheck` and `repo_gpgcheck`.

   </details>

5. Why does it help to key the data of a signature play by `pkg_mgr` and not by `os_family`?

   <details><summary>Answer</summary>

   The manager decides the files, the option names and the commands that show the values in
   effect. fedora is `RedHat` like rocky and alma but uses dnf5, whose dump options and Python
   library differ from dnf 4. Keyed by `pkg_mgr`, each value of the dict matches one tool, and an
   `assert` stops a host with a manager the data does not know.

   </details>

## Further reading

- [sources.list(5)](https://manpages.debian.org/trixie/apt/sources.list.5.en.html) - one-line and deb822 format, `Signed-By`, `Trusted`
- [apt-secure(8)](https://manpages.debian.org/trixie/apt/apt-secure.8.en.html) - how apt verifies a repository and what the `Allow...` options do
- [dnf.conf (dnf 4)](https://dnf.readthedocs.io/en/latest/conf_ref.html) - `gpgcheck`, `repo_gpgcheck`, `localpkg_gpgcheck`, `gpgkey`, `skip_if_unavailable`
- [dnf5.conf(5)](https://dnf5.readthedocs.io/en/latest/dnf5.conf.5.html) - `pkg_gpgcheck` and its alias `gpgcheck`
- [zypp.conf(5) (libzypp)](https://github.com/openSUSE/libzypp/blob/master/zypp/doc/zypp.conf.5.txt) - `gpgcheck`, `repo_gpgcheck`, `pkg_gpgcheck` and how the unset values follow `gpgcheck`
- [pacman.conf(5)](https://man.archlinux.org/man/pacman.conf.5) - `SigLevel`, `LocalFileSigLevel`, repository sections
- [Pacman/Package signing](https://wiki.archlinux.org/title/Pacman/Package_signing) - the keyring and `pacman-key`
- [apk(8)](https://man.archlinux.org/man/apk.8) - `--allow-untrusted`, `/etc/apk/config`, the key directories
- [`ansible.builtin.deb822_repository`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/deb822_repository_module.html) - a source with `signed_by`
- [`community.general.ini_file`](https://docs.ansible.com/projects/ansible/latest/collections/community/general/ini_file_module.html) - options and sections, `state: absent`
- [Filters: set theory](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_filters.html#selecting-from-sets-or-lists-set-theory) - `difference`, `union`, `intersect`
- [Glossary](../GLOSSARY.md) - terms of this lesson: `gpgcheck`, keyring, `pkg_gpgcheck`, `SigLevel`,
  `Signed-By`, `trusted=yes`
