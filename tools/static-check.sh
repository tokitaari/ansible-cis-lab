#!/usr/bin/env bash
# Static quality gate for the lab repository - no containers, no targets needed.
#   tools/static-check.sh                 all checks
#   tools/static-check.sh lint links      only the named checks
# Checks: yaml (yamllint), lint (ansible-lint, profile production, on every solution/),
#         meta, parity, links, controls (tools/static_check.py - see its docstring).
# Needs python3 + PyYAML, yamllint and ansible-lint - all present in the control node:
#   docker compose exec control /lab/tools/static-check.sh
# CI runs it in .github/workflows/release-check.yml (job "static").
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.." || exit 2
ROOT=$PWD

ALL=(yaml lint meta parity links controls)
want=("$@")
[[ ${#want[@]} -gt 0 ]] || want=("${ALL[@]}")
for c in "${want[@]}"; do
  [[ " ${ALL[*]} " == *" $c "* ]] || { echo "unknown check '$c' (choose from: ${ALL[*]})" >&2; exit 2; }
done
wanted() { [[ " ${want[*]} " == *" $1 "* ]]; }

need() {
  command -v "$1" >/dev/null && return 0
  echo "FAIL: '$1' not found - run inside the control node: docker compose exec control /lab/tools/static-check.sh" >&2
  exit 2
}

failed=()
step() { # step <name> <command...>
  echo "==> $1"
  if "${@:2}"; then echo "ok   $1"; else echo "FAIL $1"; failed+=("$1"); fi
}

if wanted yaml; then
  need yamllint
  step yaml yamllint --strict .
fi

if wanted lint; then
  need ansible-lint
  # Deterministic lint environment, independent of the caller's ansible.cfg (the lab config
  # points roles_path at /lab/work/roles, i.e. at the learner's own role):
  # - 4.04 has an encrypted vault.yml; its lab-only password ships with the solution.
  # - 5.02 uses the role 'cis' that the learner built in 5.01 -> lint against the 5.01
  #   reference role. Without this, ansible resolves 'cis' relative to the working
  #   directory and picks up the catalogue directory cis/ as an (empty) role.
  #   Solutions that bring their own roles/ (3.01, 4.03, 5.01) still use those first.
  step lint env -u ANSIBLE_CONFIG \
    ANSIBLE_VAULT_PASSWORD_FILE="$ROOT/exercises/stage4-advanced/4.04-vault-break-glass-account/solution/.vault-pass" \
    ANSIBLE_ROLES_PATH="$ROOT/exercises/stage5-capstone/5.01-capstone-cis-role/solution/roles" \
    ansible-lint --profile production --nocolor exercises/*/*/solution
fi

for c in meta parity links controls; do
  wanted "$c" || continue
  need python3
  step "$c" python3 tools/static_check.py "$c"
done

echo
if [[ ${#failed[@]} -eq 0 ]]; then
  echo "static check OK (${want[*]})"
else
  echo "static check FAILED: ${failed[*]}"
  exit 1
fi
