#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./prl-macos-lib.sh
source "$SCRIPT_DIR/prl-macos-lib.sh"

usage() {
  echo "usage: $(basename "$0") <vm-name> [--from-version <version>] [--to-tag <tag>] [--profile <name>] [--state-dir <dir>] [--port <port>] [--install-url <url>]" >&2
  exit 64
}

[[ $# -ge 1 ]] || usage

vm=$1
shift

from_version=2026.3.7
to_tag=latest
profile=
state_dir=
port=
install_url=https://openclaw.ai/install.sh
gateway_port=18789
manual_gateway_log=
manual_gateway_active=0
before_gateway_mode=unknown
after_gateway_mode=unknown
tmp_dir=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-version)
      from_version=${2:?missing version}
      shift 2
      ;;
    --to-tag)
      to_tag=${2:?missing tag}
      shift 2
      ;;
    --profile)
      profile=${2:?missing profile}
      shift 2
      ;;
    --state-dir)
      state_dir=${2:?missing state dir}
      shift 2
      ;;
    --port)
      port=${2:?missing port}
      gateway_port=$port
      shift 2
      ;;
    --install-url)
      install_url=${2:?missing install url}
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

cleanup() {
  if [[ "$manual_gateway_active" == "1" ]]; then
    prl_kill_port_listener "$vm" "$gateway_port" >/dev/null 2>&1 || true
  fi
  if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

if [[ -n "$profile" && -z "$state_dir" ]]; then
  state_dir="$(prl_guest_home "$vm")/.openclaw-$profile"
fi

launchd_label=ai.openclaw.gateway
if [[ -n "$profile" && "$profile" != "default" ]]; then
  launchd_label="ai.openclaw.$profile"
fi

common_env=()
if [[ -n "$profile" ]]; then
  common_env+=("OPENCLAW_PROFILE=$profile")
fi
if [[ -n "$state_dir" ]]; then
  common_env+=("OPENCLAW_STATE_DIR=$state_dir")
fi

json_field() {
  local json=$1
  local expr=$2
  if [[ -z "${json//$'\n'/}" ]]; then
    printf ''
    return 0
  fi
  printf '%s\n' "$json" | /opt/homebrew/bin/node -e '
const fs = require("fs");
const input = JSON.parse(fs.readFileSync(0, "utf8"));
const expr = process.argv[1];
const value = Function("input", `return (${expr});`)(input);
if (value === undefined || value === null) {
  process.stdout.write("");
} else if (typeof value === "object") {
  process.stdout.write(JSON.stringify(value));
} else {
  process.stdout.write(String(value));
}
' "$expr"
}

run_openclaw() {
  local cmd=("$SCRIPT_DIR/prl-macos-openclaw.sh" "$vm")
  local env_arg
  for env_arg in "${common_env[@]}"; do
    cmd+=(--env "$env_arg")
  done
  cmd+=("$@")
  "${cmd[@]}"
}

gateway_status_json() {
  local cmd=("$SCRIPT_DIR/prl-macos-gateway-status-version.sh" "$vm")
  if [[ -n "$profile" ]]; then
    cmd+=(--profile "$profile")
  fi
  if [[ -n "$state_dir" ]]; then
    cmd+=(--state-dir "$state_dir")
  fi
  cmd+=(--json)
  "${cmd[@]}"
}

wait_for_gateway() {
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    local status
    status="$(gateway_status_json 2>/dev/null || true)"
    if [[ -z "${status//$'\n'/}" ]]; then
      sleep 1
      continue
    fi
    if [[ "$(json_field "$status" 'input.rpcOk === true ? "true" : ""')" == "true" ]]; then
      printf '%s\n' "$status"
      return 0
    fi
    sleep 1
  done
  return 1
}

ensure_gateway_ready() {
  local install_args=()
  local status

  status="$(gateway_status_json 2>/dev/null || true)"
  if [[ "$(json_field "$status" 'input.rpcOk === true ? "true" : ""')" == "true" ]]; then
    printf 'service\n%s\n' "$status"
    return 0
  fi

  run_openclaw config set gateway.mode local >/dev/null 2>&1 || true

  install_args=(gateway install --force)
  if [[ -n "$port" ]]; then
    install_args+=(--port "$port")
  fi
  run_openclaw "${install_args[@]}" >/dev/null 2>&1 || true

  if status="$(wait_for_gateway)"; then
    printf 'service\n%s\n' "$status"
    return 0
  fi

  manual_gateway_log="/tmp/openclaw-gateway-release-smoke-${profile:-default}-$gateway_port.log"
  prl_kill_port_listener "$vm" "$gateway_port" >/dev/null 2>&1 || true
  local manual_pid
  manual_pid="$(prl_run_openclaw_detached_env "$vm" "${common_env[@]}" "$manual_gateway_log" gateway run --bind loopback --port "$gateway_port" --force)"
  manual_gateway_active=1
  if status="$(wait_for_gateway)"; then
    printf 'manual:%s\n%s\n' "$manual_pid" "$status"
    return 0
  fi

  if prlctl exec "$vm" --current-user /bin/test -f "$manual_gateway_log" >/dev/null 2>&1; then
    prlctl exec "$vm" --current-user /bin/cat "$manual_gateway_log" >&2 || true
  fi
  return 1
}

install_cmd=("$SCRIPT_DIR/prl-macos-install-openclaw.sh" "$vm" --version "$from_version" --install-url "$install_url")
if [[ -n "$profile" ]]; then
  install_cmd+=(--profile "$profile")
fi
if [[ -n "$state_dir" ]]; then
  install_cmd+=(--state-dir "$state_dir")
fi

before_install="$("${install_cmd[@]}")"
before_cli_version="$(prl_parse_openclaw_version "$before_install")"

if [[ -n "$profile" || -n "$state_dir" || -n "$port" ]]; then
  run_openclaw gateway uninstall --force >/dev/null 2>&1 || true
  prl_exec_sh "$vm" "launchctl bootout gui/\$(id -u)/$launchd_label >/dev/null 2>&1 || true; rm -f \"\$HOME/Library/LaunchAgents/$launchd_label.plist\""
fi

before_ready="$(ensure_gateway_ready)"
before_gateway_mode="$(printf '%s\n' "$before_ready" | sed -n '1p')"
before_status="$(printf '%s\n' "$before_ready" | sed -n '2,$p')"

if [[ "$before_gateway_mode" == manual:* ]]; then
  prl_kill_port_listener "$vm" "$gateway_port" >/dev/null 2>&1 || true
  manual_gateway_active=0
fi

update_raw="$(run_openclaw update --tag "$to_tag" --yes --json 2>&1)"

update_json="$(printf '%s\n' "$update_raw" | /opt/homebrew/bin/node -e '
const fs = require("fs");
const input = fs.readFileSync(0, "utf8");
const lines = input.split(/\r?\n/);
const start = lines.findIndex((line) => line.trim().startsWith("{"));
if (start < 0) {
  process.stderr.write(input);
  process.exit(1);
}
const parsed = JSON.parse(lines.slice(start).join("\n"));
process.stdout.write(JSON.stringify(parsed));
')"

after_cli_raw="$(run_openclaw --version)"
after_cli_version="$(prl_parse_openclaw_version "$after_cli_raw")"

after_ready="$(ensure_gateway_ready)"
after_gateway_mode="$(printf '%s\n' "$after_ready" | sed -n '1p')"
after_status="$(printf '%s\n' "$after_ready" | sed -n '2,$p')"

tmp_dir=$(mktemp -d)
printf '%s\n' "$before_status" >"$tmp_dir/before-status.json"
printf '%s\n' "$update_json" >"$tmp_dir/update.json"
printf '%s\n' "$after_status" >"$tmp_dir/after-status.json"

/opt/homebrew/bin/node - "$tmp_dir/before-status.json" "$tmp_dir/update.json" \
  "$tmp_dir/after-status.json" "$after_cli_version" "$before_gateway_mode" "$after_gateway_mode" <<'EOF'
const fs = require("fs");
const [beforePath, updatePath, afterPath, afterCliVersion, beforeGatewayMode, afterGatewayMode] = process.argv.slice(2);
const beforeStatus = JSON.parse(fs.readFileSync(beforePath, "utf8"));
const update = JSON.parse(fs.readFileSync(updatePath, "utf8"));
const afterStatus = JSON.parse(fs.readFileSync(afterPath, "utf8"));
const summary = {
  ok: true,
  before: {
    cliVersion: update.before?.version ?? null,
    gatewayMode: beforeGatewayMode || null,
    statusRuntimeVersion: beforeStatus.runtimeVersion ?? null,
    rpcOk: beforeStatus.rpcOk === true,
    servicePid: beforeStatus.servicePid ?? null,
    listenerPid: beforeStatus.listenerPid ?? null,
    port: beforeStatus.port ?? null,
  },
  update: {
    status: update.status ?? null,
    mode: update.mode ?? null,
    beforeVersion: update.before?.version ?? null,
    afterVersion: update.after?.version ?? null,
  },
  after: {
    cliVersion: afterCliVersion || null,
    gatewayMode: afterGatewayMode || null,
    statusRuntimeVersion: afterStatus.runtimeVersion ?? null,
    rpcOk: afterStatus.rpcOk === true,
    servicePid: afterStatus.servicePid ?? null,
    listenerPid: afterStatus.listenerPid ?? null,
    port: afterStatus.port ?? null,
  },
};

if (summary.update.status !== "ok") {
  summary.ok = false;
}
if (!summary.before.rpcOk || !summary.after.rpcOk) {
  summary.ok = false;
}
if (summary.update.afterVersion && summary.after.cliVersion && summary.update.afterVersion !== summary.after.cliVersion) {
  summary.ok = false;
}
if (summary.after.statusRuntimeVersion && summary.after.cliVersion && summary.after.statusRuntimeVersion !== summary.after.cliVersion) {
  summary.ok = false;
}

process.stdout.write(JSON.stringify(summary, null, 2) + "\n");
process.exit(summary.ok ? 0 : 1);
EOF
