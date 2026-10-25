#!/usr/bin/env bash
# Reference commands for exercise 0.01
set -x
ansible-inventory --graph
ansible-inventory --host debian
ansible targets -m ansible.builtin.ping || true   # alpine fails: no Python
ansible alpine -m ansible.builtin.raw -a 'cat /etc/os-release; command -v python3 || echo "no python3"'
