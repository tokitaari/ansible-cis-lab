# 1.01 - Remove insecure client packages: Explanation

### What the check verifies
`lab check 1.01` runs `check.yml` on `targets`: it collects `package_facts` and asserts that
`'telnet' not in ansible_facts.packages`. Then it runs your playbook once more with `--check`
and expects `changed=0` (`meta.yml` says `idempotency: true`).

The check looks at the package **name** only:

- It does not test requirement 3. A solution with `apt`, `dnf` or `shell` passes as long as the
  package is gone.
- It does not test that the program is gone. On Debian and Ubuntu the reference solution passes
  while `/usr/bin/telnet` still works (measured, see below).

### How it works

#### `package` picks the manager
`ansible.builtin.package` is an action plugin. It reads the fact `ansible_facts.pkg_mgr` (or the
parameter `use:`) and runs the matching module: `apt`, `dnf` (`dnf5` on Fedora), `zypper`,
`pacman` or `apk`. In ansible-core 2.21.6 the last three are redirected to `community.general`.
It is the right tool for a plain install or removal. As soon as you need options of one manager
(`autoremove`, `purge`, `update_cache`) you switch to the specific module; `service` and
`systemd` follow the same idea in [1.04](../1.04-disable-ftp-server/README.md).

#### `state: absent` is tolerant
A package that is not installed is `ok`, not an error. Measured with the reference solution on
fresh targets: `changed=1` on debian, ubuntu, rocky, alma, fedora and opensuse, `ok` on arch and
alpine, and `changed=0` on the second run everywhere. On arch and alpine the name `telnet` is not
even a package (`pacman -Si telnet`: "was not found"; `apk info -e telnet`: no package named
telnet), and the task is still `ok`. That answers bonus 3 for these two managers; dnf and zypper
were not tested with an unknown name.

#### The package name is not the program
The program lives in different packages:

- **Debian family:** `inetutils-telnet`. `telnet` is a transitional dummy package
  ("transitional dummy package for inetutils-telnet default switch") with
  `Depends: inetutils-telnet`.
- **Arch:** `inetutils`, which also ships `/usr/bin/hostname` (`pacman -Ql`). Removing it
  removes `hostname` too.
- **Alpine:** `busybox-extras` (`/usr/bin/telnet` is a link to `/bin/busybox-extras`) or
  `inetutils-telnet`. The BusyBox of the base image has no `telnet` applet.

The lab images ship a client only on the Debian, Red Hat and SUSE hosts. The solution cannot
remove a client you installed by hand on arch or alpine: measured with `inetutils` on arch and
`busybox-extras` on alpine, the task reports `ok` and `command -v telnet` still prints
`/usr/bin/telnet`. Per-family package names are what stage 2 introduces
([2.01](../../stage2-building-blocks/2.01-shadow-permissions-per-family/README.md)).

#### Debian and Ubuntu: the transitional package
Measured on Debian 13 and Ubuntu 26.04: `inetutils-telnet` is marked as automatically
installed, and `/usr/bin/telnet` is an `update-alternatives` link to `/usr/bin/inetutils-telnet`.
After the solution `telnet` is gone, `inetutils-telnet` is not, `command -v telnet` still prints
`/usr/bin/telnet`, and `apt-get -s autoremove` lists `inetutils-telnet` as removable.
`lab check 1.01` passes anyway.

To remove the program, name the package that holds it. Measured on ubuntu:
`ansible.builtin.package` with `name: inetutils-telnet` and `state: absent` reports `changed`,
`command -v telnet` then prints nothing, and the reference solution is `changed=0` afterwards.
The alternative `ansible.builtin.apt` with only `autoremove: true` reported `ok` on debian and
left the binary in place in our run (not investigated): use the explicit name. The name exists
on the Debian family only, so in a play for all hosts it belongs into per-family data.

#### Check mode shows the manager's own plan
`--check --diff` on debian prints apt's dry run: "The following packages will be REMOVED:
telnet", and the note that `inetutils-telnet` "was automatically installed and is no longer
required". That note is the transitional-package problem in one line. The recap shows
`changed=1` on six hosts and `ok` on arch and alpine (the answer to bonus 1).

### Per-family notes
| Host | Client at the start | Package | After the solution |
|---|---|---|---|
| debian 13 | `/usr/bin/telnet` | `telnet` 0.17+2.6 (dummy) + `inetutils-telnet` | dummy removed, binary stays |
| ubuntu 26.04 | `/usr/bin/telnet` | `telnet` 0.17+2.7 (dummy) + `inetutils-telnet` | dummy removed, binary stays |
| rocky 10.2, alma 10.2 | `/usr/bin/telnet` | `telnet-0.17-94.el10` | removed, binary gone |
| fedora 44 | `/usr/bin/telnet` | `telnet-0.17-96.fc44` | removed, binary gone |
| opensuse 16.0 | `/usr/bin/telnet` | `telnet-1.2` | removed, binary gone |
| arch | none | no package `telnet`; `inetutils` 2.8-1 in the repository | `ok` |
| alpine 3.24 | none | no package `telnet`; `busybox-extras` and `inetutils-telnet` in the repository | `ok` |

### Pitfalls and measured facts
| Symptom | Cause | Fix |
|---|---|---|
| `lab check` passes, `telnet` still starts on Debian or Ubuntu | only the dummy package was removed | also remove `inetutils-telnet`; test with `command -v telnet` |
| `which telnet` fails with "command not found" | `which` is missing on rocky, alma, fedora and opensuse | `command -v telnet` in a shell, or `ansible.builtin.stat` |
| arch or alpine reports `ok`, the client is still there | `telnet` is not a package name there | remove `inetutils` or `busybox-extras` by name, per family |
| the playbook fails on one family | a manager-specific module (`apt`, `dnf`) was used | `ansible.builtin.package` |

### Real-world notes
Check the effect, not the package list: `command -v telnet` (or the audit tool of your
benchmark) answers "is the client still usable". The same applies to every package removal
where a package was renamed or split. Removing a client can also remove other programs that
live in the same package (arch: `hostname`), so read the file list first.

### Further reading
- Lesson [L02 - Safe changes](../../../docs/lessons/L02-safe-changes.md): `--check --diff`, what changes and what only looks like a change.
- Lesson [L03 - Base hardening](../../../docs/lessons/L03-base-hardening.md): packages, services, files, SSH and sudo in one place.
- Exercise [1.04 - Stop and disable the FTP server](../1.04-disable-ftp-server/README.md): `package_facts` next to `service`.
- [`ansible.builtin.package` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/package_module.html) and [`ansible.builtin.package_facts` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/package_facts_module.html)

## Reference solution

Show it with `lab solution 1.01`, apply it with `lab solve 1.01`.
