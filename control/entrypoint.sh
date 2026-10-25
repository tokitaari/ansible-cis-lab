#!/bin/sh
# Creates the "learner" user with the host user's UID/GID (so files in ./work
# stay editable on the host) and generates the lab SSH key on first start.
set -eu
uid="${LAB_UID:-1000}"
gid="${LAB_GID:-1000}"

if ! getent group learner >/dev/null; then
  groupadd -o -g "$gid" learner
fi
if ! id learner >/dev/null 2>&1; then
  useradd -o -m -u "$uid" -g "$gid" -s /bin/bash learner
fi

if [ ! -s /lab-keys/id_ed25519 ]; then
  ssh-keygen -q -t ed25519 -N '' -C 'ansible-cis-lab' -f /lab-keys/id_ed25519
fi
chown "$uid:$gid" /lab-keys/id_ed25519 /lab-keys/id_ed25519.pub
chmod 0600 /lab-keys/id_ed25519
chmod 0644 /lab-keys/id_ed25519.pub
chmod 0755 /lab-keys

mkdir -p /lab/work /lab/.lab
chown "$uid:$gid" /lab/work /lab/.lab 2>/dev/null || true

exec "$@"
