# Installation

*[Deutsch](INSTALL.de.md)*

The lab needs **nothing but Docker, Compose v2 and Git** on your computer. The control node and
the eight targets are containers; Ansible, `ansible-lint` and the `lab` CLI live in the control
node. This guide covers the common steps first, then Docker for Windows, macOS and Linux, and
what is special about Docker on each of them.

Short version: [Quick start in the README](README.md#quick-start). Read on if Docker is not
installed yet, if something fails, or if you want to know why the lab asks for what it asks for.

## What you need

| | |
|---|---|
| Docker | Docker Engine 24+ **or** Docker Desktop, with the Compose **v2** plugin (`docker compose`, not `docker-compose`); `compose.yaml` uses the service key `cgroup`, which needs Compose 2.15 or later |
| Git | to clone the lab (a downloaded ZIP works too, but cannot be updated with `git pull`) |
| CPU | x86-64 is the tested platform. Arm64 (e.g. Apple silicon): see [macOS](#macos); the `arch` target has no official arm64 image |
| RAM and disk | 4 GB RAM available **to Docker** and about 8 GB free disk, as in the README; on Windows and macOS this is the share you give the Docker VM, not what the computer has |
| Network | Internet access for the first build (base images, distribution packages, `pip`, GitHub); the lab publishes **no ports** to your host |
| Rights | permission to talk to the Docker daemon (Linux: `docker` group), see [Linux](#linux) |
| A computer you may play on | the targets run `privileged` and share the Docker host's kernel - read [`docs/CONTAINER_LIMITS.md`](docs/CONTAINER_LIMITS.md) and do not use a production host |

Not supported: **rootless Docker** (privileged targets only get the rights of your user
namespace, and cgroup limits need extra setup) and **Podman** (`lab.sh` calls `docker compose`,
and the lab has not been tried with Podman). Both are untested, not forbidden - expect to debug
them yourself.

**Tested by the maintainer:** Debian (native host) with Docker Engine, and Windows with WSL2 (Ubuntu 26.04
with Docker Engine). Everything else
below is written from the vendors' documentation and **not tested** with this lab; the
sections say so. Reports and fixes are welcome.

## The same on every platform

1. **Install Docker** for your platform (sections below) and check it:

   ```bash
   docker version
   docker compose version
   docker run --rm hello-world
   ```
   `docker compose version` must print Compose 2.15 or later. `docker version` must show a
   *Client* **and** a *Server* section - if the server part is missing, the daemon is not running.

2. **Clone the lab** - on Windows inside the WSL2 Linux file system, see [Windows](#windows):

   ```bash
   git clone https://github.com/tokitaari/ansible-cis-lab
   cd ansible-cis-lab
   ```

3. **Build and start** (the first run pulls the base images and builds nine images - a few
   minutes, depending on your connection):

   ```bash
   ./lab.sh up
   ```
   Windows PowerShell: `.\lab.ps1 up`. The wrapper waits until all targets accept SSH and then
   prints the lab status.

4. **Open the control node** and begin:

   ```bash
   ./lab.sh shell
   lab placement
   ```
   Inside the control node `lab` is the lab CLI; `lab list` shows all exercises.

5. **Look at the result** from the host:

   ```bash
   ./lab.sh ps
   ```
   Nine containers (`control` plus `debian`, `ubuntu`, `rocky`, `alma`, `fedora`, `opensuse`,
   `arch`, `alpine`) must be *running*, `control` *healthy*.

The wrapper sets three things for you: `LAB_UID` and `LAB_GID` (your user, so the files in `./work` belong to you)
and `LAB_TZ` (your time zone, for the control node). That is why you should start the lab with
`./lab.sh` and not with a bare `docker compose up`.

## Windows

Containers need a Linux kernel, so Docker on Windows runs a Linux VM: WSL2 (default) or Hyper-V.
Choose one of three routes.

| Route | What it is | Status |
|---|---|---|
| **A. Docker Engine in WSL2, no Docker Desktop** | the Linux steps in a WSL distribution with systemd (Ubuntu) | recommended, tested (Ubuntu 26.04) |
| B. Docker Desktop + WSL2 | Docker Desktop with the WSL integration, `./lab.sh` in a WSL terminal | not tested |
| C. Docker Desktop + PowerShell, lab on a Windows drive | `.\lab.ps1` | not tested, slower, not recommended |

### Route A: Docker Engine in WSL2

1. **Enable WSL2.** Needs hardware virtualization enabled in the BIOS/UEFI. In an administrator
   PowerShell:

   ```powershell
   wsl --install
   wsl --update
   wsl --version
   ```
   `wsl --install` installs a default Linux distribution (Ubuntu); open it once to create your
   Linux user.

2. **Check that systemd runs** in the distribution (Docker's service needs it). Current Ubuntu on WSL starts it
   by default:

   ```bash
   ps -p 1 -o comm=
   ```
   The answer must be `systemd`. If not (older or other distributions), enable it - WSL supports it from
   version 0.67.6 - in `/etc/wsl.conf` and restart WSL from PowerShell with `wsl --shutdown`:

   ```ini
   [boot]
   systemd=true
   ```

3. **Install Docker Engine** inside the distribution with the Debian/Ubuntu steps from [Linux](#linux),
   including the `docker` group. Close the terminal and open it again, then check
   `docker run --rm hello-world`. There is no Docker Desktop, no WSL integration switch and no
   Docker Desktop licence question; updates and the `docker` group are yours to manage.

4. **Clone inside the Linux file system** (`~`, e.g. `/home/you/ansible-cis-lab`) and run the
   steps from [The same on every platform](#the-same-on-every-platform) **in the WSL terminal**:

   ```bash
   cd ~
   git clone https://github.com/tokitaari/ansible-cis-lab
   cd ansible-cis-lab
   ./lab.sh up
   ```
   Not under `/mnt/c/...`: the Windows drive is mounted world-writable (Ansible ignores
   `ansible.cfg` there, see [TROUBLESHOOTING](docs/TROUBLESHOOTING.md)) and file access across
   the boundary is slow. Edit your solutions from Windows through `\\wsl$\<distribution>\home\you\ansible-cis-lab\work`
   or with VS Code's *WSL* extension.

### Route B: Docker Desktop with the WSL2 backend

1. **Enable WSL2** as in step 1 of Route A. Per Docker's requirements for the WSL2 backend you
   need a 64-bit processor with SLAT and 8 GB system RAM, and WSL **2.1.5 or later**.

2. **Install Docker Desktop** from [docker.com](https://www.docker.com/products/docker-desktop/)
   and choose *Use WSL 2 instead of Hyper-V* on the configuration page. Per-user installs
   (`"Docker Desktop Installer.exe" install --user`) support only the WSL2 backend and need no
   administrator rights for updates. In *Settings > General* *Use the WSL 2 based engine* must
   be on, and Docker must run **Linux containers** (the default with WSL2).

3. **Switch Docker on for your distribution:** *Settings > Resources > WSL integration*, enable
   your distribution, *Apply*. In the WSL terminal `docker version` must now show a server.

4. **Clone and start inside the WSL file system** exactly as in step 4 of Route A.

### Route C: PowerShell with the lab on a Windows drive

`.\lab.ps1` offers the same commands as `./lab.sh`. The lab directory is then a Windows folder
that Docker bind-mounts into the Linux VM: file access is slower and Linux permissions are
approximated (`ansible.cfg` is ignored, the control node sets `ANSIBLE_CONFIG` itself). Take
care of the line endings (below) and expect `LAB_UID` and `LAB_GID` to default to `1000`.

### Windows details

- **Line endings.** Scripts in `control/` and `targets/` run **inside Linux containers straight
  from your clone**. With Git for Windows' default `core.autocrlf=true` a clone made on the Windows side
  gets CRLF line endings, and the scripts fail with errors that mention `\r` or `^M`. Clone inside WSL
  (Git there leaves the line endings alone) or, for Route C, set the option **before** cloning:

  ```powershell
  git config --global core.autocrlf input
  ```
- **Memory and CPUs.** The WSL2 VM takes what it needs up to a limit (by default a share of your
  RAM). Cap or raise it in `%UserProfile%\.wslconfig` (a Windows file, **not** `/etc/wsl.conf`):

  ```ini
  [wsl2]
  memory=8GB
  processors=4
  swap=2GB
  ```
  Apply it with `wsl --shutdown`, then open your distribution (and Docker Desktop, if you use it) again. The lab needs 4 GB for Docker
  (see above); WSL2 itself wants 8 GB system RAM.
- **Disk.** Docker's data lives in a virtual disk (VHDX). Inside a target `df /` shows its
  nominal size, not the free space of your Windows drive; when that drive is full, writes
  fail although `df` still reports plenty (see [`docs/CONTAINER_LIMITS.md`](docs/CONTAINER_LIMITS.md)).
  Check with `docker system df` and in Windows.
- **Kernel.** All targets share the kernel of the WSL2 VM, not Windows. Kernel-wide settings
  stay inside that VM.
- **Licence.** Docker Desktop in a company with more than 250 employees or more than
  USD 10 million annual revenue needs a paid subscription; Docker Engine in WSL2 (Route A) does not.
- **Hyper-V backend.** Docker Desktop can also run its Linux engine on Hyper-V (Windows Pro,
  Enterprise or Education). Not tested; everything else here applies unchanged.

## macOS

Docker Desktop is the documented way to run Docker on a Mac; all containers run in its Linux VM.
Not tested with this lab - the steps follow Docker's documentation.

1. **Download** the right build from [docker.com](https://www.docker.com/products/docker-desktop/):
   *Apple silicon* (M-series) or *Intel chip*. Docker supports the current macOS release and the
   two before it.
2. **Install:** open `Docker.dmg`, drag Docker to *Applications* and start it. On Apple silicon
   Rosetta 2 is no longer required but recommended:

   ```bash
   softwareupdate --install-rosetta
   ```
3. **Give it resources:** *Settings > Resources* - at least 4 GB RAM, more is better.
4. In *Terminal*, run the steps from [The same on every platform](#the-same-on-every-platform).

macOS details:

- **File sharing.** `./` is bind-mounted into the VM as `/lab`; the file access crosses the VM
  boundary and is slower than on Linux. Your solutions in `./work` stay editable in any Mac editor.
- **Apple silicon.** The base images are pulled for arm64. The Arch Linux image has no official
  arm64 build: see *Image pull fails on `archlinux:latest` for arm64* in
  [TROUBLESHOOTING](docs/TROUBLESHOOTING.md). Rocky and Alma 10 need an x86-64-v3 CPU only on x86-64 hosts.
- **Kernel.** All targets share the kernel of Docker's Linux VM, not macOS.
- **Licence.** The Docker Desktop terms mentioned for Windows apply here too.
- **Alternatives.** Colima (`brew install colima docker docker-compose`, `colima start --cpus 4 --memory 6`)
  or OrbStack (`brew install --cask orbstack`) provide the Docker engine without Docker Desktop.
  Not tested: both create their own Docker context (`docker context ls`), and you have to check
  that the targets run as privileged systemd containers (`./lab.sh ps`, all *running*).

## Linux

On Linux Docker runs **natively**: the targets share the kernel of your own computer, so the
rules in [`docs/CONTAINER_LIMITS.md`](docs/CONTAINER_LIMITS.md) concern your real machine. Use a
virtual machine if you would rather not take that risk.

Before you start, check that the host uses **cgroup v2** (current Debian, Ubuntu, Fedora, RHEL
9+ and Arch do by default); the systemd targets need it:

```bash
stat -fc %T /sys/fs/cgroup
```
`cgroup2fs` is what you want to see.

Docker publishes packages for Debian, Ubuntu, Fedora, RHEL and CentOS. Arch Linux and openSUSE
use their own distribution packages. Remove conflicting distribution packages
(Debian/Ubuntu: `docker.io`, `docker-compose`, `podman-docker`, `containerd`, `runc`; Fedora: the
distribution's `moby-engine`) before you use Docker's repository.

### Debian and Ubuntu

Docker's apt repository, as in the official instructions. The commands are for **Ubuntu**; on
**Debian** replace `ubuntu` with `debian` in both URLs.

```bash
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
The service starts on boot automatically on Debian and Ubuntu. Derivatives (Linux Mint and
friends) are not officially supported - use the matching Debian or Ubuntu release name.

### Fedora

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```
The `addrepo --from-repofile` syntax is DNF5 (Fedora 41 and later); with DNF4 use
`config-manager --add-repo <URL>`. The package install does not start Docker - hence `enable --now`.

### RHEL, Rocky Linux, AlmaLinux

Follow Docker's *RHEL* or *CentOS* page: the repository file is
`https://download.docker.com/linux/rhel/docker-ce.repo` (RHEL) or
`https://download.docker.com/linux/centos/docker-ce.repo` (CentOS and its derivatives such as
Rocky and AlmaLinux, which Docker does not test itself). Then install the same five packages as on
Fedora and run `sudo systemctl enable --now docker`. Not tested with this lab.

### Arch Linux

Update first - a partial upgrade is the common way to break Arch:

```bash
sudo pacman -Syu
sudo pacman -S docker docker-compose docker-buildx
sudo systemctl enable --now docker
```
The `docker-compose` package provides the `docker compose` plugin. Docker's own Arch package
(Docker Desktop for Linux) conflicts with these - choose one.

### openSUSE

```bash
sudo zypper install docker docker-compose docker-buildx
sudo systemctl enable --now docker
```
On Leap 16 the `docker-compose` package installs the Compose v2 plugin (`docker compose`; there
is no hyphenated binary); Tumbleweed uses the same package names. Older Leap releases may lack
the package: install the Compose plugin manually from Docker's binary releases. Leap 16 ships
Podman by default - do not install `podman-docker` next to the real Docker.

### Use Docker without `sudo`

Add your user to the `docker` group, then log out and in again (or run `newgrp docker`):

```bash
sudo usermod -aG docker $USER
docker run --rm hello-world
```
Membership in `docker` is **root-equivalent** on the host - which the privileged lab targets
anyway are. Do not start the lab with `sudo ./lab.sh`: `id -u` would be 0 and the
control node would create a second root user for `learner`. If you must, pass your own IDs:
`sudo env LAB_UID=$(id -u) LAB_GID=$(id -g) ./lab.sh up`.

### Linux details

- **SELinux** (Fedora, RHEL family). Docker's default daemon does not separate containers with
  SELinux, so nothing changes. If you enabled `"selinux-enabled": true` in
  `/etc/docker/daemon.json`, the control node cannot read the bind-mounted lab directory until
  you add the `z` option to that volume in `compose.yaml` (`./:/lab:z`). Never use `Z` or
  `z` on system directories.
- **Firewall.** The lab publishes no ports, so `ufw` or `firewalld` cannot be "bypassed" by it;
  the containers only need outbound access through Docker's NAT. Docker is compatible with
  `iptables-nft` and `iptables-legacy`; rules created directly with `nft` are not supported while Docker
  runs - never `nft flush ruleset` on the host. With `firewalld`, Docker creates a zone called `docker`.
- **Subnet.** The lab network is `172.31.250.0/24`. If a VPN or your LAN already uses it,
  `docker compose up` fails with *Pool overlaps with other one on this address space*. Change the
  `subnet:` in `compose.yaml`; the hosts are addressed by name, not by IP.
- **Docker Desktop for Linux** runs its own VM with its own Docker context and is a different setup
  from Docker Engine; not tested.

## Docker on each platform at a glance

| | Linux | Windows (WSL2) | macOS |
|---|---|---|---|
| Where the containers run | on your host | in the WSL2 VM | in Docker Desktop's VM |
| Kernel the targets share | your host's | the WSL2 kernel | the VM's kernel |
| Install | Docker Engine from the distribution or Docker's repository | Engine in a WSL distribution, or Docker Desktop | Docker Desktop (or Colima, OrbStack) |
| Who may use the daemon | members of `docker` (root-equivalent) | members of `docker` in the WSL distribution (Engine), or your Windows user (Docker Desktop) | your macOS user, through Docker Desktop |
| Resource limits | the host's | `%UserProfile%\.wslconfig` and Docker Desktop | Docker Desktop *Settings > Resources* |
| Where the repo should live | anywhere | **inside** the WSL file system | anywhere in your home folder |
| File access to `./work` | native | fast in WSL, slow on `/mnt/c` | through the VM, slower |
| Disk | the host's disk | virtual disk (VHDX); `df /` shows its size | virtual disk of the VM |
| Licence | open source | Engine: open source; Docker Desktop: paid for large companies | Docker Desktop: paid for large companies |
| Tested with this lab | Debian (native host) | yes (Ubuntu 26.04, Docker Engine) | no |

## Update, pause, remove

| Task | Command |
|---|---|
| Update the lab | `git pull --ff-only`, then `docker compose build && docker compose up -d` if Dockerfiles changed (see the *Updating the lab* section of the README and the [CHANGELOG](CHANGELOG.md)) |
| Stop for now, keep the targets as they are | `./lab.sh pause`, later `./lab.sh resume` |
| Start every target fresh | `./lab.sh reset all` (or `down`, then `up`) |
| Remove the containers, volumes and lab images | `./lab.sh destroy` (your `./work` and `./.lab` stay) |
| Remove the lab completely | `./lab.sh destroy`, then delete the directory |

Docker itself is removed the way you installed it - see Docker's uninstall instructions
for Docker Engine and Docker Desktop.

## If something fails

| Symptom | Cause | Fix |
|---|---|---|
| `Cannot connect to the Docker daemon` | the daemon is not running | Linux and WSL: `sudo systemctl enable --now docker` (in WSL, systemd must run, see Route A step 2); Docker Desktop: start it and wait until it reports *running* |
| `permission denied ... /var/run/docker.sock` | your user is not in the `docker` group | [Use Docker without sudo](#use-docker-without-sudo), then log in again |
| `docker: command not found` in a WSL terminal | Docker Engine is not installed in this distribution, or (Docker Desktop) the WSL integration is off | Route A step 3, or Docker Desktop *Settings > Resources > WSL integration* |
| `Unsupported config option ... 'cgroup'` or `'compose' is not a docker command` | the old `docker-compose` (v1), no Compose plugin, or Compose older than 2.15 | install the Compose v2 plugin and use `docker compose` |
| `Pool overlaps with other one on this address space` | `172.31.250.0/24` is in use elsewhere | change `subnet:` in `compose.yaml` |
| A systemd target exits immediately | the host does not use cgroup v2 | [Linux](#linux) and the first row of [TROUBLESHOOTING](docs/TROUBLESHOOTING.md) |
| `rocky` / `alma` crash with `Fatal glibc error: CPU does not support x86-64-v2` | the CPU does not support what Enterprise Linux 10 needs | [TROUBLESHOOTING](docs/TROUBLESHOOTING.md) |
| Scripts fail with `^M` or `\r` in the message | CRLF line endings from a Windows clone | [Windows details](#windows-details), then clone again |
| Files in `./work` belong to root | the lab was started without `./lab.sh` or with `sudo` | start with `./lab.sh up` as your own user |

Everything about *running* the lab (exercises, UNREACHABLE hosts, `down` versus `pause`) is in
[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Sources

- [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) and [the WSL2 backend](https://docs.docker.com/desktop/features/wsl/)
- [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
- [Docker Engine: supported platforms](https://docs.docker.com/engine/install/), [Ubuntu](https://docs.docker.com/engine/install/ubuntu/), [Fedora](https://docs.docker.com/engine/install/fedora/) and [post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/)
- [Compose file reference: `cgroup`](https://docs.docker.com/reference/compose-file/services/) and [packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
- [WSL: `wsl.conf` and `.wslconfig`](https://learn.microsoft.com/windows/wsl/wsl-config) and [systemd in WSL](https://learn.microsoft.com/windows/wsl/systemd)
- [Arch Wiki: Docker](https://wiki.archlinux.org/title/Docker) and [openSUSE: Docker](https://en.opensuse.org/Docker)
