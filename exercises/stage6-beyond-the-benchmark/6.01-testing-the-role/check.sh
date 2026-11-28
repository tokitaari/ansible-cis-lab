#!/usr/bin/env bash
# Check 6.01 - your Molecule scenario tests the role cis_mini: 'molecule test' passes on all eight
# targets, the role meets the requirements, and your tests fail on targets that break them.
# The last step breaks one requirement on six targets on purpose and converges them again.
set -u
work="${LAB_WORK_DIR:-/lab/work}"   # set by lab; CI checks solutions in another work dir
proj="$work/6.01"
scen="$proj/molecule/default"
role="$work/roles/cis_mini"
tmp="$(mktemp -d /tmp/lab-601-XXXXXX)"
rc=0
fail() { echo "FAIL: $*"; rc=1; }
nocolor() { sed 's/\x1b\[[0-9;]*m//g'; }
export ANSIBLE_NOCOLOR=1 ANSIBLE_FORCE_COLOR=0 NO_COLOR=1 PY_COLORS=0

if ! command -v molecule >/dev/null || ! command -v pytest >/dev/null; then
  fail "molecule or pytest not found - rebuild the control node on the host:"
  echo "      docker compose build control && docker compose up -d --force-recreate control"
  exit 1
fi
[[ -d "$role" ]] || { fail "missing $role (lab start 6.01 copies it there)"; exit 1; }
[[ -f "$scen/molecule.yml" ]] || { fail "missing $scen/molecule.yml"; exit 1; }

echo "--- the scenario"
python3 - "$scen" <<'PY' || exit 1
import glob, os, sys, yaml
scen = sys.argv[1]
cfg = yaml.safe_load(open(os.path.join(scen, "molecule.yml"))) or {}
verifier = cfg.get("verifier") or {}
problems = []
if verifier.get("name") != "testinfra":
    problems.append("molecule.yml: the verifier must be testinfra (verifier: name: testinfra)")
tdir = os.path.join(scen, verifier.get("directory", "tests"))
if not glob.glob(os.path.join(tdir, "**", "test_*.py"), recursive=True):
    problems.append(f"no test_*.py in {tdir}")
seq = (cfg.get("scenario") or {}).get("test_sequence")
if seq is not None:
    missing = [s for s in ("converge", "idempotence", "verify") if s not in seq]
    if missing:
        problems.append(f"test_sequence lacks {', '.join(missing)} - 'molecule test' must "
                        "converge, run the idempotence step and verify")
    elif not seq.index("converge") < seq.index("idempotence") < seq.index("verify"):
        problems.append("test_sequence: converge, idempotence and verify must come in this order")
for p in problems:
    print(f"FAIL: {p}")
if not problems:
    print("  ok   molecule.yml (testinfra, sequence) and tests/test_*.py")
sys.exit(1 if problems else 0)
PY

# junit_hosts <junit file> -> one line per host: "<host> <passed> <failed>" (skipped not counted)
junit_hosts() {
  python3 - "$1" <<'PY'
import re, sys, xml.etree.ElementTree as ET
count = {}
for tc in ET.parse(sys.argv[1]).iter("testcase"):
    m = re.search(r"\[ansible://([A-Za-z0-9_.]+)", tc.get("name", ""))
    kinds = {c.tag for c in tc}
    if not m or "skipped" in kinds:
        continue
    c = count.setdefault(m.group(1), [0, 0])
    c[1 if kinds & {"failure", "error"} else 0] += 1
for host, (p, f) in sorted(count.items()):
    print(host, p, f)
PY
}
counts() { grep "^$2 " "$1" 2>/dev/null || echo "$2 0 0"; }
targets="$(ansible targets --list-hosts 2>/dev/null | tail -n +2 | tr -d ' ' | sort | tr '\n' ' ')"

echo "--- molecule test (the role as it is now, your tests)"
(cd "$proj" && PYTEST_ADDOPTS="--junitxml=$tmp/test.xml" molecule test) 2>&1 | nocolor >"$tmp/test.log"
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  grep -E '^CRITICAL|^ERROR|^FAILED|^\* ' "$tmp/test.log" | head -n 20 | sed 's/^/  /'
  fail "molecule test failed (full output: $tmp/test.log)"
  exit 1
fi
if [[ ! -s "$tmp/test.xml" ]]; then
  fail "molecule test passed, but no test ran (is verify in the sequence?) - see $tmp/test.log"
  exit 1
fi
junit_hosts "$tmp/test.xml" >"$tmp/test.hosts"
for h in $targets; do
  read -r _ p _ < <(counts "$tmp/test.hosts" "$h")
  if [[ "$p" -gt 0 ]]; then echo "  ok   $h: $p tests passed"
  else fail "$h: none of your tests ran on this target (testinfra: lab inventory, group targets)"; fi
done
[[ $rc -eq 0 ]] || exit 1

