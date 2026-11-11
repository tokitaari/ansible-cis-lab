#!/usr/bin/env bash
# Runtime test of the reference solutions on the eight targets - used by CI
# (.github/workflows/runtime.yml, one job per stage) and by maintainers on their own lab.
#
#   tools/run-solutions.sh [options] <spec>...
#
# Runs on the HOST (it needs docker compose), with the lab up (./lab.sh up). Every run:
#   1. ./lab.sh reset all, then wait until every target answers over SSH
#   2. prerequisites: the exercises in meta 'requires' (transitive), staged and solved
#   3. tools/stage-solution.sh into a work directory in the control node, the meta 'solve'
#      command there, then 'lab check' (state checks + its idempotency test with --check)
#   4. 'idempotency: true': a real second solve run must change nothing on any target
#      (--check skips command/shell tasks, so the lab's own test cannot see them)
#
# spec:
#   stage<N>    the solo runs of stage N in id order, plus the extra level runs below; the
#               cumulative and the skipped exercises are listed as SKIPPED
#   solo        stage0 ... stage5
#   <id>        one exercise, e.g. 2.03 (a cumulative one gets its prerequisites first)
#   <id>@2      the same with -e cis_level=2 for solve and check
# options:
#   --yes           do not ask before resetting the targets (CI)
#   --no-rerun      leave out the real second run
#   --timeout <s>   limit per run in seconds (default 900; 4.08: 2400)
#   --logs <dir>    log directory (default ${RUNNER_TEMP:-/tmp}/lab-runs/<timestamp>)
#   --list          print the planned runs and exit (no Docker needed)
#
# Result per run: PASSED, SKIPPED (<reason>) or FAIL (reset|ssh|prereq|stage|solve|check|rerun|
# timeout), with the targets that failed or changed; exit code 1 if a run failed. With
# GITHUB_STEP_SUMMARY set, a Markdown table is appended to it. ./work stays untouched (the work
# directory is /tmp/lab-run-work in the control node) and so does 'lab progress' (LAB_STATE_DIR).
set -uo pipefail

# --- run policy --------------------------------------------------------------------------------
# Cumulative: their checks run the checks of earlier exercises against the role that grows from
# 3.01 to 5.01 (5.02 rolls that role out) - not solo runs.
CHAIN=(3.01 4.03 5.01 5.02)
# No runnable reference solution
declare -A SKIP=([5.03]="no reference solution: self-assessed review")
# Extra runs at CIS level 2, right after the level 1 run of the same exercise
EXTRA=(2.03@2)
# Seconds per run. Measured on WSL2 (2026-11-11): at most 218 s (4.08 builds the AIDE database,
# async for up to 1800 s).
TIMEOUT_DEFAULT=900
declare -A TIMEOUT=([4.08]=2400)
# Extra arguments for 'lab check' ({wd} = the work directory)
declare -A CHECK_ARGS=([4.04]="--vault-password-file {wd}/4.04/.vault-pass")
# -------------------------------------------------------------------------------------------------

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
SELF_IN_CONTROL=/lab/tools/run-solutions.sh   # the repository is mounted at /lab
WD=/tmp/lab-run-work                          # in the control node
STATE=/tmp/lab-run-state                      # LAB_STATE_DIR for 'lab' in the control node
TARGETS=(debian ubuntu rocky alma fedora opensuse arch alpine)

die() { echo "run-solutions: $*" >&2; exit 2; }
in_list() { local x="$1" y; shift; for y in "$@"; do [[ "$x" == "$y" ]] && return 0; done; return 1; }
exdir() { local d; for d in "$ROOT"/exercises/stage*/"$1"-*; do [[ -d "$d" ]] && { echo "$d"; return 0; }; done; return 1; }

# =================================================================================================
# Part 1 - inside the control node: one run (called by part 2 via docker compose exec)
# =================================================================================================
meta_get() { # meta_get <exercise dir> <key>
  python3 -c 'import sys, yaml
v = (yaml.safe_load(open(sys.argv[1])) or {}).get(sys.argv[2])
print("true" if v is True else "false" if v is False else "" if v is None else v)' "$1/meta.yml" "$2"
}

requires_of() { # transitive 'requires' of <id>, prerequisites first
  python3 - "$ROOT" "$1" <<'PY'
import glob, sys, yaml
meta = {}
for f in glob.glob(f"{sys.argv[1]}/exercises/stage*/*/meta.yml"):
    m = yaml.safe_load(open(f))
    meta[str(m["id"])] = m
out = []
def visit(i):
    for r in map(str, meta[i].get("requires") or []):
        if r not in out:
            visit(r)
            out.append(r)
visit(sys.argv[2])
print(" ".join(out))
PY
}

