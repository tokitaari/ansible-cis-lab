# Troubleshooting

*[Deutsch](TROUBLESHOOTING.de.md)*

| Symptom | Cause | Fix |
|---|---|---|
| A systemd target exits immediately / `Failed to mount cgroup` | cgroup setup of your Docker host | use cgroup v2 (default in current Docker Desktop/WSL2). Fallback per target in `compose.yaml`: `cgroup: host` and volume `/sys/fs/cgroup:/sys/fs/cgroup:rw` |
| `rocky`/`alma` fail with `Fatal glibc error: CPU does not support x86-64-v2/v3` | Enterprise Linux 10 requires an x86-64-v3 CPU | newer CPU, or switch the base image: `BASE_IMAGE=rockylinux/rockylinux:9` / `almalinux:9` (build arg in the Dockerfile) |
| `UNREACHABLE` right after `./lab.sh up` | targets still booting / key not installed yet | wait 30 s; `./lab.sh logs debian`; inside the target `systemctl status lab-keysync` |
| Every host `UNREACHABLE` after an exercise | sshd or firewall change locked you out | `./lab.sh reset all` (or the single host), fix the playbook, use `validate` and the dead-man switch |
| `sshd -t` fails with `Bad SSH2 KexAlgorithms` | an older OpenSSH does not know `mlkem768x25519-sha256` | remove it from the list (2.02 / role defaults) - all current lab images support it |
| Many checks fail only on `alpine` | Python missing | run exercise 0.02 or `lab solve 0.02` once after each `reset alpine` |
| `ansible.cfg` ignored, wrong inventory | lab on a world-writable mount (e.g. `/mnt/c` in WSL) | clone inside the Linux file system; `ANSIBLE_CONFIG` is set in the control node anyway |
| Files in `./work` owned by root on the host | started without `lab.sh` | start with `./lab.sh up` (sets `LAB_UID`/`LAB_GID`) or `LAB_UID=$(id -u) LAB_GID=$(id -g) docker compose up -d` |
| `package_facts` fails on Fedora/openSUSE | `python3-rpm` missing | rebuild the image (`./lab.sh destroy && ./lab.sh up`); on openSUSE the package name may differ (`python313-rpm`) |
| `Fedora 45` wanted | the image tag is `fedora:44` while 45 is not released | change `BASE_IMAGE` in `targets/fedora/Dockerfile` |
| Image pull fails on `archlinux:latest` for arm64 | no official arm64 Arch image | remove the `arch` service on Apple Silicon or use an arm64 community image |
| `lab check` passes state checks but reports *not idempotent* | your playbook reports `changed` in `--check` | look at the tasks listed as `changed`; typical: `command` without `changed_when`, `copy` with timestamps, `password_hash` without salt |
| Docker DNS broken inside a target (`apt`/`dnf` cannot resolve) | `nft flush ruleset` or a restarted nftables service | `./lab.sh reset <host>`; see 4.07 |

## Useful commands

```bash
./lab.sh ps                         # container state
./lab.sh logs rocky                 # boot log of a target
docker compose exec rocky bash      # root shell in a target (bypasses SSH - for debugging only)
ansible targets -m ansible.builtin.raw -a 'uptime'   # works even without Python
ansible-playbook playbook.yml -vvv   # verbose connection details
```
