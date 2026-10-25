# 2.03 - Disable unneeded kernel modules

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 2 - Building blocks | ★★☆☆☆ | ~30 min | 1.1.1 Kernel modules / 3.2 Network kernel modules (L1/L2) | `targets` |

**Concepts:** `loop`, `copy per item`, `modprobe.d`, `container limits`

## Goal

Prevent rarely used filesystem and protocol modules from being loaded - each module with its own `modprobe.d` file.

## Background

Every loadable module is kernel code an attacker can trigger (e.g. by mounting a
crafted USB stick or opening an exotic socket). CIS disables modules that servers
rarely need. Two lines per module:

```
install <module> /bin/false   # loading fails
blacklist <module>            # no automatic loading by alias
```

**Container note:** all containers share the HOST kernel. In this lab you only
write the configuration - you must **not** `modprobe -r` anything (that would unload
modules from your host). Read `docs/CONTAINER_LIMITS.md`.

## Requirements

- [ ] Variable `cis_disabled_modules_l1`: `cramfs`, `freevxfs`, `hfs`, `hfsplus`, `jffs2`, `usb-storage`.
- [ ] One file per module: `/etc/modprobe.d/cis-<module>.conf`, content exactly the two lines above, `root:root`, `0644`.
- [ ] Use a single task with `loop`.
- [ ] No `modprobe -r`, no `rmmod`.

## How to work

```bash
lab start 2.03            # creates /lab/work/2.03/
cd /lab/work/2.03
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 2.03            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 2.03 1` (gentle) ... `lab hint 2.03 3` (almost the answer).  
Passed? Read `lab explain 2.03` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Add a list `cis_disabled_modules_l2` (`squashfs`, `udf`, `dccp`, `tipc`, `rds`, `sctp`) and a variable `cis_level` (default 1). Level-2 modules are only handled when `cis_level >= 2`. Hint: `cis_disabled_modules_l1 + (cis_disabled_modules_l2 if cis_level | int >= 2 else [])`.
- On a real VM you would also unload loaded modules. Write that task, but guard it with `when: not lab_in_container` (variable already defined in the inventory).
- Why can disabling `squashfs` break Ubuntu systems? (Think: snaps.)
