#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./prl-macos-lib.sh
source "$SCRIPT_DIR/prl-macos-lib.sh"

usage() {
  echo "usage: $(basename "$0") <vm-name> <local-auth-profiles.json|-> [--agent <agent-id>] [--guest-path <path>]" >&2
  exit 64
}

[[ $# -ge 2 ]] || usage

vm=$1
input_path=$2
shift 2

agent_id=main
guest_path=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      agent_id=${2:?missing agent id}
      shift 2
      ;;
    --guest-path)
      guest_path=${2:?missing guest path}
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$guest_path" ]]; then
  guest_home=$(prl_guest_home "$vm")
  [[ -n "$guest_home" ]] || prl_die "could not resolve guest HOME"
  guest_path="$guest_home/.openclaw/agents/$agent_id/agent/auth-profiles.json"
fi

tmp_input=
if [[ "$input_path" == "-" ]]; then
  tmp_input=$(mktemp)
  cat >"$tmp_input"
  input_path=$tmp_input
fi

trap '[[ -n "$tmp_input" ]] && rm -f "$tmp_input"' EXIT

[[ -f "$input_path" ]] || prl_die "input file not found: $input_path"

/opt/homebrew/bin/node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$input_path" >/dev/null

payload=$(base64 <"$input_path" | tr -d "\n")
guest_dir=$(dirname "$guest_path")
guest_b64_path="${guest_path}.b64"
prlctl exec "$vm" --current-user /bin/mkdir -p "$guest_dir"
printf '%s' "$payload" | prlctl exec "$vm" --current-user /usr/bin/tee "$guest_b64_path" >/dev/null
prlctl exec "$vm" --current-user /usr/bin/base64 -D -i "$guest_b64_path" -o "$guest_path"
prlctl exec "$vm" --current-user /bin/rm -f "$guest_b64_path" >/dev/null 2>&1 || true
printf '%s\n' "$guest_path"
