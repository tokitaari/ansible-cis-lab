#!/usr/bin/env bash
# Stage the reference solution of an exercise into a work directory, so that 'lab check'
# can verify the solution itself (state checks + idempotency) - used by CI.
#   tools/stage-solution.sh <id> <work-dir>
# Layout, the same a learner builds:
#   solution/*              -> <work-dir>/<id>/        (replaced)
#   solution/roles/<name>/  -> <work-dir>/roles/<name>/ (replaced; 5.02 has none and uses
#                              the role staged with 5.01 - see 'requires' in meta.yml)
# Then, inside the control node (ANSIBLE_ROLES_PATH so that the solve run finds the staged roles;
# 'lab' derives it from LAB_WORK_DIR itself):
#   export LAB_WORK_DIR=<work-dir> ANSIBLE_ROLES_PATH=<work-dir>/roles:/lab/ansible/roles
#   (cd <work-dir>/<id> && <solve command from meta.yml>) && lab check <id>
# Refuses the lab's own work/ directory - it holds the learner's files.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

id="${1:-}" wd="${2:-}"
[[ -n "$id" && -n "$wd" ]] || { echo "usage: $0 <id> <work-dir>" >&2; exit 2; }
# The id becomes part of paths that are removed below - accept only '<stage>.<NN>'
# (e.g. 3.01), never '..' or '/'.
[[ "$id" =~ ^[0-9]\.[0-9]{2}$ ]] || { echo "invalid exercise id '$id' (expected e.g. 3.01)" >&2; exit 2; }

ex=""
for d in "$ROOT"/exercises/stage*/"$id"-*; do [[ -d "$d" ]] && ex="$d"; done
[[ -n "$ex" ]] || { echo "unknown exercise '$id'" >&2; exit 2; }
[[ -d "$ex/solution" ]] || { echo "$id has no solution/ directory" >&2; exit 2; }

mkdir -p "$wd"
wd="$(cd "$wd" && pwd)"
if [[ "$wd" == "$ROOT/work" || "$wd" == /lab/work ]]; then
  echo "refusing to stage into the learner work directory $wd - use a temporary one" >&2
  exit 2
fi

rm -rf "${wd:?}/$id"
mkdir -p "$wd/$id"
tar -C "$ex/solution" --exclude=./roles -cf - . | tar -C "$wd/$id" -xf -
if [[ -d "$ex/solution/roles" ]]; then
  for r in "$ex/solution/roles"/*/; do
    [[ -d "$r" ]] || continue
    name="$(basename "$r")"
    rm -rf "${wd:?}/roles/$name"
    mkdir -p "$wd/roles"
    cp -a "$r" "$wd/roles/$name"
    echo "staged role  $wd/roles/$name"
  done
fi
echo "staged $id   $wd/$id"
solve="$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["solve"])' "$ex/meta.yml")"
echo "next:  export LAB_WORK_DIR=$wd ANSIBLE_ROLES_PATH=$wd/roles:$ROOT/ansible/roles"
echo "       (cd $wd/$id && $solve) && lab check $id"
