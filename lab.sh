#!/usr/bin/env bash
# Host-side wrapper: lifecycle via docker compose, everything else is
# forwarded to the 'lab' command inside the control node.
set -euo pipefail
CALLER_PWD="$PWD"
cd "$(dirname "$0")"
LAB_DIR="$PWD"
export LAB_UID="${LAB_UID:-$(id -u)}" LAB_GID="${LAB_GID:-$(id -g)}"
# Host time zone (IANA name) for the containers - otherwise they run on UTC
detect_tz() {
  local tz=""
  if [[ -n "${TZ:-}" && "${TZ}" != :* ]]; then tz="$TZ"
  elif [[ -r /etc/timezone ]]; then tz="$(head -n1 /etc/timezone)"
  elif [[ -L /etc/localtime ]]; then tz="$(readlink /etc/localtime | sed -E 's#.*/zoneinfo/##')"
  elif command -v timedatectl >/dev/null 2>&1; then tz="$(timedatectl show -p Timezone --value 2>/dev/null)"
  fi
  [[ "$tz" =~ ^[A-Za-z_]+(/[A-Za-z0-9_+-]+)*$ ]] && echo "$tz" || echo UTC
}
export LAB_TZ="${LAB_TZ:-$(detect_tz)}"
TARGETS=(debian ubuntu rocky alma fedora opensuse arch alpine)

usage() {
  cat <<'USAGE'
./lab.sh up                 build images and start the lab
./lab.sh down               stop the lab (keeps images and keys)
./lab.sh destroy            remove containers, volumes and lab images
./lab.sh reset <host|all>   recreate target(s) in their original non-compliant state
./lab.sh shell              interactive shell in the control node
./lab.sh ps | logs [svc]    container status / logs
./lab.sh view <file.md>     render any markdown file of the lab (path relative to where you are)
./lab.sh docs [name]        list / show the guides
./lab.sh <lab-command>      e.g. ./lab.sh list, ./lab.sh check 1.03  (see: ./lab.sh help)
USAGE
}

case "${1:-help}" in
  up)
    docker compose up -d --build
    echo "Waiting for targets to accept SSH ..."
    for _ in $(seq 1 60); do
      if docker compose exec -T -u learner control ansible targets -m ansible.builtin.raw -a true >/dev/null 2>&1; then
        break
      fi
      sleep 3
    done
    docker compose exec -T -u learner control lab status || true
    echo; echo "Ready. Next: ./lab.sh shell   then   lab placement   or   lab show 0.01"
    ;;
  down)    docker compose down ;;
  destroy) docker compose down -v --rmi local ;;
  reset)
    shift
    [[ $# -gt 0 ]] || { echo "usage: ./lab.sh reset <host...|all>"; exit 1; }
    if [[ "$1" == all ]]; then set -- "${TARGETS[@]}"; fi
    docker compose up -d --force-recreate --no-deps "$@"
    ;;
  shell)   docker compose exec -u learner control bash ;;
  ps)      docker compose ps ;;
  logs)    shift; docker compose logs "$@" ;;
  view)
    shift
    [[ $# -eq 1 ]] || { echo "usage: ./lab.sh view <file.md>"; exit 1; }
    f="$1"; [[ "$f" == /* ]] || f="$CALLER_PWD/$f"
    [[ -f "$f" ]] || { echo "file not found: $1"; exit 1; }
    f="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"     # absolute, symlink-free dir
    case "$f" in
      "$LAB_DIR"/*) rel="${f#"$LAB_DIR"/}" ;;
      *) echo "only files inside the lab ($LAB_DIR) can be shown"; exit 1 ;;
    esac
    docker compose exec -u learner -w /lab control lab-view "/lab/$rel"
    ;;
  help|-h|--help) usage; echo; docker compose exec -T -u learner control lab help 2>/dev/null || true ;;
  *)       docker compose exec -u learner control lab "$@" ;;
esac
