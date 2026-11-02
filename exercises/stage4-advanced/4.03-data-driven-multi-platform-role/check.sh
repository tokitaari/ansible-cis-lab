#!/usr/bin/env bash
# Check 4.03 - data-driven role, lint, regression checks
set -u
work="${LAB_WORK_DIR:-/lab/work}"   # set by lab; CI checks solutions in another work dir
role="$work/roles/cis"
rc=0
fail() { echo "FAIL: $*"; rc=1; }

[[ -f "$work/4.03/site.yml" ]] || fail "missing $work/4.03/site.yml"
for f in section5_password_policy.yml section5_pam.yml section5_accounts.yml section6_logging.yml; do
  [[ -f "$role/tasks/$f" ]] || fail "missing $role/tasks/$f"
done

echo "--- fact comparisons in task files"
if grep -rnE "(os_family|distribution)[^|]*(==|!=|[[:space:]]in[[:space:]])" "$role/tasks" 2>/dev/null \
     | grep -v 'first_found' | grep -vE '^\S+:[0-9]+:\s*#' | grep -vE '\.yml"?\s*$'; then
  fail "replace the fact comparisons above with values/flags from vars/"
fi
grep -q "distribution_major_version" "$role/tasks/main.yml" 2>/dev/null \
  || fail "tasks/main.yml should look up <distribution>-<major>.yml first"

echo "--- ansible-lint"
ansible-lint --offline --profile moderate -q "$role" || fail "ansible-lint reported problems"

echo "--- regression checks"
. "${LAB_ROOT:-/lab}/exercises/_common/cis_level.sh"
read -ra ids <<<"$(regression_ids "$@")"
bash "${LAB_ROOT:-/lab}/exercises/_common/run_checks.sh" "${ids[@]}" -- "$@" || rc=1
level_note 4.03 "$@"
exit $rc
