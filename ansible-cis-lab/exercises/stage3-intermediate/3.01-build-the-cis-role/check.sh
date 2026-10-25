#!/usr/bin/env bash
# Check 3.01 - role structure, lint and the state checks of 0.04-2.06
set -u
role=/lab/work/roles/cis
site=/lab/work/3.01/site.yml
rc=0
fail() { echo "FAIL: $*"; rc=1; }

echo "--- structure"
for f in tasks/main.yml defaults/main.yml handlers/main.yml meta/main.yml \
         tasks/section1_initial_setup.yml tasks/section2_services.yml \
         tasks/section3_network.yml tasks/section5_access_control.yml \
         tasks/section7_maintenance.yml; do
  [[ -f "$role/$f" ]] || fail "missing $role/$f"
done
compgen -G "$role/vars/*.yml" >/dev/null || fail "no platform vars in $role/vars/"
[[ -f "$site" ]] || fail "missing $site"

if [[ -f "$site" ]]; then
  echo "--- tags"
  tags="$(cd /lab/work/3.01 && ansible-playbook site.yml --list-tags 2>&1)"
  for t in section1 section2 section3 section5 section7 ssh sudo cron sysctl; do
    grep -qw "$t" <<<"$tags" || fail "tag '$t' not found in --list-tags"
  done
fi

if [[ -d "$role" ]]; then
  echo "--- ansible-lint (moderate)"
  ansible-lint --offline --profile moderate -q "$role" || fail "ansible-lint reported problems"
fi

echo "--- state checks 0.04 ... 2.06"
bash /lab/exercises/_common/run_checks.sh 0.04 1.01 1.02 1.03 1.04 1.05 2.01 2.02 2.03 2.04 2.05 2.06 -- "$@" || rc=1
exit $rc
