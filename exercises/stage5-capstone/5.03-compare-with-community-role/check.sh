#!/usr/bin/env bash
# Check 5.03 - self-assessed review; only checks that all six questions are answered
set -u
f=/lab/work/5.03/review.md
[[ -f "$f" ]] || { echo "FAIL: $f not found"; exit 1; }
missing=0
for n in 1 2 3 4 5 6; do
  grep -Eq "^\s*(#+\s*)?(Q|Frage\s*)?${n}[.):]" "$f" || { echo "  missing answer for question $n (start a line with '$n.' or '## $n')"; missing=1; }
done
words=$(wc -w < "$f")
[[ $words -ge 300 ]] || { echo "  only $words words - a useful review needs more depth (>= 300)"; missing=1; }
[[ $missing -eq 0 ]] && echo "  ok   review.md answers all six questions ($words words). Discuss it with a colleague!"
exit $missing
