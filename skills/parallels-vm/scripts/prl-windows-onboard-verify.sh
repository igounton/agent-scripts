#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./prl-windows-lib.sh
source "$SCRIPT_DIR/prl-windows-lib.sh"

usage() {
  echo "usage: $(basename "$0") <vm-name> [--openai-api-key-env <env-var>] [--openai-api-key <key>] [--install-daemon] [--workspace <path>] [--json]" >&2
  exit "${1:-64}"
}

[[ $# -ge 1 ]] || usage

case "${1:-}" in
  -h|--help)
    usage 0
    ;;
esac

vm=$1
shift

openai_api_key=
openai_api_key_env=
install_daemon=0
workspace=
json_mode=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openai-api-key-env)
      openai_api_key_env=${2:?missing env var}
      shift 2
      ;;
    --openai-api-key)
      openai_api_key=${2:?missing key}
      shift 2
      ;;
    --install-daemon)
      install_daemon=1
      shift
      ;;
    --workspace)
      workspace=${2:?missing workspace}
      shift 2
      ;;
    --json)
      json_mode=1
      shift
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -n "$openai_api_key" && -n "$openai_api_key_env" ]]; then
  prl_windows_die "pass only one of --openai-api-key or --openai-api-key-env"
fi

env_args=()
auth_choice=skip
if [[ -n "$openai_api_key_env" ]]; then
  [[ -n "${!openai_api_key_env:-}" ]] || prl_windows_die "host env var $openai_api_key_env is empty"
  env_args+=("OPENAI_API_KEY=${!openai_api_key_env}")
  auth_choice=openai-api-key
elif [[ -n "$openai_api_key" ]]; then
  env_args+=("OPENAI_API_KEY=$openai_api_key")
  auth_choice=openai-api-key
fi

cmd=(onboard --non-interactive --mode local --auth-choice "$auth_choice" --skip-skills --accept-risk --json)
if [[ "$install_daemon" == "1" ]]; then
  cmd+=(--install-daemon)
fi
if [[ -n "$workspace" ]]; then
  cmd+=(--workspace "$workspace")
fi

wrapper_args=()
for env_arg in "${env_args[@]}"; do
  wrapper_args+=(--env "$env_arg")
done

set +e
raw="$("$SCRIPT_DIR/prl-windows-openclaw.sh" "$vm" "${wrapper_args[@]}" "${cmd[@]}" 2>&1)"
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
const installDaemon = process.argv[2] === "1";
const authChoice = process.argv[3];
const raw = Buffer.from(process.argv[4], "base64").toString("utf8");

const expectedNoDaemonHealthFailure =
  !installDaemon &&
  raw.includes("already-running gateway unless you pass --install-daemon");
const scheduledTaskAccessDenied =
  installDaemon && raw.includes("schtasks create failed: ERROR: Access is denied.");

const parsed = input ? JSON.parse(input) : null;
const ok = exitCode === 0;

process.stdout.write(JSON.stringify({
  ok,
  exitCode,
  authChoice,
  installDaemon,
  expectedNoDaemonHealthFailure,
  scheduledTaskAccessDenied,
  configWritten: parsed?.workspace != null || raw.includes("Config updated."),
  workspaceDir: typeof parsed?.workspace === "string" ? parsed.workspace : null,
  gateway: parsed?.gateway ?? null,
  error: ok ? null : raw.trim() || `command exited with ${exitCode}`,
  raw: parsed,
}, null, 2) + "\n");
' "$status" "$install_daemon" "$auth_choice" "$raw_b64")"

if [[ "$json_mode" == "1" ]]; then
  printf '%s\n' "$summary"
  exit 0
fi

printf '%s\n' "$summary" | /opt/homebrew/bin/node -e '
const fs = require("fs");
const parsed = JSON.parse(fs.readFileSync(0, "utf8"));
console.log(`ok=${parsed.ok}`);
console.log(`authChoice=${parsed.authChoice}`);
console.log(`installDaemon=${parsed.installDaemon}`);
console.log(`expectedNoDaemonHealthFailure=${parsed.expectedNoDaemonHealthFailure}`);
console.log(`scheduledTaskAccessDenied=${parsed.scheduledTaskAccessDenied}`);
console.log(`workspaceDir=${parsed.workspaceDir ?? ""}`);
if (parsed.error) {
  console.log(`error=${parsed.error}`);
}
'
