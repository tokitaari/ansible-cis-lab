#!/usr/bin/env bash
# Runs the state checks of several exercises (used by the stage 3-5 checks).
# Usage: run_checks.sh <id> [<id> ...] [-- <extra ansible-playbook args>]
set -u
ids=()
while [[ $# -gt 0 && "$1" != "--" ]]; do ids+=("$1"); shift; done
[[ "${1:-}" == "--" ]] && shift
rc=0
for id in "${ids[@]}"; do
  dir=""
  for d in /lab/exercises/stage*/"$id"-*; do [[ -d "$d" ]] && dir="$d"; done
  if [[ -z "$dir" || ! -f "$dir/check.yml" ]]; then
    echo "  ?    $id (no check.yml)"; continue
  fi
  log="/tmp/lab-check-$id.log"
  if ANSIBLE_NOCOLOR=1 ansible-playbook "$dir/check.yml" "$@" >"$log" 2>&1; then
    echo "  ok   $id"
  else
    echo "  FAIL $id  (details: $log)"
    grep -E '"msg"|FAILED|fatal|UNREACHABLE' "$log" | head -n 6 | sed 's/^/         /'
    rc=1
  fi
done
exit $rc
