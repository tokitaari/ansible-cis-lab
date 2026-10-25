#!/usr/bin/env bash
# Host-side wrapper: lifecycle via docker compose, everything else is
# forwarded to the 'lab' command inside the control node.
set -euo pipefail
cd "$(dirname "$0")"
export LAB_UID="${LAB_UID:-$(id -u)}" LAB_GID="${LAB_GID:-$(id -g)}"
TARGETS=(debian ubuntu rocky alma fedora opensuse arch alpine)

usage() {
  cat <<'USAGE'
./lab.sh up                 build images and start the lab
./lab.sh down               stop the lab (keeps images and keys)
./lab.sh destroy            remove containers, volumes and lab images
./lab.sh reset <host|all>   recreate target(s) in their original non-compliant state
./lab.sh shell              interactive shell in the control node
./lab.sh ps | logs [svc]    container status / logs
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
  help|-h|--help) usage; echo; docker compose exec -T -u learner control lab help 2>/dev/null || true ;;
  *)       docker compose exec -u learner control lab "$@" ;;
esac
