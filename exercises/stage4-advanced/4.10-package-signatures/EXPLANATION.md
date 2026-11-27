# 4.10 - Package signatures: every repository verified, no bypass: Explanation

### What the check verifies
`lab check 4.10` runs `check.yml` on all eight targets and then your playbook once more with
`--check`, expecting `changed=0` (`meta.yml` says `idempotency: true`). Per `pkg_mgr` it reads
what the manager itself reports:

- **apt:** `apt-config dump` has none of `Acquire::AllowInsecureRepositories`,
  `Acquire::AllowWeakRepositories`, `Acquire::AllowDowngradeToInsecureRepositories` and
  `APT::Get::AllowUnauthenticated` set to true; an `awk` program walks `sources.list` and every
  `*.list` and `*.sources` file and prints one line per entry (one-line) or stanza (deb822) - each
  must name `Signed-By` and carry no `trusted`, `allow-insecure`, `allow-weak` or
  `allow-downgrade-to-insecure` option.
- **dnf, dnf5:** a few lines of Python ask the dnf API (dnf4) or libdnf5 for the values in effect:
  `gpgcheck` of the main section and, for every repository, its `gpgcheck` and whether it names a
  `gpgkey`. All must be on.
- **dnf, dnf5, zypper:** a `gpgcheck=1` line (also `yes`, `true`, `on`) in `dnf.conf` or
  `zypp.conf`.
- **zypper:** `zypper --xmlout lr` lists every repository with `gpgcheck="1"`,
  `repo_gpgcheck="1"` and a non-empty `gpgkey`.
- **pacman:** for every repository its own `SigLevel` from `pacman-conf -r`, or the global one
  when it sets none, must contain `PackageRequired` and not `PackageTrustAll`.
- **apk:** no `allow-untrusted` line in `/etc/apk/config` or `/lib/apk/config`, and every
  repository line is an `https://` URL.
- **refresh** (apt, dnf, dnf5, zypper, apk): `apt-get update`, `dnf -y makecache`, `zypper -n
  refresh`, `apk update` exit 0 and print none of `is not signed`, `NO_PUBKEY`, `UNTRUSTED`,
  `BADSIG`, `EXPKEYSIG`.

It does not test that the data lives in a dict or that an `assert` guards it, that the key a
source names exists or is the right one (only the refresh notices a missing one), in which
section of the main file the `gpgcheck` line stands, `localpkg_gpgcheck` or `LocalFileSigLevel`,
who owns the keys in `/etc/apk/keys`, or that you *removed* the legacy repository - giving it a
real key passes too. Measured with the reference solution: the check fails on all eight hosts of
a fresh lab (after 0.02); the first run changes 3 tasks on fedora, opensuse and alpine, 2 on
debian, ubuntu, rocky and alma, 1 on arch; the second run and `--check` change nothing; the whole
runner job (`tools/run-solutions.sh 4.10`: reset, 0.02, solve, check, second run) took 122 s.

### How it works

#### "Has no key" is a set difference
```yaml
loop: >-
  {{ (cis_repo_all.files | map(attribute='path'))
     | difference(cis_repo_keyed.files | map(attribute='path')) | sort }}
```
Two `find` runs over the same directory, one with `contains:` for a key line, give two lists of
paths; what is in the first and not in the second has no key and goes. apt adds a third list with
`| union(...)`: a source that names a key *and* says `trusted=yes` is still a bypass. `contains:`
is applied with `re.match` to every line, so a pattern that may stand in the middle of a line
starts with `.*` (`(?i)(.*signed-by=|signed-by:)` covers the one-line and the deb822 form). The
lists are sorted so that the loop order, and the output, stay the same from run to run.

#### The repository value wins
Setting `gpgcheck=0` in `[main]` of `dnf.conf` changed none of the rocky and alma repositories:
each sets `gpgcheck=1` itself, and the dnf API still reported `True` for every one. The other
way round, a repository with `gpgcheck=0` is unchecked whatever `[main]` says. That is why the
check asks for both, and why the solution turns the repository lines on with `replace` in every
file that has a key. On fedora `dnf.conf` holds only `[main]` and `tsflags=nodocs`; the check is
on by default (`dnf5 --dump-main-config`: `gpgcheck = 1`, `pkg_gpgcheck = 1`), but an audit that
reads the file finds nothing, so the line is written explicitly.

#### The value in effect is the manager's answer
None of the managers needs you to parse its files: dnf4 has its Python API (`dnf config-manager
--dump` answered on alma, not on rocky), dnf5 has `--dump-main-config` and
`--dump-repo-config`, zypper `--xmlout lr`, pacman `pacman-conf`. Two answers need reading with
care. `pacman-conf -r core SigLevel` printed nothing: it shows only what a section sets, and a
section without `SigLevel` uses the global one. zypper's `pkg_gpgcheck` changed from `1` to `0`
after the first `zypper ref` on the same repositories: when it is not set, libzypp checks package
signatures only as long as the metadata are not validly signed - signed metadata carry the
checksums of the packages. The check therefore requires `gpgcheck` and `repo_gpgcheck`, not
`pkg_gpgcheck`.

