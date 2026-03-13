#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./prl-windows-lib.sh
source "$SCRIPT_DIR/prl-windows-lib.sh"

usage() {
  echo "usage: $(basename "$0") <vm-name> [--json]" >&2
  exit 64
}

[[ $# -ge 1 ]] || usage

case "${1:-}" in
  -h|--help)
    usage
    ;;
esac

vm=$1
shift

json_mode=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      json_mode=1
      shift
      ;;
    *)
      usage
      ;;
  esac
done

set +e
raw="$("$SCRIPT_DIR/prl-windows-openclaw.sh" "$vm" gateway status --json 2>&1)"
status=$?
set -e
json_raw=
if json_raw=$(printf '%s\n' "$raw" | prl_windows_extract_json 2>/dev/null); then
  :
else
  json_raw=
fi
raw_b64=$(printf '%s' "$raw" | /usr/bin/base64)

summary="$(printf '%s\n' "$json_raw" | /opt/homebrew/bin/node -e '
const fs = require("fs");
const input = fs.readFileSync(0, "utf8").trim();
const exitCode = Number(process.argv[1]);
const raw = Buffer.from(process.argv[2], "base64").toString("utf8");
if (input) {
  const parsed = JSON.parse(input);
  const listener = Array.isArray(parsed.port?.listeners) ? parsed.port.listeners[0] ?? null : null;
  process.stdout.write(JSON.stringify({
    runtimeVersion: parsed.runtimeVersion ?? null,
    rpcOk: parsed.rpc?.ok === true,
    servicePid: parsed.service?.runtime?.pid ?? null,
    listenerPid: listener?.pid ?? null,
    port: parsed.gateway?.port ?? null,
    error: null,
    exitCode,
    raw: parsed,
  }));
  process.exit(0);
}
process.stdout.write(JSON.stringify({
  runtimeVersion: null,
  rpcOk: false,
  servicePid: null,
  listenerPid: null,
  port: null,
  error: raw.trim() || `command exited with ${exitCode}`,
  exitCode,
  raw: null,
}));
' "$status" "$raw_b64")"

if [[ "$json_mode" == "1" ]]; then
  printf '%s\n' "$summary" | /opt/homebrew/bin/node -e '
const fs = require("fs");
process.stdout.write(JSON.stringify(JSON.parse(fs.readFileSync(0, "utf8")), null, 2) + "\n");
'
  exit 0
fi

printf '%s\n' "$summary" | /opt/homebrew/bin/node -e '
const fs = require("fs");
const parsed = JSON.parse(fs.readFileSync(0, "utf8"));
console.log(`runtimeVersion=${parsed.runtimeVersion ?? ""}`);
console.log(`rpcOk=${parsed.rpcOk}`);
console.log(`servicePid=${parsed.servicePid ?? ""}`);
console.log(`listenerPid=${parsed.listenerPid ?? ""}`);
console.log(`port=${parsed.port ?? ""}`);
if (parsed.error) {
  console.log(`error=${parsed.error}`);
}
'