# hosts_in <mode> <log...>: targets of the PLAY RECAP lines with failed/unreachable > 0
# (mode 'changed': also changed > 0); localhost is not a target
hosts_in() {
  local mode="$1"; shift
  cat "$@" 2>/dev/null | grep -E '^[^ ]+[[:space:]]+:[[:space:]]+ok=' | grep -Ev '^localhost[[:space:]]' |
    awk -v mode="$mode" '{ bad = 0
      for (i = 2; i <= NF; i++) { split($i, kv, "=")
        if ((kv[1] == "failed" || kv[1] == "unreachable" || (mode == "changed" && kv[1] == "changed")) && kv[2] + 0 > 0) bad = 1 }
      if (bad) print $1 }' | sort -u | tr '\n' ' '
}
mark_hosts() { local h; h="$(hosts_in "$@")"; [[ -n "$h" ]] && echo "@@ hosts $h"; return 0; }
phase() { echo; echo "=== $* (+${SECONDS} s)"; }

in_control() { # in_control <id> <level 1|2> <rerun 0|1>  -> 0 or 10 prereq 11 stage 12 solve 13 check 14 rerun
  local id="$1" lvl="$2" rerun="$3" d solve idem extra cargs r rd rs rc f
  export LAB_WORK_DIR="$WD" ANSIBLE_ROLES_PATH="$WD/roles:$ROOT/ansible/roles"
  export LAB_STATE_DIR="$STATE" ANSIBLE_NOCOLOR=1 ANSIBLE_FORCE_COLOR=0
  rm -rf "${WD:?}" "${LAB_STATE_DIR:?}" /tmp/lab-check-*.log /tmp/lab-402-* /tmp/lab-502-* /tmp/lab-run-*.log
  mkdir -p "$WD" "$LAB_STATE_DIR"
  d="$(exdir "$id")" || { echo "unknown exercise $id"; return 11; }

  for r in $(requires_of "$id"); do
    phase "prerequisite $r"
    rd="$(exdir "$r")" && rs="$(meta_get "$rd" solve)" || return 10
    "$ROOT/tools/stage-solution.sh" "$r" "$WD" || return 10
    (cd "$WD/$r" && bash -c "$rs" </dev/null) 2>&1 | tee "/tmp/lab-run-prereq-$r.log"
    rc=${PIPESTATUS[0]}
    [[ $rc -eq 0 ]] || { mark_hosts failed "/tmp/lab-run-prereq-$r.log"; return 10; }
  done

  solve="$(meta_get "$d" solve)"; idem="$(meta_get "$d" idempotency)"
  extra=""; [[ "$lvl" == 2 ]] && extra="-e cis_level=2"
  cargs="$extra ${CHECK_ARGS[$id]:-}"; cargs="${cargs//\{wd\}/$WD}"

  phase "stage $id"
  "$ROOT/tools/stage-solution.sh" "$id" "$WD" || return 11

  phase "solve: $solve $extra"
  (cd "$WD/$id" && bash -c "$solve $extra" </dev/null) 2>&1 | tee /tmp/lab-run-solve.log
  rc=${PIPESTATUS[0]}
  [[ $rc -eq 0 ]] || { mark_hosts failed /tmp/lab-run-solve.log; return 12; }

  phase "check: lab check $id $cargs"
  # shellcheck disable=SC2086  # cargs holds several words on purpose
  lab check "$id" $cargs </dev/null 2>&1 | tee /tmp/lab-run-check.log
  rc=${PIPESTATUS[0]}
  if [[ $rc -ne 0 ]]; then
    for f in /tmp/lab-check-*.log; do [[ -f "$f" ]] && { echo "--- $f"; cat "$f"; }; done
    mark_hosts failed /tmp/lab-run-check.log /tmp/lab-check-*.log
    return 13
  fi

  if [[ "$idem" == true && "$rerun" == 1 ]]; then
    phase "rerun (must change nothing): $solve $extra"
    (cd "$WD/$id" && bash -c "$solve $extra" </dev/null) 2>&1 | tee /tmp/lab-run-rerun.log
    rc=${PIPESTATUS[0]}
    if [[ $rc -ne 0 || -n "$(hosts_in changed /tmp/lab-run-rerun.log)" ]]; then
      mark_hosts changed /tmp/lab-run-rerun.log
      return 14
    fi
  fi
  phase "done"
  return 0
}

