#!/bin/sh
# Build-time bootstrap for every lab target (POSIX sh, runs on all distros).
#
# Usage: bootstrap.sh <family> <host>
#   family: debian | redhat | suse | arch | alpine
#   host:   lab host name (used for host-specific "vulnerabilities")
#
# The script does three things:
#   1. prepares the managed-node account "ansible" (key-based, passwordless sudo)
#   2. normalises sshd so that /etc/ssh/sshd_config.d/*.conf is read FIRST
#   3. deliberately plants non-compliant settings the exercises will fix
set -eu

FAMILY="${1:?family missing}"
HOST="${2:?host missing}"
LAB=/opt/lab

log() { printf '[bootstrap:%s] %s\n' "$HOST" "$*"; }

# --------------------------------------------------------------------------
# 1. Managed-node account
# --------------------------------------------------------------------------
LOGIN_SHELL=/bin/sh
[ -x /bin/bash ] && LOGIN_SHELL=/bin/bash

if ! id ansible >/dev/null 2>&1; then
  useradd -m -U -s "$LOGIN_SHELL" ansible
fi
# '*' = no usable password but NOT locked ('!' would block sshd on non-PAM builds)
usermod -p '*' ansible

mkdir -p /etc/sudoers.d
printf 'ansible ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/00-lab-ansible
chmod 0440 /etc/sudoers.d/00-lab-ansible

for f in /etc/sudoers /usr/etc/sudoers; do
  if [ -f "$f" ] && ! grep -Eq '^[@#]includedir /etc/sudoers.d' "$f"; then
    printf '@includedir /etc/sudoers.d\n' >> "$f"
  fi
done

mkdir -p /usr/local/sbin
install -m 0755 "$LAB/lab-keysync" /usr/local/sbin/lab-keysync

# --------------------------------------------------------------------------
# 2. sshd normalisation
# --------------------------------------------------------------------------
mkdir -p /etc/ssh/sshd_config.d
if [ ! -f /etc/ssh/sshd_config ] && [ -f /usr/etc/ssh/sshd_config ]; then
  cp /usr/etc/ssh/sshd_config /etc/ssh/sshd_config   # openSUSE vendor split
fi
if ! grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config.d/' /etc/ssh/sshd_config; then
  { printf 'Include /etc/ssh/sshd_config.d/*.conf\n'; cat /etc/ssh/sshd_config; } > /tmp/sshd_config.new
  mv /tmp/sshd_config.new /etc/ssh/sshd_config
fi
ssh-keygen -A >/dev/null

# --------------------------------------------------------------------------
# Init-system wiring
# --------------------------------------------------------------------------
if [ "$FAMILY" = "alpine" ]; then
  # OpenRC inside a container
  sed -i 's/^#*rc_sys=.*/rc_sys="docker"/' /etc/rc.conf
  sed -i 's/^#*rc_provide=.*/rc_provide="loopback net"/' /etc/rc.conf
  grep -q '^rc_provide=' /etc/rc.conf || printf 'rc_provide="loopback net"\n' >> /etc/rc.conf
  sed -i '/getty/d' /etc/inittab
  mkdir -p /etc/local.d
  printf '#!/bin/sh\nexec /usr/local/sbin/lab-keysync\n' > /etc/local.d/lab-keysync.start
  chmod 0755 /etc/local.d/lab-keysync.start
  rc-update add local default
  rc-update add sshd default
  [ -e /etc/init.d/crond ] && rc-update add crond default
  [ -e /etc/init.d/vsftpd ] && rc-update add vsftpd default
else
  mkdir -p /etc/systemd/system
  install -m 0644 "$LAB/lab-keysync.service" /etc/systemd/system/lab-keysync.service
  systemctl enable lab-keysync.service
  # Units that make no sense (or are harmful) inside a container.
  # systemd-modules-load would load kernel modules into the HOST kernel.
  systemctl mask \
    getty@tty1.service console-getty.service serial-getty@.service \
    systemd-udevd.service systemd-udev-trigger.service \
    systemd-modules-load.service systemd-remount-fs.service \
    systemd-firstboot.service sys-kernel-debug.mount \
    sys-kernel-tracing.mount dev-hugepages.mount >/dev/null 2>&1 || true
  case "$FAMILY" in
    debian) systemctl enable ssh.service
            systemctl disable ssh.socket >/dev/null 2>&1 || true
            systemctl enable cron.service >/dev/null 2>&1 || true ;;
    redhat) systemctl enable sshd.service crond.service
            # Container images ship without an authselect profile; real hosts have one.
            if command -v authselect >/dev/null 2>&1; then
              authselect select local --force >/dev/null 2>&1 \
                || authselect select minimal --force >/dev/null 2>&1 || true
            fi ;;
    suse)   systemctl enable sshd.service
            systemctl enable cron.service >/dev/null 2>&1 || true ;;
    arch)   systemctl enable sshd.service cronie.service ;;
  esac
  systemctl enable vsftpd.service >/dev/null 2>&1 || true
