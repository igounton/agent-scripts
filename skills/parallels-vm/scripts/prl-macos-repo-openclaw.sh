#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./prl-macos-lib.sh
source "$SCRIPT_DIR/prl-macos-lib.sh"

usage() {
  echo "usage: $(basename "$0") <vm-name> <guest-repo-dir|guest-entry.js> [--env KEY=VALUE ...] <openclaw-args...>" >&2
  exit 64
}

[[ $# -ge 3 ]] || usage

vm=$1
repo_or_entry=$2
shift 2

env_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || prl_die "--env requires KEY=VALUE"
      env_args+=("$2")
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -gt 0 ]] || prl_die "missing openclaw args"

prl_require_prlctl
prl_require_node

entry=$(prl_resolve_repo_openclaw_entry "$vm" "$repo_or_entry") ||
  prl_die "guest repo OpenClaw entrypoint not found under: $repo_or_entry"

prl_exec_env_node "$vm" "${env_args[@]}" "$entry" "$@"