if [[ "${1:-}" == --in-control ]]; then
  [[ $# -eq 4 ]] || die "usage: $0 --in-control <id> <level> <rerun>"
  in_control "$2" "$3" "$4"
  exit $?
fi

# =================================================================================================
# Part 2 - on the host: plan, reset, run, summary
# =================================================================================================
usage() { sed -n '2,/^set -uo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

YES=0 RERUN=1 LIST=0 OPT_TIMEOUT="" LOGS=""
specs=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) YES=1 ;;
    --no-rerun) RERUN=0 ;;
    --list) LIST=1 ;;
    --timeout) [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || die "--timeout needs seconds"; OPT_TIMEOUT="$2"; shift ;;
    --logs) [[ -n "${2:-}" ]] || die "--logs needs a directory"; LOGS="$2"; shift ;;
    -h|--help) usage 0 ;;
    -*) die "unknown option '$1' (see --help)" ;;
    *) specs+=("$1") ;;
  esac
  shift
done
[[ ${#specs[@]} -gt 0 ]] || usage 2

P_KIND=() P_SPEC=() P_NOTE=()
add() { # add <run|skip> <spec> [note]; a spec is planned once
  in_list "$2" "${P_SPEC[@]}" && return 0
  P_KIND+=("$1"); P_SPEC+=("$2"); P_NOTE+=("${3:-}")
}
ids_of_stage() { local d; for d in "$ROOT"/exercises/stage"$1"-*/[0-9].[0-9][0-9]-*/; do [[ -d "$d" ]] && basename "$d" | cut -d- -f1; done; }
plan_spec() {
  local s="$1" n id e ids
  case "$s" in
    solo) for n in 0 1 2 3 4 5; do plan_spec "stage$n"; done ;;
    stage[0-9])
      ids="$(ids_of_stage "${s#stage}")"
      [[ -n "$ids" ]] || die "no exercises in $s"
      for id in $ids; do
        if [[ -n "${SKIP[$id]:-}" ]]; then add skip "$id" "${SKIP[$id]}"
        elif in_list "$id" "${CHAIN[@]}"; then add skip "$id" "cumulative exercise, not a solo run"
        else
          add run "$id"
          for e in "${EXTRA[@]}"; do [[ "${e%@*}" == "$id" ]] && add run "$e"; done
        fi
      done ;;
    [0-9].[0-9][0-9] | [0-9].[0-9][0-9]@2)
      id="${s%@2}"
      exdir "$id" >/dev/null || die "unknown exercise '$id'"
      if [[ -n "${SKIP[$id]:-}" ]]; then add skip "$s" "${SKIP[$id]}"; else add run "$s"; fi ;;
    *) die "unknown spec '$s' (stage0 ... stage5, solo, <id>, <id>@2)" ;;
  esac
}
for s in "${specs[@]}"; do plan_spec "$s"; done
timeout_of() { local id="${1%@2}"; echo "${OPT_TIMEOUT:-${TIMEOUT[$id]:-$TIMEOUT_DEFAULT}}"; }

if [[ $LIST -eq 1 ]]; then
  for i in "${!P_SPEC[@]}"; do
    if [[ "${P_KIND[$i]}" == run ]]; then printf 'run   %-7s timeout %s s\n' "${P_SPEC[$i]}" "$(timeout_of "${P_SPEC[$i]}")"
    else printf 'skip  %-7s %s\n' "${P_SPEC[$i]}" "${P_NOTE[$i]}"; fi
  done
  exit 0
fi

