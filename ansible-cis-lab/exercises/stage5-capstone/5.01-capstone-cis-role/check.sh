#!/usr/bin/env bash
# Check 5.01 - capstone acceptance (expects that you already ran enforce mode)
set -u
role=/lab/work/roles/cis
site=/lab/work/5.01/site.yml
report=/lab/work/5.01/reports/compliance.json
rc=0
fail() { echo "FAIL: $*"; rc=1; }

[[ -f "$site" ]] || { fail "missing $site"; exit 1; }

echo "--- ansible-lint (production)"
ansible-lint --offline --profile production -q "$role" || fail "ansible-lint production profile reported problems"

echo "--- regression checks (state after enforce)"
bash /lab/exercises/_common/run_checks.sh 0.04 1.01 1.02 1.03 1.04 1.05 2.01 2.02 2.03 2.04 2.05 2.06 3.02 3.03 3.05 -- "$@" || rc=1

echo "--- audit run must change nothing and report no failures"
out="$(cd /lab/work/5.01 && ANSIBLE_NOCOLOR=1 ansible-playbook site.yml -e cis_mode=audit "$@" 2>&1)" || {
  printf '%s\n' "$out" | tail -n 30; fail "audit run failed"; }
if printf '%s\n' "$out" | sed -n '/PLAY RECAP/,$p' | grep -E '^[a-z]+ +:' | grep -v '^localhost' | grep -Ev 'changed=0 '; then
  fail "audit mode changed something on the hosts above"
fi

[[ -f "$report" ]] || fail "missing $report"
if [[ -f "$report" ]]; then
  python3 - "$report" <<'PY' || rc=1
import json, sys
rep = json.load(open(sys.argv[1]))
ok = True
for host, s in sorted(rep.items()):
    fails = [f["id"] for f in s.get("findings", []) if f.get("status") == "fail"]
    need = {"mode", "level", "counts", "findings"} - set(s)
    if need or s.get("mode") != "audit" or fails or len(s.get("findings", [])) < 14:
        ok = False
        print(f"  FAIL {host}: mode={s.get('mode')} missing={sorted(need)} failing={fails} findings={len(s.get('findings', []))}")
    else:
        print(f"  ok   {host}: {s['counts']}")
if len(rep) != 8:
    ok = False
    print(f"  FAIL report covers {len(rep)} hosts, expected 8")
sys.exit(0 if ok else 1)
PY
fi
exit $rc
