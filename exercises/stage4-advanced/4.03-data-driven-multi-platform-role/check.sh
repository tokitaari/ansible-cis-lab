#!/usr/bin/env bash
# Check 4.03 - data-driven role, lint, regression checks
set -u
role=/lab/work/roles/cis
rc=0
fail() { echo "FAIL: $*"; rc=1; }

[[ -f /lab/work/4.03/site.yml ]] || fail "missing /lab/work/4.03/site.yml"
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
bash /lab/exercises/_common/run_checks.sh 0.04 1.01 1.02 1.03 1.04 1.05 2.01 2.02 2.03 2.04 2.05 2.06 3.02 3.03 3.05 -- "$@" || rc=1
exit $rc