cd "$ROOT" || exit 2
ctl() { docker compose exec -T -u learner -e "LAB_STATE_DIR=$STATE" control "$@"; }
running="$(docker compose ps --status running -q 2>/dev/null | wc -l)"
[[ "$running" -eq $((${#TARGETS[@]} + 1)) ]] \
  || die "the lab is not up ($running of $((${#TARGETS[@]} + 1)) containers running) - ./lab.sh up first"

if [[ $YES -eq 0 ]]; then
  [[ -t 0 ]] || die "every run resets all targets - pass --yes when there is no terminal to ask"
  echo "Every run resets all ${#TARGETS[@]} targets: their state is lost (./work and lab progress are kept)."
  read -r -p "Continue? [y/N] " a
  [[ "$a" =~ ^[yY] ]] || exit 0
fi

LOGS="${LOGS:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/lab-runs/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOGS" || die "cannot create $LOGS"
{
  echo "commit  $(git -C "$ROOT" log -1 --format='%h %s' 2>/dev/null || echo unknown)"
  echo "host    kernel $(uname -r), $(stat -fc %T /sys/fs/cgroup), $(nproc) CPUs"
  echo "docker  $(docker version --format '{{.Server.Version}}' 2>&1), compose $(docker compose version --short 2>&1)"
  echo "ansible $(ctl ansible --version </dev/null 2>&1 | head -n 1)"
  echo "specs   ${specs[*]}"
} | tee "$LOGS/env.txt"
echo

wait_ssh() {
  local _
  for _ in $(seq 1 60); do
    ctl ansible targets -m ansible.builtin.raw -a true </dev/null >/dev/null 2>&1 && return 0
    sleep 3
  done
  ctl ansible targets -m ansible.builtin.raw -a true </dev/null   # once more, into the log
  return 1
}
diagnose() {
  echo "--- docker compose ps -a"; docker compose ps -a
  echo "--- docker compose logs (targets, last 60 lines each)"; docker compose logs --no-color --tail 60 "${TARGETS[@]}"
}

R_RES=() R_SEC=() R_HOSTS=()
failed=0 passed=0 skipped=0 start=$SECONDS
for i in "${!P_SPEC[@]}"; do
  spec="${P_SPEC[$i]}"
  if [[ "${P_KIND[$i]}" == skip ]]; then
    R_RES+=("SKIPPED (${P_NOTE[$i]})"); R_SEC+=("-"); R_HOSTS+=("")
    skipped=$((skipped + 1))
    printf '%-7s %s\n' "$spec" "${R_RES[-1]}"
    continue
  fi
  id="${spec%@2}" lvl=1; [[ "$spec" == *@2 ]] && lvl=2
  t="$(timeout_of "$spec")"
  f="$LOGS/${spec/@/-L}.log"
  t0=$SECONDS
  echo "### $spec ($(date '+%F %T'), timeout $t s)" >"$f"
  if ! ./lab.sh reset all >>"$f" 2>&1; then
    res="FAIL (reset)"; diagnose >>"$f" 2>&1
  elif ! wait_ssh >>"$f" 2>&1; then
    res="FAIL (ssh)"; diagnose >>"$f" 2>&1
  else
    echo "=== targets ready after $((SECONDS - t0)) s" >>"$f"
    ctl timeout -k 30 "$t" bash "$SELF_IN_CONTROL" --in-control "$id" "$lvl" "$RERUN" </dev/null >>"$f" 2>&1
    rc=$?
    case $rc in
      0) res="PASSED" ;;
      10) res="FAIL (prereq)" ;;
      11) res="FAIL (stage)" ;;
      12) res="FAIL (solve)" ;;
      13) res="FAIL (check)" ;;
      14) res="FAIL (rerun)" ;;
      124 | 137) res="FAIL (timeout $t s)"; echo "=== stopped after the timeout of $t s" >>"$f" ;;
      *) res="FAIL (rc=$rc)" ;;
    esac
  fi
  hosts="$(sed -n 's/^@@ hosts //p' "$f" | tail -n 1)"
  R_RES+=("$res"); R_SEC+=("$((SECONDS - t0))"); R_HOSTS+=("${hosts% }")
  if [[ "$res" == PASSED ]]; then passed=$((passed + 1)); else failed=$((failed + 1)); fi
  printf '%-7s %-22s %5ss  %s\n' "$spec" "$res" "${R_SEC[-1]}" "${R_HOSTS[-1]}"
done

total=$((SECONDS - start))
line="$((passed + failed)) runs: $passed passed, $failed failed; $skipped skipped; $((total / 60))m$((total % 60))s"
{
  printf '%-7s %-22s %6s  %s\n' run result time hosts
  for i in "${!P_SPEC[@]}"; do
    printf '%-7s %-22s %6s  %s\n' "${P_SPEC[$i]}" "${R_RES[$i]}" "${R_SEC[$i]}" "${R_HOSTS[$i]}"
  done
  echo "$line"
} >"$LOGS/summary.txt"
echo; echo "$line"; echo "logs: $LOGS"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Reference solutions: ${specs[*]}"
    echo
    echo "| Run | Result | Seconds | Targets |"
    echo "|---|---|---:|---|"
    for i in "${!P_SPEC[@]}"; do
      echo "| ${P_SPEC[$i]} | ${R_RES[$i]} | ${R_SEC[$i]} | ${R_HOSTS[$i]} |"
    done
    echo
    echo "$line"
  } >>"$GITHUB_STEP_SUMMARY"
fi
[[ $failed -eq 0 ]]
