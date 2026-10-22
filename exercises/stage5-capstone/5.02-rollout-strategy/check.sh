#!/usr/bin/env bash
# Check 5.02 - structure and gate behaviour (check mode only)
set -u
pb=/lab/work/5.02/rollout.yml
[[ -f "$pb" ]] || { echo "FAIL: $pb not found"; exit 1; }
rc=0
python3 - "$pb" <<'PY' || rc=1
import sys, yaml
plays = yaml.safe_load(open(sys.argv[1]))
ok = True
def expect(cond, msg):
    global ok
    print(("  ok   " if cond else "  FAIL ") + msg); ok = ok and bool(cond)
expect(isinstance(plays, list) and len(plays) >= 3, "at least three plays (preflight, canary, batches)")
expect(plays and plays[0].get("any_errors_fatal") is True, "play 1 uses any_errors_fatal: true")
batch = [p for p in plays if p.get("serial")]
expect(batch, "a play uses serial")
expect(batch and isinstance(batch[0].get("serial"), list) and len(batch[0]["serial"]) >= 2, "serial grows in steps (list)")
expect(batch and str(batch[0].get("max_fail_percentage")) == "0", "batch play has max_fail_percentage: 0")
text = open(sys.argv[1]).read()
expect("cis_rollout_confirm" in text, "confirmation variable cis_rollout_confirm is used")
sys.exit(0 if ok else 1)
PY

cd /lab/work/5.02 || exit 1
if ANSIBLE_NOCOLOR=1 ansible-playbook rollout.yml --check "$@" >/tmp/lab-502-noconfirm.log 2>&1; then
  echo "  FAIL running without -e cis_rollout_confirm=true must fail (see /tmp/lab-502-noconfirm.log)"; rc=1
else
  if grep -q "cis_rollout_confirm" /tmp/lab-502-noconfirm.log; then
    echo "  ok   refuses to run without confirmation"
  else
    echo "  FAIL the run failed, but not because of the missing confirmation (see /tmp/lab-502-noconfirm.log)"; rc=1
  fi
fi
exit $rc