#### Removing an INI section
`community.general.ini_file` with only `section:` and `state: absent` deletes the header and every
line up to the next header, comments included; `pacman.conf` with two `[options]` sections was
no problem (measured in the session and on arch). `create: false` keeps the module from creating a
missing file and satisfies `ansible-lint`'s `risky-file-permissions`.

### Per-family notes
| `pkg_mgr` | Hosts | Planted | Solution changes | Notes |
|---|---|---|---|---|
| `apt` | debian, ubuntu | `lab-legacy.list` with `[trusted=yes]` | removes it, `apt-get update` | debian apt 3.0.4 verifies with `sqv`, ubuntu apt 3.2.1 with `gpgv`; 9 / 2 archive keys in `trusted.gpg.d` |
| `dnf` | rocky, alma | disabled `lab-legacy` repo, `gpgcheck=0`, no key | removes it, `dnf makecache` | dnf 4.20; `skip_if_unavailable=False` |
| `dnf5` | fedora | the same; no `gpgcheck` line in `dnf.conf` | `gpgcheck=1` in `[main]`, removes the repo, refresh | dnf5 5.4.6, rpm 6.0; `skip_if_unavailable = 1` |
| `zypper` | opensuse | the same in `/etc/zypp/repos.d/` | `gpgcheck=1` in `zypp.conf`, removes the repo, `zypper ref` | the vendor repositories come from the service `openSUSE` |
| `pacman` | arch | `[lab-legacy]` with `SigLevel = Optional TrustAll` | removes the section | `SigLevel = Required DatabaseOptional` |
| `apk` | alpine | legacy repository line, `allow-untrusted` in `/etc/apk/config` | removes both lines, `apk update` | apk-tools 3.0.9 |

The rpm keys were already imported in all four rpm images (`rpm -q gpg-pubkey`: rocky 2, alma 1,
fedora 1, opensuse 6). A disabled repository with `gpgcheck=0` changes nothing at install time,
but the CIS audit reads every repository file, enabled or not.

### Pitfalls and measured facts

| Symptom | Cause | Fix |
|---|---|---|
| `apt-get update` is silent about the legacy mirror | `trusted=yes` and `Trusted: yes` switch the check off without a warning (only `Ign: ... Release.gpg`) | read the sources; remove the entry |
| An unsigned source fails with rc 100 "is not signed" | the check works - until `Acquire::AllowInsecureRepositories "true"`, which turns it into a `W:` line and rc 0 | no global bypass in `apt.conf.d` |
| `gpgcheck=0` in `[main]`, every repository still checks | the repository value wins | check and set both levels |
| `find` with `contains: signed-by=` finds nothing | `re.match` from the line start | `.*signed-by=` |
| zypper `pkg_gpgcheck="0"` after a refresh | unset, it follows the metadata signature | require `gpgcheck` + `repo_gpgcheck` |
| `pacman-conf -r core SigLevel` is empty | it prints only the section's own value | fall back to `pacman-conf SigLevel` |
| `apk update` exits 0 with `UNTRUSTED signature` | apk drops the repository and goes on | grep the output, not only the exit code |
| An enabled repository without metadata: `dnf makecache` rc 1 on rocky, rc 0 on fedora | `skip_if_unavailable` False (el10) / 1 (fedora) | do not rely on errors; read the configuration |
| `pacman -Sy` with a scratch `--dbpath` from `mktemp -d`: "Permission denied" | pacman 7 downloads as the user `alpm`, the directory is 0700 | no refresh on pacman (its databases are not signed) |
| `package_facts` fails on arch: "Could not detect a supported package manager" | a repository section without a sync database makes every pacman command warn on stderr, and the module gives up on any stderr of `pacman -Qi` (CI, first image of this exercise) | the image ships the database of `[lab-legacy]`; on a real host run `pacman -Sy` once or remove the section |
| A `/etc/apk/config` emptied by `lineinfile` stays | the module removes lines, not the file; apk reads only the first config file that exists (apk(8)), so it hides `/lib/apk/config` | harmless in the lab; delete it if it is empty |

`gpgcheck=0` written into a repository file of the zypper service survived `zypper refs`: the
service did not rewrite the file while the service itself was unchanged.

### Real-world notes
- A refresh proves the metadata signature only where the metadata are signed and checked: apt
  (InRelease), zypper (`repo_gpgcheck`) and apk (signed index). dnf with `repo_gpgcheck=0` and
  pacman with `DatabaseOptional` verify each package at install time instead.
- Bind a third-party key to its source (`Signed-By` in `/etc/apt/keyrings/`, `gpgkey=` per
  repository). A key in `/etc/apt/trusted.gpg.d/` is trusted for every source; `apt-key` and
  `ansible.builtin.apt_key` are deprecated for this reason.
- "Removed" is the safe answer for an internal mirror without a key. The real fix is to sign it
  (a repository key of your own) and distribute that key with the same automation.
- Signatures say who built a package, not that it is free of bugs: keep the updates coming
  (the benchmarks list that next to the signature items, as a manual one).

### Further reading
- Lesson [L16 - Package signatures](../../../docs/lessons/L16-package-signatures.md): the chain of trust per manager, global and per-repository switches, the views in effect - the concepts before this exercise.
- Exercise [4.09 - System logging](../4.09-system-logging/README.md): the same "value in effect" question for journald and rsyslog.

## Reference solution

Show it with `lab solution 4.10`, apply it with `lab solve 4.10`.
