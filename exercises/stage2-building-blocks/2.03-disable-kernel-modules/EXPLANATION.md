# 2.03 - Disable unneeded kernel modules: Explanation

### What the check verifies
`lab check 2.03` runs `check.yml` on `targets`: for each of the six Level 1 modules (with
`-e cis_level=2` also the six Level 2 modules) it reads `/etc/modprobe.d/00-cis-<module>.conf` and
asserts a line `install <module> /bin/false` (or `/usr/bin/false`) and a line `blacklist <module>`.
On the hosts whose `modprobe -V` names kmod (all but alpine) it then asks `modprobe
--show-depends <module>` which rule **applies** and expects your `install` line as the answer. Then it runs your playbook once more with `--check` and expects `changed=0`.

- File names are fixed, with the README spelling: `00-cis-usb-storage.conf`, not
  `00-cis-usb_storage.conf` or `cis-usb-storage.conf`.
- Nothing may follow `/bin/false` on the line: a trailing `# comment` fails, `/bin/true` (used by
  older benchmark versions) fails too.
- Owner, mode and extra lines are not tested.
- A rule that an earlier-sorted file overrides fails on the kmod hosts (measured on opensuse with
  an extra `00-aaa-cramfs.conf`). On alpine only the files count (BusyBox ignores `install`).
- Leftover files with other names do not matter while `00-cis-...` sorts first (measured with the
  old names `cis-<module>.conf` next to the new ones).

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
ignores it unless called with `-b`. Lesson L05 shows both with `modprobe -n -v`. Measured on all
seven kmod hosts after the solution (Level 2 included): `modprobe -n -v` and `modprobe
--show-depends` print `install /bin/false` for all twelve modules.

#### Dash and underscore
The kernel module is called `usb_storage`. kmod treats `-` and `_` as the same character, so
`install usb-storage /bin/false` covers it: `modprobe -n -v usb_storage` and `usb-storage` both
print the rule (measured on all seven kmod hosts), and `modprobe -c` lists it as `usb_storage` (session test).

#### The first `install` line wins
kmod merges `/etc/modprobe.d`, `/run/modprobe.d` and `/usr/lib/modprobe.d` and reads the files in
the byte order of their **names**; a file in `/etc` replaces one of the same name in `/usr/lib`.
For `install` the first line found counts. openSUSE ships `60-blacklist_fs-<fs>.conf` for 29 file
systems, five of them on the Level 1 list, each with `blacklist <fs>` and
`install <fs> /usr/lib/module-init-tools/unblacklist <fs>; /sbin/modprobe --ignore-install <fs>`.
That rule does not block: started without a terminal, as by the kernel, `unblacklist` exits at
once (suse-module-tools 16.0.65 on the target) and `modprobe --ignore-install` loads the module.
`00-cis-<module>.conf` sorts before `60-...` and wins; the old name of this exercise,
`cis-<module>.conf`, sorted after it and lost (measured). No other target has an `install` line
for any of the twelve modules (fresh hosts).

#### Loaded modules: the dry run says nothing
When the kernel has the module already, `modprobe -n -v` stops before it looks at `install`,
prints nothing and exits with 0 - and the lab kernel is your PC's. Measured with `ac`, loaded in
the WSL2 host kernel, and a temporary `install ac /bin/false`: `-n -v` printed nothing on all seven
kmod hosts, `modprobe --show-depends ac` printed `install /bin/false`. `--show-depends` ignores the
loaded state, so the check uses it. None of the twelve modules was loaded on the measuring host.

#### Alpine: BusyBox ignores `install`
`/sbin/modprobe` on alpine is BusyBox 1.37.0. Its configuration parser knows only `alias`,
`options`, `include` and `blacklist` (BusyBox source; a test with BusyBox 1.36.1 confirms it):
the `install` line is ignored, a plain `modprobe cramfs` would try to load the module, and
`blacklist` holds for the plain name only with `-b`. BusyBox also has no `-n`, so there is no dry
run to verify the rule; the check skips that part there (`modprobe -V`: `unrecognized option`).

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
| os_family | `/sbin/modprobe` | `/bin/false` resolves to | Vendor `install` lines for the twelve modules | `modprobe -n -v cramfs` after the solution |
|---|---|---|---|---|
| Debian | kmod 34.2 | `/usr/bin/false`; ubuntu: Rust coreutils (`/usr/lib/cargo/bin/coreutils/false`) | none | `install /bin/false` |
| RedHat | kmod 31 (rocky, alma), 34.2 (fedora) | `/usr/bin/false` | none | `install /bin/false` |
| Suse | kmod 34.2 | `/usr/bin/false` | `60-blacklist_fs-*.conf` for five of them (after `00-cis-`) | `install /bin/false` |
| Alpine | BusyBox 1.37.0 | BusyBox | none (BusyBox ignores `install` anyway) | no dry run in BusyBox |
| Archlinux | kmod 34.3 | `/usr/bin/false` | none | `install /bin/false` |

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| The check fails, the file looks right | trailing comment, `/bin/true`, `00-cis-usb_storage.conf` or the old name `cis-<module>.conf` | exactly the two lines, the README file names |
| `kmod uses '...' for <module>` | an earlier-sorted file in `/etc`, `/run` or `/usr/lib/modprobe.d` | find it with `grep -r '^install <module>'` in the three directories |
| `modprobe -n -v <module>` prints nothing, exit code 0 | the (host) kernel has the module loaded already | `modprobe --show-depends <module>` shows the rule anyway |
| `Module cramfs not found in directory /lib/modules/...` | no module directory in the container, no rule yet | expected; after the rule the dry run prints `install ...` |
| `Error running install command '/bin/false'` | the rule works; you ran a real `modprobe` | read the rule with `modprobe -n -v`, do not load to test |
| `modprobe -n` fails on alpine | BusyBox has no `-n` | read the file; BusyBox does not enforce `install` anyway |
| A module unloaded on your PC | `modprobe -r` or `rmmod` in a target | never in the lab; guard with `lab_in_container` |

### Real-world notes
- Verify what applies, not what you wrote: `modprobe --show-depends <module>` on every platform
  with kmod (`-n -v` says nothing for a loaded module). A scanner that only greps your file misses
  an earlier vendor rule, and a package update can add one at any time.
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