fi

# --------------------------------------------------------------------------
# 3. Deliberately non-compliant state (the exercises fix these)
# --------------------------------------------------------------------------
log "planting non-compliant settings"

# sshd: legacy drop-in that loses against an earlier-sorted file (first match wins)
cat > /etc/ssh/sshd_config.d/10-lab-legacy.conf <<'EOF'
# Legacy settings left behind by "a previous admin"
PermitRootLogin yes
PermitEmptyPasswords yes
X11Forwarding yes
MaxAuthTries 10
EOF

# Banner that leaks OS details
. /etc/os-release
printf 'Welcome to %s \\r \\m\n' "${PRETTY_NAME:-Linux}" > /etc/issue.net
cp /etc/issue.net /etc/issue

# Overly permissive account files
chmod 0664 /etc/passwd /etc/group
chmod 0644 /etc/shadow
[ -f /etc/gshadow ] && chmod 0644 /etc/gshadow

# Host-specific account problems
case "$HOST" in
  debian|rocky)
    # second UID 0 account ("toor")
    useradd -o -u 0 -g 0 -M -d /nonexistent -s /bin/sh -c 'legacy admin' toor
    usermod -p '*' toor ;;
  ubuntu|fedora)
    # account with an EMPTY password field
    useradd -m -s /bin/sh -c 'guest account' guest
    usermod -p '' guest ;;
esac

# Package sources trusted without a key: the "quick fix" for an internal mirror (exercise
# 4.10). The mirror is a local, empty repository - nothing is ever installed from it.
LEGACY=/opt/lab/legacy-repo
case "$FAMILY" in
  debian)
    mkdir -p "$LEGACY"
    : > "$LEGACY/Packages"
    { printf 'Origin: lab\nLabel: lab-legacy\nDate: %s\nSHA256:\n' "$(date -Ru)"
      printf ' %s 0 Packages\n' "$(sha256sum "$LEGACY/Packages" | cut -d' ' -f1)"; } > "$LEGACY/Release"
    printf '# Internal mirror (legacy)\ndeb [trusted=yes] file:%s ./\n' "$LEGACY" \
      > /etc/apt/sources.list.d/lab-legacy.list ;;
  redhat)
    printf '[lab-legacy]\nname=Internal mirror (legacy)\nbaseurl=file://%s\nenabled=0\ngpgcheck=0\n' \
      "$LEGACY" > /etc/yum.repos.d/lab-legacy.repo ;;
  suse)
    printf '[lab-legacy]\nname=Internal mirror (legacy)\nbaseurl=dir:%s\nenabled=0\nautorefresh=0\ngpgcheck=0\n' \
      "$LEGACY" > /etc/zypp/repos.d/lab-legacy.repo ;;
  arch)
    mkdir -p "$LEGACY"
    tar -czf "$LEGACY/lab-legacy.db.tar.gz" -T /dev/null
    ln -sf lab-legacy.db.tar.gz "$LEGACY/lab-legacy.db"
    # its sync database too: without one every pacman command warns on stderr, and
    # ansible.builtin.package_facts fails on any stderr of `pacman -Qi`
    cp "$LEGACY/lab-legacy.db.tar.gz" /var/lib/pacman/sync/lab-legacy.db
    printf '\n[lab-legacy]\n# Internal mirror (legacy)\nSigLevel = Optional TrustAll\nServer = file://%s\n' \
      "$LEGACY" >> /etc/pacman.conf ;;
  alpine)
    mkdir -p "$LEGACY/$(apk --print-arch)"
    apk index -o "$LEGACY/$(apk --print-arch)/APKINDEX.tar.gz"   # no packages: an empty, unsigned index
    printf '%s\n' "$LEGACY" >> /etc/apk/repositories
    printf 'allow-untrusted\n' > /etc/apk/config ;;
esac

log "done"
