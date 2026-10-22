# shellcheck shell=bash
# Sourced by interactive bash shells in the control node
export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-/lab/ansible/ansible.cfg}"
export ANSIBLE_FORCE_COLOR=1
PS1='\[\e[1;32m\]lab\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
if [ -z "${LAB_WELCOME_SHOWN:-}" ]; then
  export LAB_WELCOME_SHOWN=1
  echo "Ansible CIS lab - control node.  'lab help' lists all commands."
  echo "Your work directory: /lab/work   (mounted from ./work on the host)"
fi
