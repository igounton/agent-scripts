#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./prl-windows-lib.sh
source "$SCRIPT_DIR/prl-windows-lib.sh"

usage() {
  echo "usage: $(basename "$0") <vm-name> [--from-version <version>] [--from-spec <npm-spec-or-url>] [--to-tag <tag>] [--update-spec <npm-spec-or-url>] [--install-url <url>]" >&2
  exit 64
}

[[ $# -ge 1 ]] || usage

vm=$1
shift

from_version=2026.3.7
from_spec=
to_tag=latest
update_spec=
install_url=https://openclaw.ai/install.ps1
tmp_dir=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-version)
      from_version=${2:?missing version}
      shift 2
      ;;
    --from-spec)
      from_spec=${2:?missing from spec}
      shift 2
      ;;
    --to-tag)
      to_tag=${2:?missing tag}
      shift 2
      ;;
    --update-spec)
      update_spec=${2:?missing update spec}
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
  if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

capture_gateway_status() {
  "$SCRIPT_DIR/prl-windows-gateway-status-version.sh" "$vm" --json
}

capture_update() {
  set +e
  if [[ -n "$update_spec" ]]; then
    raw="$("$SCRIPT_DIR/prl-windows-openclaw.sh" "$vm" --env "OPENCLAW_UPDATE_PACKAGE_SPEC=$update_spec" update --yes --json 2>&1)"
  else
    raw="$("$SCRIPT_DIR/prl-windows-openclaw.sh" "$vm" update --tag "$to_tag" --yes --json 2>&1)"
  fi
  status=$?
  set -e
  printf '%s\n' "$raw" | /opt/homebrew/bin/node -e '
const fs = require("fs");
const input = fs.readFileSync(0, "utf8");
const exitCode = Number(process.argv[1]);
const lines = input.split(/\r?\n/);
const start = lines.findIndex((line) => line.trim().startsWith("{"));
if (start >= 0) {
  const parsed = JSON.parse(lines.slice(start).join("\n"));
  process.stdout.write(JSON.stringify({
    exitCode,
    ok: exitCode === 0,
    beforeVersion: parsed.before?.version ?? null,
    afterVersion: parsed.after?.version ?? null,
    raw: parsed,
    error: null,
  }));
  process.exit(0);
}
process.stdout.write(JSON.stringify({
  exitCode,
  ok: false,
  beforeVersion: null,
  afterVersion: null,
  raw: null,
  error: input.trim() || `command exited with ${exitCode}`,
}));
' "$status"
}

if [[ -n "$from_spec" ]]; then
  before_install="$("$SCRIPT_DIR/prl-windows-install-openclaw.sh" "$vm" --spec "$from_spec" 2>/dev/null)"
else
  before_install="$("$SCRIPT_DIR/prl-windows-install-openclaw.sh" "$vm" --version "$from_version" --install-url "$install_url" 2>/dev/null)"
fi
before_cli_version="$(prl_windows_parse_openclaw_version "$before_install")"
before_status="$(capture_gateway_status)"

update_json="$(capture_update)"

set +e
after_cli_raw="$("$SCRIPT_DIR/prl-windows-openclaw.sh" "$vm" --version 2>&1)"
after_cli_exit=$?
set -e
after_cli_version=
if [[ "$after_cli_exit" == "0" ]]; then
  after_cli_version="$(prl_windows_parse_openclaw_version "$after_cli_raw")"
fi
after_status="$(capture_gateway_status)"

tmp_dir=$(mktemp -d)
printf '%s\n' "$before_status" >"$tmp_dir/before-status.json"
printf '%s\n' "$update_json" >"$tmp_dir/update.json"
printf '%s\n' "$after_status" >"$tmp_dir/after-status.json"

/opt/homebrew/bin/node - "$tmp_dir/before-status.json" "$tmp_dir/update.json" "$tmp_dir/after-status.json" "$before_cli_version" "$after_cli_version" "$update_spec" <<'EOF'
const fs = require("fs");
const [beforePath, updatePath, afterPath, beforeCliVersion, afterCliVersion, updateSpec] = process.argv.slice(2);
const beforeStatus = JSON.parse(fs.readFileSync(beforePath, "utf8"));
const update = JSON.parse(fs.readFileSync(updatePath, "utf8"));
const afterStatus = JSON.parse(fs.readFileSync(afterPath, "utf8"));
const knownBlockers = [];

for (const candidate of [beforeStatus.error, update.error, afterStatus.error]) {
  if (typeof candidate === "string" && candidate.includes("@snazzah\\davey")) {
    knownBlockers.push("published native Windows release still fails on @snazzah/davey optional binding load");
    break;
  }
}

for (const candidate of [beforeStatus.error, update.error, afterStatus.error]) {
  if (typeof candidate === "string" && candidate.includes("getOAuthApiKey")) {
    knownBlockers.push("older published native Windows release still fails on @mariozechner/pi-ai export drift");
    break;
  }
}

const ok = Boolean(
  beforeCliVersion &&
  afterCliVersion &&
  (!update.error || update.ok)
);

process.stdout.write(JSON.stringify({
  ok,
  before: {
    cliVersion: beforeCliVersion || null,
    statusRuntimeVersion: beforeStatus.runtimeVersion ?? null,
    rpcOk: beforeStatus.rpcOk === true,
    error: beforeStatus.error ?? null,
  },
  update: {
    ok: update.ok === true,
    beforeVersion: update.beforeVersion ?? null,
    afterVersion: update.afterVersion ?? null,
    spec: updateSpec || null,
    error: update.error ?? null,
  },
  after: {
    cliVersion: afterCliVersion || null,
    statusRuntimeVersion: afterStatus.runtimeVersion ?? null,
    rpcOk: afterStatus.rpcOk === true,
    error: afterStatus.error ?? null,
  },
  knownBlockers,
}, null, 2) + "\n");
EOF