echo "--- the requirements on every target (checked here, independent of your tests)"
cat >"$tmp/req.yml" <<'EOF'
---
- name: Check 6.01 - requirements of cis_mini
  hosts: targets
  become: true
  gather_facts: true
  gather_subset: [min]
  vars:
    banner: "Authorized users only. All activity may be monitored and reported.\n"
    shadow:
      Debian: shadow 0640
      Suse: shadow 0640
      Alpine: shadow 0640
      RedHat: root 0000
      Archlinux: root 0600
  tasks:
    - name: Stat the files
      ansible.builtin.stat:
        path: "{{ item }}"
      loop: [/etc/passwd, /etc/group, /etc/shadow, /etc/gshadow, /etc/issue, /etc/issue.net]
      register: st
    - name: Read the banners
      ansible.builtin.slurp:
        src: "{{ item }}"
      loop: [/etc/issue, /etc/issue.net]
      register: txt
    - name: Owner, group and mode
      vars:
        want: "{{ 'root ' ~ shadow[ansible_facts.os_family] if 'shadow' in item.item else 'root root 0644' }}"
        have: "{{ item.stat.pw_name }} {{ item.stat.gr_name }} {{ item.stat.mode }}"
      ansible.builtin.assert:
        that: have == want
        fail_msg: "{{ item.item }} is {{ have }}, required: {{ want }}"
        quiet: true
      loop: "{{ st.results | selectattr('stat.exists') | list }}"
      loop_control:
        label: "{{ item.item }}"
    - name: Banner text
      ansible.builtin.assert:
        that: (item.content | b64decode) == banner
        fail_msg: "{{ item.source }} is not exactly the text of cis_mini_banner and one newline"
        quiet: true
      loop: "{{ txt.results }}"
      loop_control:
        label: "{{ item.source }}"
EOF
if ANSIBLE_LOAD_CALLBACK_PLUGINS=1 ANSIBLE_STDOUT_CALLBACK=ansible.posix.json \
   ansible-playbook "$tmp/req.yml" >"$tmp/req.json" 2>"$tmp/req.err"; then
  echo "  ok   every target meets the requirements"
else
  python3 - "$tmp/req.json" <<'PY' | sort | sed 's/^/  /'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except ValueError:
    sys.exit(0)
for play in data.get("plays", []):
    for task in play.get("tasks", []):
        for host, res in task.get("hosts", {}).items():
            items = [r for r in res.get("results", [])
                     if r.get("failed") or r.get("evaluated_to") is False] or \
                    ([res] if res.get("failed") or res.get("unreachable") else [])
            for r in items:
                print(f"{host}: {r.get('msg', '')}")
PY
  fail "the role does not meet the requirements (output: $tmp/req.json) - and your tests passed"
  exit 1
fi

echo "--- your tests on broken targets (one requirement broken on each of six targets)"
# host | what is broken | command (run as root)
mutants=(
  "debian|/etc/passwd mode 0664|chmod 0664 /etc/passwd"
  "arch|/etc/group owned by ansible|chown ansible /etc/group"
  "rocky|/etc/shadow mode 0640 (RedHat family: 0000)|chmod 0640 /etc/shadow"
  "opensuse|/etc/shadow group root (Suse family: shadow)|chgrp root /etc/shadow"
  "fedora|/etc/issue mode 0666|chmod 0666 /etc/issue"
  "alpine|/etc/issue.net names the system|echo 'Welcome to Alpine Linux' > /etc/issue.net"
)
broken=""
for m in "${mutants[@]}"; do
  IFS='|' read -r h _ cmd <<<"$m"
  if ansible "$h" -b -m ansible.builtin.shell -a "$cmd" >>"$tmp/mutate.log" 2>&1 </dev/null; then
    broken+="$h "
  else
    fail "could not break $h ($cmd) - see $tmp/mutate.log"
  fi
done
(cd "$proj" && PYTEST_ADDOPTS="--junitxml=$tmp/verify.xml" molecule verify) 2>&1 | nocolor >"$tmp/verify.log"
if [[ -s "$tmp/verify.xml" ]]; then
  junit_hosts "$tmp/verify.xml" >"$tmp/verify.hosts"
else
  : >"$tmp/verify.hosts"
  fail "molecule verify ran no test - see $tmp/verify.log"
fi
for m in "${mutants[@]}"; do
  IFS='|' read -r h what _ <<<"$m"
  read -r _ _ f < <(counts "$tmp/verify.hosts" "$h")
  if [[ "$f" -gt 0 ]]; then echo "  ok   $h: $what - $f test(s) failed"
  else fail "$h: $what - none of your tests noticed"; fi
done
for h in $targets; do
  [[ " $broken " == *" $h "* ]] && continue
  read -r _ _ f < <(counts "$tmp/verify.hosts" "$h")
  if [[ "$f" -eq 0 ]]; then echo "  ok   $h: nothing broken, no test failed"
  else fail "$h: nothing was broken there, but $f test(s) failed - see $tmp/verify.log"; fi
done

echo "--- restore the broken targets: molecule converge"
(cd "$proj" && molecule converge) 2>&1 | nocolor >"$tmp/converge.log"
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
  echo "  ok   converged"
else
  fail "molecule converge failed - see $tmp/converge.log"
fi
[[ $rc -eq 0 ]] && rm -rf "$tmp"
exit $rc
