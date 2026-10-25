#!/usr/bin/env bash
# Check 4.02 - black-box contract test (check mode only, host debian)
set -u
site=/lab/work/4.02/site.yml
[[ -f "$site" ]] || { echo "FAIL: $site not found"; exit 1; }
cd /lab/work/4.02 || exit 1

run() { # run <name> <extra-vars-json> -> writes /tmp/lab-402-<name>.json, returns rc
  ANSIBLE_STDOUT_CALLBACK=ansible.posix.json ANSIBLE_NOCOLOR=1 \
    ansible-playbook site.yml -l debian --check -e "$2" > "/tmp/lab-402-$1.json" 2>"/tmp/lab-402-$1.err"
}

run level1   '{"cis_level": 1, "cis_exceptions": []}';                 rc1=$?
run level2   '{"cis_level": 2, "cis_exceptions": []}';                 rc2=$?
run except   '{"cis_level": 2, "cis_exceptions": [{"id": "l2-modules", "reason": "lab test", "expires": "2099-12-31"}]}'; rc3=$?
run expired  '{"cis_level": 1, "cis_exceptions": [{"id": "l1-telnet", "reason": "old", "expires": "2001-01-01"}]}'; rc4=$?
run noreason '{"cis_level": 1, "cis_exceptions": [{"id": "l1-telnet", "reason": "", "expires": "2099-12-31"}]}'; rc5=$?

python3 - "$rc1" "$rc2" "$rc3" "$rc4" "$rc5" <<'PY'
import json, sys
rc = list(map(int, sys.argv[1:]))
ok = True

def tasks(name):
    with open(f"/tmp/lab-402-{name}.json") as fh:
        txt = fh.read()
    data = json.loads(txt[txt.index("{"):])
    out = {}
    for play in data.get("plays", []):
        for t in play.get("tasks", []):
            h = t.get("hosts", {}).get("debian")
            if h is None:
                continue
            name = t["task"]["name"].split(" : ", 1)[-1]   # drop "role : " prefix
            out.setdefault(name, []).append(bool(h.get("skipped")))
    return out

def ran(ts, prefix):
    sel = [v for n, vs in ts.items() if n.lower().startswith(prefix) for v in vs]
    return None if not sel else not all(sel)

def expect(cond, msg):
    global ok
    print(("  ok   " if cond else "  FAIL ") + msg)
    ok = ok and cond

for i, name in enumerate(["level1", "level2", "except"]):
    expect(rc[i] == 0, f"run '{name}' succeeds (see /tmp/lab-402-{name}.err)")
expect(rc[3] != 0, "an expired exception makes the run fail")
expect(rc[4] != 0, "an exception without reason makes the run fail")

if all(r == 0 for r in rc[:3]):
    l1, l2, ex = tasks("level1"), tasks("level2"), tasks("except")
    expect(ran(l1, "l1-telnet") is True, "level 1: l1-telnet runs")
    expect(ran(l1, "l1-ssh-maxauthtries") is True, "level 1: l1-ssh-maxauthtries runs")
    expect(ran(l1, "l2-modules") in (False, None) and ran(l1, "l2-audit-identity") in (False, None),
           "level 1: no l2-* task runs")
    expect(ran(l2, "l2-modules") is True and ran(l2, "l2-audit-identity") is True, "level 2: l2-* tasks run")
    expect(ran(ex, "l2-modules") is False, "exception for l2-modules skips its tasks")
    expect(ran(ex, "l2-audit-identity") is True, "other level 2 controls still run")
sys.exit(0 if ok else 1)
PY
