#!/usr/bin/env bash
# Release hygiene check for the lab repository. Run before tagging a release:
#   tools/release-check.sh
# Checks the files TRACKED by git (what ends up in a release archive).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
rc=0
fail() { echo "FAIL: $*"; rc=1; }
warn() { echo "WARN: $*"; [[ -z "${GITHUB_ACTIONS:-}" ]] || echo "::warning::$*"; return 0; }

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
         exercises/_common/run_checks.sh tools/release-check.sh tools/static-check.sh \
         tools/static_check.py tools/stage-solution.sh tools/run-solutions.sh; do
  [[ -e "$f" ]] || continue
  mode=$(git ls-files -s -- "$f" | awk '{print $1}')
  [[ "$mode" == 100755 ]] || fail "$f is not executable in git (mode ${mode:-untracked}) - git update-index --chmod=+x $f"
done

# 5. CHANGELOG has a release section for the version being tagged (optional arg)
if [[ -n "${1:-}" ]]; then
  grep -q "^## \[${1#v}\] - " CHANGELOG.md || fail "CHANGELOG.md has no section '## [${1#v}] - <date>'"
fi

# 6. warning only: control/requirements.txt changed since the last tag, but the changelog section
#    (the version's, else [Unreleased]) has no 'Rebuild: *control*' / '*targets*' hint - users
#    would not learn that their control image is outdated (v1.5.0: ansible 14.6.0 had none).
last=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [[ -z "$last" ]]; then
  echo "note: no tag in this clone (shallow? git fetch --tags) - requirements/changelog hint not checked"
elif ! git diff --quiet "$last" -- control/requirements.txt; then
  head="## [Unreleased]"
  [[ -z "${1:-}" ]] || head="## [${1#v}] - "
  if ! awk -v h="$head" 'index($0, h) == 1 { on = 1; next } /^## / { on = 0 } on' CHANGELOG.md |
       tr '\n' ' ' | grep -Eq 'Rebuild: +\*(control|targets)\*'; then
    warn "control/requirements.txt changed since $last, but '${head% - }' in CHANGELOG.md has no 'Rebuild: *control*' (or *targets*) hint"
  fi
fi

[[ $rc -eq 0 ]] && echo "release check OK ($(tracked | wc -l) tracked files)"
exit $rc
