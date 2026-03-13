#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./prl-macos-lib.sh
source "$SCRIPT_DIR/prl-macos-lib.sh"

if [[ $# -lt 3 ]]; then
  echo "usage: $(basename "$0") <vm-name> <guest-repo-dir> <pnpm-args...>" >&2
  exit 64
fi

vm=$1
shift
repo_dir=$1
shift

prl_require_prlctl
prl_require_node

prl_run_pnpm "$vm" "$repo_dir" "$@"
