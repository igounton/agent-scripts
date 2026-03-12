#!/usr/bin/env bash
set -euo pipefail

prl_windows_die() {
  echo "error: $*" >&2
  exit 1
}

prl_windows_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || prl_windows_die "$1 not found"
}

prl_windows_require_prlctl() {
  prl_windows_require_cmd prlctl
}

prl_windows_json_array() {
  if [[ $# -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  printf '%s\0' "$@" | /opt/homebrew/bin/node -e '
const fs = require("fs");
const raw = fs.readFileSync(0, "utf8");
if (!raw) {
  process.stdout.write("[]");
  process.exit(0);
}
const items = raw.split("\0");
if (items.length && items[items.length - 1] === "") {
  items.pop();
}
process.stdout.write(JSON.stringify(items));
'
}

prl_windows_encode_ps() {
  /opt/homebrew/bin/node -e '
const fs = require("fs");
const script = fs.readFileSync(0, "utf8");
process.stdout.write(Buffer.from(script, "utf16le").toString("base64"));
'
}

prl_windows_strip_clixml() {
  /opt/homebrew/bin/node -e '
const fs = require("fs");
let text = fs.readFileSync(0, "utf8");
text = text.replace(/^#< CLIXML\r?\n?/gm, "");
text = text.replace(/<Objs\b[\s\S]*?<\/Objs>/g, "");
text = text.replace(/\r/g, "");
process.stdout.write(text);
'
}

prl_windows_exec_ps_script() {
  local vm=$1
  local script=$2
  local encoded
  encoded=$(printf '%s' "$script" | prl_windows_encode_ps)
  prlctl exec "$vm" --current-user powershell -NoProfile -EncodedCommand "$encoded"
}

prl_windows_build_openclaw_script() {
  local env_json=$1
  local args_json=$2

  /opt/homebrew/bin/node - "$env_json" "$args_json" <<'EOF'
const envArgs = JSON.parse(process.argv[2]);
const args = JSON.parse(process.argv[3]);
const ps = (value) => "'" + String(value).replace(/'/g, "''") + "'";

const envList = envArgs.map(ps).join(", ");
const argList = args.map(ps).join(", ");

process.stdout.write(`$envPairs = @(${envList})
foreach ($pair in $envPairs) {
  if ([string]::IsNullOrWhiteSpace($pair)) { continue }
  $parts = $pair -split '=', 2
  if ($parts.Length -eq 2) {
    Set-Item -Path ("Env:" + $parts[0]) -Value $parts[1]
  }
}
$command = Get-Command openclaw.cmd -ErrorAction SilentlyContinue
if (-not $command) {
  $command = Get-Command openclaw -ErrorAction SilentlyContinue
}
if (-not $command -or -not $command.Source) {
  throw "guest openclaw command not found"
}
$argsList = @(${argList})
& $command.Source @argsList
exit $LASTEXITCODE
`);
EOF
}

prl_windows_run_openclaw_env() {
  local vm=$1
  shift

  local env_args=()
  while [[ $# -gt 0 && "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done

  [[ $# -gt 0 ]] || prl_windows_die "missing openclaw args"

  local env_json args_json script
  env_json=$(prl_windows_json_array "${env_args[@]}")
  args_json=$(prl_windows_json_array "$@")
  script=$(prl_windows_build_openclaw_script "$env_json" "$args_json")
  prl_windows_exec_ps_script "$vm" "$script"
}

prl_windows_build_install_script() {
  local install_url=$1
  local tag=$2
  local method=$3
  local git_dir=$4
  local no_onboard=$5

  /opt/homebrew/bin/node - "$install_url" "$tag" "$method" "$git_dir" "$no_onboard" <<'EOF'
const [installUrl, tag, method, gitDir, noOnboard] = process.argv.slice(2);
const ps = (value) => "'" + String(value).replace(/'/g, "''") + "'";

const lines = ["$params = @{}"];
if (tag) lines.push(`$params.Tag = ${ps(tag)}`);
if (method) lines.push(`$params.InstallMethod = ${ps(method)}`);
if (gitDir) lines.push(`$params.GitDir = ${ps(gitDir)}`);
if (noOnboard === "1") lines.push("$params.NoOnboard = $true");
lines.push(`& ([scriptblock]::Create((Invoke-RestMethod ${ps(installUrl)}))) @params`);
lines.push("exit $LASTEXITCODE");
process.stdout.write(lines.join("\n"));
EOF
}

prl_windows_build_npm_install_script() {
  local spec=$1

  /opt/homebrew/bin/node - "$spec" <<'EOF'
const [spec] = process.argv.slice(2);
const ps = (value) => "'" + String(value).replace(/'/g, "''") + "'";

process.stdout.write(`$portableRoot = Join-Path $env:LOCALAPPDATA "OpenClaw\\deps\\portable-git"
$portableEntries = @(
  (Join-Path $portableRoot "mingw64\\bin"),
  (Join-Path $portableRoot "usr\\bin"),
  (Join-Path $portableRoot "cmd"),
  (Join-Path $portableRoot "bin")
) | Where-Object { Test-Path $_ }
if ($portableEntries.Count -gt 0) {
  $env:Path = (($portableEntries + @($env:Path)) -join ";")
}
$env:NPM_CONFIG_LOGLEVEL = "error"
$env:NPM_CONFIG_UPDATE_NOTIFIER = "false"
$env:NPM_CONFIG_FUND = "false"
$env:NPM_CONFIG_AUDIT = "false"
$env:NPM_CONFIG_SCRIPT_SHELL = "cmd.exe"
$env:NODE_LLAMA_CPP_SKIP_DOWNLOAD = "1"
& npm.cmd install -g ${ps(spec)} --force --no-fund --no-audit --loglevel=error
exit $LASTEXITCODE
`);
EOF
}

prl_windows_parse_openclaw_version() {
  local raw=$1
  local version
  version=$(printf '%s\n' "$raw" | /usr/bin/perl -ne 'if (/(20[0-9]{2}\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.]+)?)/) { print "$1\n"; exit 0 }')
  [[ -n "$version" ]] || prl_windows_die "could not parse OpenClaw version from: $raw"
  printf '%s\n' "$version"
}
