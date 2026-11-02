# shellcheck shell=bash
# Sourced by the 4.03 and 5.01 checks.
# cis_level2 <ansible-playbook args> -> true if the args pass cis_level=2, e.g.
#   lab check 4.03 -e cis_level=2      --extra-vars=cis_level=2      -e '{"cis_level": 2}'
#   (a quoted value counts too: -e 'cis_level="2"', -e '{"cis_level": "2"}')
# Variables from a file (-e @vars.yml) are not inspected.
cis_level2() {
  local re='cis_level["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?2([^0-9]|$)'
  [[ " $* " =~ $re ]]
}

# regression_ids <args> -> state checks that the whole role must keep green: 0.04-2.06 and
# 3.02-3.05; 3.04 (auditd, CIS Level 2) only when cis_level=2 is passed through.
regression_ids() {
  local ids="0.04 1.01 1.02 1.03 1.04 1.05 2.01 2.02 2.03 2.04 2.05 2.06 3.02 3.03"
  if cis_level2 "$@"; then ids+=" 3.04"; fi
  echo "$ids 3.05"
}

# level_note <id> <args> -> explains on stdout that 3.04 was skipped at level 1
level_note() {
  local id="$1"; shift
  cis_level2 "$@" && return 0
  echo "  note 3.04 (auditd, Level 2) not checked - after a level 2 run: lab check $id -e cis_level=2"
  echo "       (variables from -e @file are not inspected)"
}
