#!/usr/bin/env bash
# Release hygiene check for the lab repository. Run before tagging a release:
#   tools/release-check.sh
# Checks the files TRACKED by git (what ends up in a release archive).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
rc=0
fail() { echo "FAIL: $*"; rc=1; }

tracked() { git ls-files -z | tr '\0' '\n'; }

# 1. no compiled Python / caches
bad=$(tracked | grep -E '(^|/)__pycache__/|\.py[co]$' || true)
[[ -z "$bad" ]] || fail "compiled Python files tracked:"$'\n'"$bad"

# 2. no nested copy of the repository (a second compose.yaml next to control/lab)
nested=$(tracked | grep -E '.+/control/lab$' | sed 's#/control/lab$##' || true)
[[ -z "$nested" ]] || fail "nested repository copy tracked: $nested/"

# 3. no archives, patches or merge leftovers
junk=$(tracked | grep -E '\.(zip|tgz|tar\.gz|patch|orig|rej)$' || true)
[[ -z "$junk" ]] || fail "archives / patch leftovers tracked:"$'\n'"$junk"

# 4. scripts are executable in the index
for f in lab.sh control/lab control/lab-view control/lab-lesspipe control/live-wrapper \
         control/entrypoint.sh targets/common/bootstrap.sh targets/common/lab-keysync \
         exercises/_common/run_checks.sh tools/release-check.sh; do
  [[ -e "$f" ]] || continue
  mode=$(git ls-files -s -- "$f" | awk '{print $1}')
  [[ "$mode" == 100755 ]] || fail "$f is not executable in git (mode ${mode:-untracked}) - git update-index --chmod=+x $f"
done

# 5. CHANGELOG has a release section for the version being tagged (optional arg)
if [[ -n "${1:-}" ]]; then
  grep -q "^## \[${1#v}\] - " CHANGELOG.md || fail "CHANGELOG.md has no section '## [${1#v}] - <date>'"
fi

[[ $rc -eq 0 ]] && echo "release check OK ($(tracked | wc -l) tracked files)"
exit $rc
