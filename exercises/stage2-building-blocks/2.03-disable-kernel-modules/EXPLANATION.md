# 2.03 - Disable unneeded kernel modules: Explanation

### What the check verifies
`lab check 2.03` runs `check.yml` on `targets`: for each of the six Level 1 modules it reads
`/etc/modprobe.d/cis-<module>.conf` and asserts a line `install <module> /bin/false` (or
`/usr/bin/false`) and a line `blacklist <module>`. Then it runs your playbook once more with
`--check` and expects `changed=0`.

- File names are fixed, with the README spelling: `cis-usb-storage.conf`, not `cis-usb_storage.conf`.
- Nothing may follow `/bin/false` on the line: a trailing `# comment` fails, `/bin/true` (used by
  older benchmark versions) fails too.
- Owner, mode, extra lines and the Level 2 list are not tested, also not with `-e cis_level=2`.
- It reads files, it does not ask `modprobe` which rule **applies**. On opensuse five of the six
  rules are overridden by vendor rules, and the check still passes (measured, see below).

### How it works

#### One file per module
`copy` with `loop` writes one file per list item; `content: |` gives the two lines and a final
newline. Measured: the reference solution reports `changed=1` per host in the first run (the
looped `copy`; `/etc/modprobe.d` exists on all eight hosts, so the directory task is `ok`) and
`changed=0` in the second; the unload task is skipped (`lab_in_container`). One file per module
makes an exception cheap - delete one file - and keeps diffs readable.

#### `install` and `blacklist`
`install <module> /bin/false` replaces the load by a command that fails, for every `modprobe` of
that name. `blacklist` only stops loading through the module's aliases; a plain `modprobe <name>`
ignores it unless called with `-b`. Lesson L05 shows both with `modprobe -n -v`. Measured on the
kmod hosts after the solution: `modprobe -n -v cramfs` prints `install /bin/false` (except on
opensuse, below).

#### Dash and underscore
The kernel module is called `usb_storage`. kmod treats `-` and `_` as the same character, so
`install usb-storage /bin/false` covers it: `modprobe -n -v usb_storage` and `usb-storage` both
print the rule (measured on all seven kmod hosts), and `modprobe -c` lists it as `usb_storage` (session test).

#### The first `install` line wins
kmod merges `/etc/modprobe.d`, `/run/modprobe.d` and `/usr/lib/modprobe.d` and reads the files in
the order of their **names**; a file in `/etc` replaces one of the same name in `/usr/lib`. For
`install` the first line found counts. openSUSE ships `60-blacklist_fs-<fs>.conf` for many file
systems, among them `cramfs`, `freevxfs`, `hfs`, `hfsplus` and `jffs2`, each with
`install <fs> /usr/lib/module-init-tools/unblacklist <fs>; /sbin/modprobe --ignore-install <fs>`.
`60-...` sorts before `cis-...`, so after the reference solution opensuse still prints the
vendor command for those five; only `usb-storage` has no vendor file there. Measured: the same
rules in `/etc/modprobe.d/00-...conf` win on opensuse; on the other six kmod hosts no vendor file
names the six modules, and both names give the same result.

#### Alpine: BusyBox ignores `install`
`/sbin/modprobe` on alpine is BusyBox 1.37.0. Its configuration parser knows only `alias`,
`options`, `include` and `blacklist` (BusyBox source; a test with BusyBox 1.36.1 confirms it):
the `install` line is ignored, a plain `modprobe cramfs` would try to load the module, and
`blacklist` holds for the plain name only with `-b`. BusyBox also has no `-n`, so there is no dry
run to verify the rule.

#### What the container cannot show
The lab kernel is the host's (a WSL2 kernel in the measurement), and the targets have no module
directory: before the rule, `modprobe -n -v cramfs` ends with `Module cramfs not found in
directory /lib/modules/...`. When the kernel itself needs a module - mounting a file system type,
opening a socket of an unusual protocol - it starts `/sbin/modprobe` in the host's namespaces, so
it reads the **host's** `modprobe.d`, never the container's. In the lab the six files are
configuration that a real host would use. That is why the solution's unload task
(`community.general.modprobe`, `state: absent`) only runs with `lab_in_container: false`.

#### Level 2 (bonus)
`squashfs` is Level 2 because snaps and many live and installer images need it. `dccp`, `tipc`,
`rds` and `sctp` had vulnerabilities reachable by unprivileged users, but some telecom software
relies on SCTP. That is what the profile split is for.

### Per-family notes
| os_family | `/sbin/modprobe` | `/bin/false` resolves to | Vendor rules for the six modules | `modprobe -n -v cramfs` after the solution |
|---|---|---|---|---|
| Debian | kmod 34.2 | `/usr/bin/false`; ubuntu: Rust coreutils (`/usr/lib/cargo/bin/coreutils/false`) | none | `install /bin/false` |
| RedHat | kmod 31 (rocky, alma), 34.2 (fedora) | `/usr/bin/false` | none | `install /bin/false` |
| Suse | kmod 34.2 | `/usr/bin/false` | `60-blacklist_fs-*.conf` for five of them | the vendor command |
| Alpine | BusyBox 1.37.0 | BusyBox | not measured (BusyBox ignores `install`) | no dry run in BusyBox |
| Archlinux | kmod 34.3 | `/usr/bin/false` | none | `install /bin/false` |

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| The check fails, the file looks right | trailing comment, `/bin/true`, or `cis-usb_storage.conf` | exactly the two lines, the README file names |
| `modprobe -n -v` prints another `install` command | an earlier-sorted vendor file (opensuse) | a lower-sorting name such as `00-...`, or the vendor's file name in `/etc` |
| `Module cramfs not found in directory /lib/modules/...` | no module directory in the container, no rule yet | expected; after the rule the dry run prints `install ...` |
| `Error running install command '/bin/false'` | the rule works; you ran a real `modprobe` | read the rule with `modprobe -n -v`, do not load to test |
| `modprobe -n` fails on alpine | BusyBox has no `-n` | read the file; BusyBox does not enforce `install` anyway |
| A module unloaded on your PC | `modprobe -r` or `rmmod` in a target | never in the lab; guard with `lab_in_container` |

### Real-world notes
- Verify what applies, not what you wrote: `modprobe -n -v <module>` on every platform with kmod.
  A scanner that only greps your file misses an earlier vendor rule.
- A rule stops new loads. On a real host also unload loaded modules and rebuild the initramfs,
  which holds its own copy of `modprobe.d` (L05).
- Check which `modprobe` your hosts run (`readlink -f /sbin/modprobe`) before you rely on
  `install`.

### Further reading
- Lesson [L05 - Kernel hardening](../../../docs/lessons/L05-kernel-modules-and-sysctl.md): `install`, `blacklist`, dry runs, container limits.
- Exercise [2.04 - Kernel parameters: network hardening via sysctl](../2.04-sysctl-network/README.md)
- Exercise [3.01 - Refactor everything into a role](../../stage3-intermediate/3.01-build-the-cis-role/README.md)
- [Container limits](../../../docs/CONTAINER_LIMITS.md)
- [`modprobe.d(5)`](https://man.archlinux.org/man/modprobe.d.5) - `install`, `blacklist` and the other keywords

## Reference solution

Show it with `lab solution 2.03`, apply it with `lab solve 2.03`.
