# shellcheck shell=bash
# Sourced by every interactive bash in the control node (via /etc/bash.bashrc).
# The prompt comes from oh-my-bash in ~/.bashrc.
export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-/lab/ansible/ansible.cfg}"
export ANSIBLE_FORCE_COLOR=1
if [ -z "${LAB_WELCOME_SHOWN:-}" ]; then
  export LAB_WELCOME_SHOWN=1
  echo "Ansible CIS lab - control node.  'lab help' lists all commands, 'lab docs' the guides."
  echo "Your work directory: /lab/work   (mounted from ./work on the host)"
fi
